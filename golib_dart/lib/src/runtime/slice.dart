/// Slices Go: janela (offset, len, cap) sobre um array compartilhado.
library;

import '../../fixed_types/golang/src/bounds.dart';
import 'elem.dart';
import 'panic.dart';
import 'ptr.dart';

/// `[]T` do Go.
///
/// Fatias do mesmo array compartilham armazenamento. `append` escreve no
/// array quando cabe e só realoca quando `len > cap`, com a política de
/// crescimento do runtime Go (`growslice` + size classes), para que o aliasing
/// observável seja o mesmo. Structs no array são atualizadas in-place
/// (`$set`), então ponteiros para elementos continuam válidos.
///
/// `base`: um tipo nomeado Go sobre slice (`type IDs []string`) é uma
/// subclasse gerada, e a conversão entre eles é [Slice.alias].
base class Slice<T> {
  Slice._(this._array, this._off, this._len, this._cap, this.elem);

  /// Mesmo cabeçalho (array, offset, len, cap) de [s]: conversão entre tipos
  /// de slice com o mesmo subjacente (`IDs(s)`, `[]string(ids)`).
  Slice.alias(Slice<T> s) : this._(s._array, s._off, s._len, s._cap, s.elem);

  /// Janela sobre um array existente (`a[low:high:max]` de um array Go).
  Slice.view(List<T> array, int off, int len, int cap, Elem<T> elem)
    : this._(array, off, len, cap, elem);

  /// Slice nil (zero value).
  Slice.nil(this.elem) : _array = null, _off = 0, _len = 0, _cap = 0;

  /// Literal `[]T{...}`: len = cap = número de itens.
  Slice.of(List<T> items, this.elem)
    : _array = List<T>.of(items),
      _off = 0,
      _len = items.length,
      _cap = items.length;

  /// `make([]T, len, cap)`, com as checagens do `makeslice` do Go (tamanho
  /// em bytes acima de `maxAlloc`, 2^48 no amd64: "len" se o len já
  /// estoura, senão "cap").
  factory Slice.make(int len, int cap, Elem<T> elem) {
    bool over(int n) => n < 0 || n * elem.size > 281474976710656;
    if (over(cap) || len > cap) {
      throw Panic(
        RuntimeError(
          'runtime error: makeslice: ${over(len) ? 'len' : 'cap'} out of range',
        ),
      );
    }
    return Slice._(
      List<T>.generate(cap, (_) => elem.zero()),
      0,
      len,
      cap,
      elem,
    );
  }

  final List<T>? _array;
  final int _off;
  final int _len;
  final int _cap;
  final Elem<T> elem;

  bool get isNil => _array == null;
  int get length => _len;
  int get capacity => _cap;

  void _check(int i) {
    if (i < 0 || i >= _len) {
      throw Panic(
        RuntimeError(
          'runtime error: index out of range [${indexText(i)}]'
          '${withBound(i, 'length', _len)}',
        ),
      );
    }
  }

  T operator [](int i) {
    _check(i);
    return _array![_off + i];
  }

  void operator []=(int i, T v) {
    _check(i);
    _store(_array!, _off + i, v);
  }

  /// `clear(s)`: zera os elementos da janela (struct/array in-place, como o
  /// `[]=`: ponteiros para os elementos veem o zero).
  void clear() {
    for (var i = 0; i < _len; i++) {
      _store(_array!, _off + i, elem.zero());
    }
  }

  /// `&s[i]`.
  Ptr<T> addr(int i) {
    _check(i);
    return ElemPtr<T>(_array!, _off + i);
  }

  /// `s[low:high:max]`, com os limites do Go (relativos a cap).
  Slice<T> slice(int low, [int? high, int? max]) {
    final m = max ?? _cap, h = high ?? _len;
    if (m < 0 || m > _cap) {
      throw Panic(
        RuntimeError(
          'runtime error: slice bounds out of range [::${indexText(m)}]'
          '${withBound(m, 'capacity', _cap)}',
        ),
      );
    }
    if (h < 0 || h > m) {
      throw Panic(
        RuntimeError(
          'runtime error: slice bounds out of range [:${indexText(h)}]'
          '${withBound(h, 'capacity', m)}',
        ),
      );
    }
    if (low < 0 || low > h) {
      throw Panic(
        RuntimeError(
          'runtime error: slice bounds out of range ${lowHigh(low, h)}',
        ),
      );
    }
    final array = _array;
    if (array == null) return this; // nil[0:0] continua nil
    return Slice._(array, _off + low, h - low, m - low, elem);
  }

  /// `append(s, values...)` — values já copiados pelo chamador.
  Slice<T> append(List<T> values) {
    if (values.isEmpty) return this;
    final newLen = _len + values.length;
    var array = _array, off = _off, cap = _cap;
    if (array == null || newLen > cap) {
      cap = growCap(newLen, _cap, elem.size, elem.pointers);
      final old = _array;
      array = List<T>.generate(
        cap,
        (i) => i < _len ? elem.copyOf(old![_off + i]) : elem.zero(),
      );
      off = 0;
    }
    for (var i = 0; i < values.length; i++) {
      _store(array, off + _len + i, values[i]);
    }
    return Slice._(array, off, newLen, cap, elem);
  }

  /// `append(s, t...)`.
  Slice<T> appendSlice(Slice<T> t) =>
      append([for (var i = 0; i < t._len; i++) elem.copyOf(t[i])]);

  /// `copy(dst, src)`: copia min(len) elementos (sobreposição permitida).
  int copyFrom(Slice<T> src) {
    final n = _len < src._len ? _len : src._len;
    final tmp = [for (var i = 0; i < n; i++) elem.copyOf(src[i])];
    for (var i = 0; i < n; i++) {
      _store(_array!, _off + i, tmp[i]);
    }
    return n;
  }

  void _store(List<T> array, int i, T v) => elem.storeAt(array, i, v);

  /// Elementos da janela (formatação e utilitários do runtime).
  Iterable<T> get items sync* {
    for (var i = 0; i < _len; i++) {
      yield _array![_off + i];
    }
  }
}

