part of '../../reflect.dart';

// Descritores dos tipos predeclarados e construtores usados pelo código
// gerado (reexportados por `builtin.dart`, prefixo `go`).

RType<T> _basic<T>(
  int kind,
  String name,
  int size,
  T Function() zero,
  T Function(Object) conv, {
  bool ptrs = false,
}) => RType<T>._(
  kind,
  name,
  name: name,
  size: size,
  align: size > 8 ? 8 : size,
  zero: zero,
  conv: conv,
  ptrs: ptrs,
);

Golang.IntBase _i(Object v) => v as Golang.IntBase;

final rtBool = _basic<bool>(kBool, 'bool', 1, () => false, (v) => v as bool);
final rtInt = _basic<Golang.Int>(
  kInt,
  'int',
  8,
  Golang.Int.new,
  (v) => Golang.Int.from(_i(v)),
);
final rtInt8 = _basic<Golang.Int8>(
  kInt8,
  'int8',
  1,
  Golang.Int8.new,
  (v) => Golang.Int8.from(_i(v)),
);
final rtInt16 = _basic<Golang.Int16>(
  kInt16,
  'int16',
  2,
  Golang.Int16.new,
  (v) => Golang.Int16.from(_i(v)),
);
final rtInt32 = _basic<Golang.Int32>(
  kInt32,
  'int32',
  4,
  Golang.Int32.new,
  (v) => Golang.Int32.from(_i(v)),
);
final rtInt64 = _basic<Golang.Int64>(
  kInt64,
  'int64',
  8,
  Golang.Int64.new,
  (v) => Golang.Int64.from(_i(v)),
);
final rtUint = _basic<Golang.Uint>(
  kUint,
  'uint',
  8,
  Golang.Uint.new,
  (v) => Golang.Uint.from(_i(v)),
);
final rtUint8 = _basic<Golang.Uint8>(
  kUint8,
  'uint8',
  1,
  Golang.Uint8.new,
  (v) => Golang.Uint8.from(_i(v)),
);
final rtUint16 = _basic<Golang.Uint16>(
  kUint16,
  'uint16',
  2,
  Golang.Uint16.new,
  (v) => Golang.Uint16.from(_i(v)),
);
final rtUint32 = _basic<Golang.Uint32>(
  kUint32,
  'uint32',
  4,
  Golang.Uint32.new,
  (v) => Golang.Uint32.from(_i(v)),
);
final rtUint64 = _basic<Golang.Uint64>(
  kUint64,
  'uint64',
  8,
  Golang.Uint64.new,
  (v) => Golang.Uint64.from(_i(v)),
);
final rtUintptr = _basic<Golang.Uintptr>(
  kUintptr,
  'uintptr',
  8,
  Golang.Uintptr.new,
  (v) => Golang.Uintptr.from(_i(v)),
);
final rtFloat32 = _basic<Golang.Float32>(
  kFloat32,
  'float32',
  4,
  Golang.Float32.new,
  (v) => Golang.Float32(v as double),
);
final rtFloat64 = _basic<Golang.Float64>(
  kFloat64,
  'float64',
  8,
  Golang.Float64.new,
  (v) => Golang.Float64(v as double),
);
final rtComplex64 = _basic<Golang.Complex64>(
  kComplex64,
  'complex64',
  8,
  Golang.Complex64.new,
  (v) => Golang.Complex64.fromComplex128(v as Golang.Complex128),
);
final rtComplex128 = _basic<Golang.Complex128>(
  kComplex128,
  'complex128',
  16,
  Golang.Complex128.new,
  (v) => v as Golang.Complex128,
);
final rtString = _basic<Golang.String>(
  kString,
  'string',
  16,
  Golang.String.new,
  (v) => v as Golang.String,
  ptrs: true,
);
final rtUnsafePointer = RType<Object?>._(
  kUnsafePointer,
  'unsafe.Pointer',
  name: 'Pointer',
  pkg: 'unsafe',
  size: 8,
  align: 8,
  zero: () => null,
  ptrs: true,
);

/// `interface {}` / `any`.
final rtAny = RType<Object?>._(
  kInterface,
  'interface {}',
  size: 16,
  align: 8,
  zero: () => null,
  ptrs: true,
);

/// `error`.
final rtError = RType<GoError?>._(
  kInterface,
  'error',
  name: 'error',
  size: 16,
  align: 8,
  zero: () => null,
  ptrs: true,
  methods: const ['Error'],
  sigs: {'Error': () => _errorSig},
);

/// `*T`.
RType rtPtr(RType t) => t.ptrTo();

/// `[]T`.
RType rtSlice(RType t) => t.sliceOf();

/// `[n]T`.
RType rtArray(int n, RType t) => t.arrayOf(n);

