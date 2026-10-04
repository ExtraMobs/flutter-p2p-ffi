part of '../../reflect.dart';

/// Valor de um tipo com descritor: as classes geradas pelo g2d (structs,
/// tipos nomeados) e os tipos de shim que o reflect conhece.
abstract interface class Typed {
  /// Descritor do tipo T da classe (para uma struct, T e não `*T`: o
  /// [rtypeOf] decide pelo `$isValue`).
  RType get $rtype;
}

/// Campo de struct num descritor: nome Go, pacote (vazio se exportado),
/// tipo, tag, posição e o acesso ao campo Dart do objeto da struct.
final class RField {
  RField(
    this.name,
    this.pkg,
    this.typeFn, {
    this.tag = '',
    this.embedded = false,
    this.offset = 0,
    this.get,
    this.set,
  });

  /// Nome Go (o do tipo, para campo embutido).
  final String name;

  /// Import path do pacote se o campo não é exportado; vazio se é.
  final String pkg;

  /// Tipo do campo (thunk: tipos recursivos).
  final RType Function() typeFn;

  /// Tag crua (`json:"x,omitempty"`).
  final String tag;

  final bool embedded;

  /// `unsafe.Offsetof` em amd64 (de struct genérica, calculado no primeiro
  /// uso do layout).
  int offset;

  /// Lê o campo de um objeto da struct: a representação Dart do valor
  /// (struct/array aninhado é o próprio objeto, sem cópia).
  final Object? Function(Object)? get;

  /// Escreve o campo (struct/array aninhado: `$set` in-place). `null` para
  /// campo de tipo de shim sem acesso.
  final void Function(Object, Object?)? set;

  RType get type => typeFn();
}

/// Descritor de um tipo Go. Um objeto por tipo (canônico): os nomeados são
/// `static final` das classes geradas; os sem nome saem dos caches de
/// [ptrTo]/[sliceOf]/[rtMap]/[arrayOf]/[rtChan]/[rtFunc]/[rtIface].
///
/// T é a representação Dart dos valores do tipo (`Golang.Int`, a classe da
/// struct, `Point?` para `*Point`, `go.Ptr<Golang.Int>?` para `*int`,
/// `Object?` para interfaces), usada para criar slices, maps e ponteiros
/// com o tipo reificado certo.
final class RType<T> {
  RType._(
    this.$kind,
    this.$str, {
    String name = '',
    String pkg = '',
    required int size,
    required int align,
    required T Function() zero,
    bool ptrs = false,
    T Function(Object)? conv,
    RType Function()? elem,
    RType Function()? key,
    int len = 0,
    int dir = 0,
    List<RField> Function()? fields,
    List<String> methods = const [],
    List<String> ptrMethods = const [],
    Map<String, String> sigs = const {},
    Object Function()? nil,
    bool opaque = false,
    RType Function()? under,
  }) : $name = name,
       $pkg = pkg,
       _size = size,
       _align = align,
       $zero = zero,
       $ptrs = ptrs,
       $conv = conv,
       _elemFn = elem,
       _keyFn = key,
       _len = len,
       _dir = dir,
       _underFn = under,
       _fieldsFn = fields,
       $methods = methods,
       $ptrMethods = ptrMethods,
       $sigs = sigs,
       $nil = nil,
       $opaque = opaque;

  /// Kind Go (`kStruct`...).
  final int $kind;

  /// `Type.String()` (`[]int`, `main.P`, `*main.P`).
  final String $str;

  /// `Type.Name()`: vazio para tipo sem nome.
  final String $name;

  /// `Type.PkgPath()`: vazio para tipo sem nome ou predeclarado.
  final String $pkg;

  int _size;
  int _align;

  /// `Size()` em amd64. Negativo no construtor (instância de genérico):
  /// calculado aqui a partir dos campos ou do subjacente.
  int get $size {
    if (_size < 0) _layout();
    return _size;
  }

  int get $align {
    if (_align < 0) _layout();
    return _align;
  }

