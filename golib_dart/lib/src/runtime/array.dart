/// Arrays Go `[N]T`: valores de comprimento fixo.
library;

import 'elem.dart';
import 'panic.dart';
import 'ptr.dart';
import 'slice.dart';
import 'struct.dart';

/// `[N]T` do Go: um valor, como uma struct.
///
/// Atribuir/passar copia os elementos ([$copy]); `a = b` sobrescreve in-place
/// ([$set]); `==` compara elemento a elemento (serve de chave de map);
/// `a[i:j]` devolve um [Slice] que compartilha o armazenamento do array.
///
/// Tipo nomeado sobre array (`type Hash [32]byte`) é uma subclasse gerada:
/// `final class Hash extends GoArray<Uint8>`, construída com [GoArray.alias].
base class GoArray<T> extends GoValue<GoArray<T>> {
  GoArray._(this._items, this.elem);

  /// Mesmo armazenamento de [v] (o tipo nomeado embrulha o array).
  GoArray.alias(GoArray<T> v) : _items = v._items, elem = v.elem;

  /// Zero value: N zeros.
  GoArray.zero(int n, this.elem)
    : _items = List<T>.generate(n, (_) => elem.zero());

  /// Literal `[N]T{...}` (o g2d completa com zeros até N).
  GoArray.of(List<T> items, this.elem) : _items = List<T>.of(items);

  final List<T> _items;
  final Elem<T> elem;

  int get length => _items.length;

  void _check(int i) {
    if (i < 0 || i >= _items.length) {
      throw Panic(
        RuntimeError(
          'runtime error: index out of range [$i] with length ${_items.length}',
        ),
      );
    }
  }

  T operator [](int i) {
    _check(i);
    return _items[i];
  }

  void operator []=(int i, T v) {
    _check(i);
    final cur = _items[i];
    if (cur is GoValue && v is GoValue) {
      cur.$set(v);
    } else {
      _items[i] = v;
    }
  }

  /// `&a[i]`.
  Ptr<T> addr(int i) {
    _check(i);
    return ElemPtr<T>(_items, i);
  }

  /// `a[low:high:max]`: slice sobre o mesmo armazenamento.
  Slice<T> slice(int low, [int? high, int? max]) => Slice.view(
    _items,
    0,
    _items.length,
    _items.length,
    elem,
  ).slice(low, high, max);

  Iterable<T> get items => _items;

  @override
  GoArray<T> $copy() =>
      GoArray._([for (final e in _items) elem.copyOf(e)], elem);

  @override
  void $set(GoArray<T> other) {
    for (var i = 0; i < _items.length; i++) {
      this[i] = elem.copyOf(other._items[i]);
    }
  }

  @override
  String get $goType => '[${_items.length}]';

  @override
  List<String> get $methods => const [];

  @override
  bool operator ==(Object other) {
    if (other is! GoArray<T> ||
        other._items.length != _items.length ||
        other.$goType != $goType) {
      return false; // tipos nomeados distintos numa interface não são iguais
    }
    for (var i = 0; i < _items.length; i++) {
      if (_items[i] != other._items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_items);
}