/// `map[K]V`.
RType rtMap(RType k, RType v) => k.$keyOf(v);

/// `chan T` (dir: 1 `<-chan`, 2 `chan<-`, 3 `chan`).
RType rtChan(int dir, RType t) => t.chanOf(dir);

final _funcs = <String, RType>{};

final _errorSig = rtFuncOf<Golang.String Function()?>(
  'func() string',
  () => const [],
  () => [rtString],
);

/// Tipo func sem nome pela assinatura Go (`func(int) string`), sem os
/// parâmetros descritos: o de [rtFuncOf] com a mesma assinatura, se já
/// existe.
RType rtFunc(String sig) => _funcs[sig] ??= RType<Object?>._(
  kFunc,
  sig,
  size: 8,
  align: 8,
  zero: () => null,
  ptrs: true,
  conv: (v) => v,
);

/// Tipo func sem nome descrito pelo g2d: [ins]/[outs] (thunks: tipos
/// recursivos), variádico (o último de [ins] é o `[]E`) e a cor `async` da
/// assinatura (a closure Dart devolve `Future`). [sig] vazio: o texto Go
/// sai dos tipos (assinatura com parâmetro de tipo). T é o tipo Dart
/// anulável da closure. Canônico pelo texto Go.
RType rtFuncOf<T>(
  String sig,
  List<RType> Function() ins,
  List<RType> Function() outs, {
  bool variadic = false,
  bool async = false,
}) {
  if (sig.isEmpty) sig = _funcSig(ins(), outs(), variadic);
  final old = _funcs[sig];
  if (old != null) {
    old._fnInfo ??= RFunc(ins, outs, variadic, async);
    return old;
  }
  return _funcs[sig] = RType<T>._(
    kFunc,
    sig,
    size: 8,
    align: 8,
    zero: () => null as T,
    ptrs: true,
    conv: (v) => v as T,
  ).._fnInfo = RFunc(ins, outs, variadic, async);
}

/// Texto Go de uma assinatura (`func(int, ...string) (bool, error)`).
String _funcSig(List<RType> ins, List<RType> outs, bool variadic) {
  final ps = [
    for (var i = 0; i < ins.length; i++)
      variadic && i == ins.length - 1
          ? '...${ins[i].$elem!.$str}'
          : ins[i].$str,
  ];
  final r = switch (outs.length) {
    0 => '',
    1 => ' ${outs[0].$str}',
    _ => ' (${outs.map((t) => t.$str).join(', ')})',
  };
  return 'func(${ps.join(', ')})$r';
}

final _ifaces = <String, RType>{};

/// Interface sem nome com estes métodos (`interface { M() }`); [str] é o
/// texto Go do tipo.
RType rtIface(
  String str,
  List<String> methods, {
  Map<String, RType Function()> sigs = const {},
}) => methods.isEmpty
    ? rtAny
    : _ifaces[str] ??= RType<Object?>._(
        kInterface,
        str,
        size: 16,
        align: 8,
        zero: () => null,
        ptrs: true,
        methods: methods,
        sigs: sigs,
      );

/// Interface nomeada (`type Stringer interface{...}`). T é a classe Dart
/// anulável da interface.
RType<T> rtNamedIface<T>(
  String pkg,
  String name,
  String str,
  List<String> methods, {
  Map<String, RType Function()> sigs = const {},
}) => RType<T>._(
  kInterface,
  str,
  name: name,
  pkg: pkg,
  size: 16,
  align: 8,
  zero: () => null as T,
  ptrs: true,
  methods: methods,
  sigs: sigs,
);

/// Struct (nomeada ou sem nome: [name] vazio). [fields] é um thunk (tipos
/// recursivos); [nil] devolve a sentinela `T.$nil`.
RType<T> rtStruct<T>(
  String pkg,
  String name,
  String str, {
  required int size,
  required int align,
  required T Function() zero,
  required List<RField> Function() fields,
  bool ptrs = false,
  List<String> methods = const [],
  List<String> ptrMethods = const [],
  Map<String, RType Function()> sigs = const {},
  Map<String, Function Function(Object)> binds = const {},
  Map<String, Function Function(Object)> pbinds = const {},
  Object Function()? nil,
}) => RType<T>._(
  kStruct,
  str,
  name: name,
  pkg: pkg,
  size: size,
  align: align,
  zero: zero,
  fields: fields,
  ptrs: ptrs,
  methods: methods,
  ptrMethods: ptrMethods,
  sigs: sigs,
  binds: binds,
  pbinds: pbinds,
  nil: nil,
);