// Size classes do alocador Go 1.25 (internal/runtime/gc/sizeclasses.go).
const _sizeClasses = <int>[
  8, 16, 24, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, //
  240, 256, 288, 320, 352, 384, 416, 448, 480, 512, 576, 640, 704, 768, 896,
  1024, 1152, 1280, 1408, 1536, 1792, 2048, 2304, 2688, 3072, 3200, 3456,
  4096, 4864, 5376, 6144, 6528, 6784, 6912, 8192, 9472, 9728, 10240, 10880,
  12288, 13568, 14336, 16384, 18432, 19072, 20480, 21760, 24576, 27264, 28672,
  32768,
];

/// Novo cap de `append` (runtime.growslice + nextslicecap + roundupsize).
/// Só aritmética, sem bitwise: exato também no int do JS.
int growCap(int newLen, int oldCap, int size, bool pointers) {
  if (size == 0) return newLen;
  var newcap = oldCap;
  final doublecap = newcap + newcap;
  if (newLen > doublecap) {
    newcap = newLen;
  } else if (oldCap < 256) {
    newcap = doublecap;
  } else {
    while (newcap < newLen) {
      newcap += (newcap + 3 * 256) ~/ 4;
    }
  }
  return _roundupsize(newcap * size, !pointers) ~/ size;
}

int _roundupsize(int size, bool noscan) {
  var req = size;
  if (req <= 32768 - 8) {
    if (!noscan && req > 512) req += 8; // malloc header
    for (final c in _sizeClasses) {
      if (c >= req) return c - (req - size);
    }
  }
  return (req + 8191) ~/ 8192 * 8192;
}

/// `alias.InexactOverlap(x, y)` do Go: x e y dividem memória em algum índice
/// não correspondente (o que passa do `len` não conta).
bool inexactOverlap<T>(Slice<T> x, Slice<T> y) {
  if (x._len == 0 || y._len == 0) return false;
  if (!identical(x._array, y._array) || x._off == y._off) return false;
  return x._off <= y._off + y._len - 1 && y._off <= x._off + x._len - 1;
}

/// `s[i], s[j] = s[j], s[i]` (o `reflectlite.Swapper` do Go): struct/array
/// copiam o valor antes, porque `[]=` sobrescreve o elemento in-place.
void swapElems<T>(Slice<T> s, int i, int j) {
  s._check(i);
  s._check(j);
  final a = s._array![s._off + i];
  final t = s.elem.copyOf(a);
  s[i] = s._array[s._off + j];
  s[j] = t;
}

/// Endereço (estável, não o do Go) do primeiro elemento de s: o mesmo
/// `hashCode` de `&s[0]` (`ElemPtr`). Para `%p` de slice.
int sliceAddr<T>(Slice<T> s) =>
    s._array == null ? 0 : Object.hash(identityHashCode(s._array), s._off);

/// Bytes alocados para um pedido de `size` bytes (classe de tamanho do
/// alocador do Go, `roundupsize`): o cap de `bytealg.MakeNoZero`.
int allocBytes(int size) => _roundupsize(size, true);