  void _layout() {
    if ($kind != kStruct) {
      _size = $under.$size;
      _align = $under.$align;
      return;
    }
    var off = 0, align = 1;
    for (final f in $fields) {
      final t = f.type;
      final a = t.$align;
      off = (off + a - 1) ~/ a * a;
      f.offset = off;
      off += t.$size;
      if (a > align) align = a;
    }
    // Campo final de tamanho zero numa struct não vazia ganha 1 byte (gc).
    if ($fields.isNotEmpty && $fields.last.type.$size == 0 && off > 0) off++;
    _align = align;
    _size = (off + align - 1) ~/ align * align;
  }

  /// O tipo contém ponteiros (decide o `cap` do `append`, como o Go).
  final bool $ptrs;

  /// Zero value novo.
  final T Function() $zero;

  /// T a partir do valor canônico do kind: inteiro (`Golang.IntBase`),
  /// float (`double`), string (`Golang.String`), bool (`bool`), complex
  /// (`Golang.ComplexBase`) ou a representação sem nome do subjacente
  /// (`go.Slice`, `go.GoMap`, `go.GoArray`, a closure de uma func).
  final T Function(Object)? $conv;

  final RType Function()? _elemFn;
  final RType Function()? _keyFn;

  final int _len;
  final int _dir;
  final RType Function()? _underFn;

  /// O tipo subjacente (o próprio, se não tem nome ou é struct/interface).
  RType get $under => _underFn?.call() ?? this;

  /// `Len()` de array.
  int get $len => _underFn != null ? $under.$len : _len;

  /// `ChanDir` de chan (1 recv, 2 send, 3 ambos).
  int get $dir => _underFn != null ? $under.$dir : _dir;

  final List<RField> Function()? _fieldsFn;
  List<RField>? _fields;

  /// Method set de T (nomes Go ordenados); de uma interface, os métodos dela.
  final List<String> $methods;

  /// Method set de `*T` (structs e nomeados).
  final List<String> $ptrMethods;

  /// Assinatura Go de cada método, sem o receptor (`func(int) string`).
  final Map<String, String> $sigs;

  /// `(*T)(nil)` dentro de uma interface (a sentinela `T.$nil` de uma struct).
  final Object Function()? $nil;

  /// Descritor montado em runtime de um tipo sem descritor gerado (shim,
  /// genérico): os campos não são conhecidos.
  final bool $opaque;

  RType? get $elem => _elemFn?.call();
  RType? get $key => _keyFn?.call();

  List<RField> get $fields {
    final f = _fields;
    if (f != null) return f;
    final fn = _fieldsFn;
    if (fn == null) {
      if ($opaque && $kind == kStruct) {
        throw Panic(
          Golang.String.fromDart(
            'reflect: campos de ${$str} desconhecidos (tipo sem descritor gerado)',
          ),
        );
      }
      return _fields = const [];
    }
    final fs = _fields = fn();
    if (_size < 0) _layout(); // offsets de struct genérica
    return fs;
  }

  @override
  String toString() => $str;

  /// Struct ou array: o valor ocupa armazenamento próprio (`go.GoValue`), e
  /// `*T` é o próprio objeto.
  bool get $isValueKind => $kind == kStruct || $kind == kArray;

  /// Tipo anulável no Dart (ponteiro, interface, func, chan, unsafe.Pointer).
  bool get $nullable =>
      $kind == kPointer ||
      $kind == kInterface ||
      $kind == kFunc ||
      $kind == kChan ||
      $kind == kUnsafePointer;

  bool get $isComparable => switch ($kind) {
    kSlice || kMap || kFunc => false,
    kArray => $elem!.$isComparable,
    kStruct => $opaque || $fields.every((f) => f.type.$isComparable),
    _ => true,
  };

  // ------------------------------------------------------------ caches
  RType? _ptr;
  RType? _slice;
  Map<RType, RType>? _maps;
  Map<int, RType>? _arrays;
  Map<int, RType>? _chans;
  Elem<T>? _elemDesc;

  /// `go.Elem<T>` deste tipo (slices e maps criados pelo reflect).
  Elem<T> get $elemDesc => _elemDesc ??= Elem<T>(
    $size,
    $zero,
    pointers: $ptrs,
    value: $isValueKind,
    type: () => this,
  );