/// Tipo nomeado que não é struct nem interface: kind, elem, key e len vêm do
/// subjacente [under]; [conv] cria o nomeado a partir do valor canônico.
RType<T> rtNamed<T>(
  String pkg,
  String name,
  String str,
  RType Function() under, {
  required int kind,
  required int size,
  required int align,
  required T Function() zero,
  T Function(Object)? conv,
  bool ptrs = false,
  List<String> methods = const [],
  List<String> ptrMethods = const [],
  Map<String, RType Function()> sigs = const {},
  Map<String, Function Function(Object)> binds = const {},
  Map<String, Function Function(Object)> pbinds = const {},
  Object Function()? nil,
}) => RType<T>._(
  kind,
  str,
  name: name,
  pkg: pkg,
  size: size,
  align: align,
  zero: zero,
  conv: conv,
  ptrs: ptrs,
  elem: () => under().$elem!,
  key: () => under().$key!,
  methods: methods,
  ptrMethods: ptrMethods,
  sigs: sigs,
  binds: binds,
  pbinds: pbinds,
  nil: nil,
  under: under,
);

final _generics = <String, List<(List<RType>, RType)>>{};

/// Instância de tipo genérico (`Box[int]`): uma por argumentos de tipo
/// (comparados por identidade), montada por [build] com o `Name()` e o
/// `String()` do Go (`Box[int]`, `main.Box[int]`; argumento nomeado com o
/// import path inteiro, como o runtime do Go escreve).
RType<T> rtGeneric<T>(
  String pkg,
  String name,
  String short,
  List<RType> args,
  RType<T> Function(String name, String str) build,
) {
  final list = _generics['$pkg.$name'] ??= [];
  for (final (a, t) in list) {
    var same = a.length == args.length;
    for (var i = 0; same && i < a.length; i++) {
      same = identical(a[i], args[i]);
    }
    if (same) return t as RType<T>;
  }
  final n = '$name[${args.map(_fullStr).join(',')}]';
  final t = build(n, '$short.$n');
  list.add((args, t));
  return t;
}

/// Texto de um tipo com o import path inteiro dos nomeados (argumentos de
/// tipo de genérico).
String _fullStr(RType t) {
  if (t.$name.isNotEmpty) {
    return t.$pkg.isEmpty ? t.$name : '${t.$pkg}.${t.$name}';
  }
  return switch (t.$kind) {
    kPointer => '*${_fullStr(t.$elem!)}',
    kSlice => '[]${_fullStr(t.$elem!)}',
    kArray => '[${t.$len}]${_fullStr(t.$elem!)}',
    kMap => 'map[${_fullStr(t.$key!)}]${_fullStr(t.$elem!)}',
    kChan => switch (t.$dir) {
      1 => '<-chan ${_fullStr(t.$elem!)}',
      2 => 'chan<- ${_fullStr(t.$elem!)}',
      _ => 'chan ${_fullStr(t.$elem!)}',
    },
    _ => t.$str,
  };
}

/// Campo de struct para [rtStruct].
RField rtField(
  String name,
  String pkg,
  RType Function() type, {
  String tag = '',
  bool embedded = false,
  int offset = 0,
  Object? Function(Object)? get,
  void Function(Object, Object?)? set,
}) => RField(
  name,
  pkg,
  type,
  tag: tag,
  embedded: embedded,
  offset: offset,
  get: get,
  set: set,
);

final _opaque = <String, RType>{};

/// Descritor montado em runtime para um tipo sem descritor gerado (tipo de
/// shim, instância de genérico): nome Go e kind; campos desconhecidos. O
/// primeiro uso de cada nome fixa o descritor (canônico daí em diante).
/// Interface nomeada de um shim (`json.Marshaler`...): o g2d a descreve em
/// cada uso, então o descritor é canônico pelo nome.
RType<T> rtShimIface<T>(
  String pkg,
  String name,
  String str,
  List<String> methods, {
  Map<String, RType Function()> sigs = const {},
}) =>
    (_shimIfaces['$pkg.$name'] ??= rtNamedIface<T>(
          pkg,
          name,
          str,
          methods,
          sigs: sigs,
        ))
        as RType<T>;

final _shimIfaces = <String, RType>{};

/// A interface de shim [key] (`pkg.Nome`) já descrita: o g2d cita assim a
/// própria interface dentro das assinaturas dela (`thunk`).
RType rtShimIfaceRef(String key) => _shimIfaces[key]!;

RType rtOpaque(
  String goType,
  int kind, {
  List<String> methods = const [],
  List<String> ptrMethods = const [],
}) {
  final dot = goType.lastIndexOf('.');
  return _opaque['$kind $goType'] ??= RType<Object?>._(
    kind,
    goType,
    name: dot >= 0 ? goType.substring(dot + 1) : goType,
    pkg: dot >= 0 ? goType.substring(0, dot) : '',
    size: 8,
    align: 8,
    zero: () => null,
    ptrs: true,
    methods: methods,
    ptrMethods: ptrMethods,
    opaque: true,
  );
}