  /// `*T`.
  RType ptrTo() => _ptr ??= $isValueKind
      ? RType<T?>._(
          kPointer,
          '*${$str}',
          size: 8,
          align: 8,
          zero: () => null,
          ptrs: true,
          elem: () => this,
        )
      : RType<Ptr<T>?>._(
          kPointer,
          '*${$str}',
          size: 8,
          align: 8,
          zero: () => null,
          ptrs: true,
          elem: () => this,
        );

  /// `[]T`.
  RType sliceOf() => _slice ??= RType<Slice<T>>._(
    kSlice,
    '[]${$str}',
    size: 24,
    align: 8,
    zero: () => Slice<T>.nil($elemDesc),
    ptrs: true,
    conv: (v) => v as Slice<T>,
    elem: () => this,
  );

  /// `[n]T`.
  RType arrayOf(int n) => (_arrays ??= {})[n] ??= RType<GoArray<T>>._(
    kArray,
    '[$n]${$str}',
    size: $size * n,
    align: $align,
    zero: () => GoArray<T>.zero(n, $elemDesc),
    ptrs: $ptrs && n > 0,
    conv: (v) => v as GoArray<T>,
    elem: () => this,
    len: n,
  );

  /// `chan T` (dir 3), `<-chan T` (1), `chan<- T` (2).
  RType chanOf(int dir) => (_chans ??= {})[dir] ??= RType<Chan<T>?>._(
    kChan,
    '${const ['', '<-chan ', 'chan<- ', 'chan '][dir]}'
    '${dir == 3 && $kind == kChan && $dir == 1 ? '(${$str})' : $str}',
    size: 8,
    align: 8,
    zero: () => null,
    ptrs: true,
    elem: () => this,
    dir: dir,
  );

  /// `map[K]T` com K = [key] (despacho duplo: K e T reificados).
  RType $mapWithKey<K>(RType<K> key) =>
      (key._maps ??= {})[this] ??= RType<GoMap<K, T>>._(
        kMap,
        'map[${key.$str}]${$str}',
        size: 8,
        align: 8,
        zero: () => GoMap<K, T>.nil($elemDesc, key: key.$elemDesc),
        ptrs: true,
        conv: (v) => v as GoMap<K, T>,
        elem: () => this,
        key: () => key,
      );

  RType $keyOf(RType elem) => elem.$mapWithKey<T>(this);

  // ------------------------------------------------- operações reificadas
  /// `new(T)`: o ponteiro (objeto da struct/array, ou `go.Box<T>`).
  Object $newPtr() => $isValueKind ? $zero() as Object : Box<T>($zero());

  /// `make([]T, len, cap)`.
  Slice<T> $makeSlice(int len, int cap) => Slice<T>.make(len, cap, $elemDesc);

  /// `make(map[K]T)` com K = [key].
  GoMap $makeMapWithKey(RType key) => key.$makeMapOf<T>(this);

  GoMap<T, V> $makeMapOf<V>(RType<V> elem) => GoMap<T, V>(
    elem.$elemDesc,
    identity: $kind == kPointer && $elem!.$isValueKind,
    key: $elemDesc,
  );

  /// `(*T)(nil)` dentro de uma interface (este é o T apontado).
  Object $typedNil() => $nil?.call() ?? NilPtr<T>();

  /// Ponteiro para um lugar (campo, elemento) lido e escrito por closures.
  Ptr<T> $locPtr(Object? Function() get, void Function(Object?) set) =>
      _LocPtr<T>(get, set);

  /// Lista Dart de T (para `go.Slice<T>.append`).
  List<T> $listOf(Iterable<Object?> xs) => [for (final x in xs) x as T];

  /// T do Dart é exatamente X?
  bool $is<X>() => <T>[] is List<X> && <X>[] is List<T>;
}

/// `&v.Field(i)` / `&v.Index(i)` de um valor que não é struct/array.
final class _LocPtr<T> implements Ptr<T> {
  _LocPtr(this._get, this._set);

  final Object? Function() _get;
  final void Function(Object?) _set;

  @override
  T get value => _get() as T;

  @override
  set value(T v) => _set(v);

  @override
  bool $assignIfIs(Object? v) {
    if (v is! T) return false;
    _set(v);
    return true;
  }

  @override
  bool $errorTargetOk() => <T>[] is List<GoError?> || null is T;

  @override
  R $withElem<R>(R Function<E>() f) => f<T>();
}
