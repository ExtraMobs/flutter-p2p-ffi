part of '../../reflect.dart';

/// `reflect.StructTag` (`type StructTag string`).
final class StructTag extends Golang.StringBase<StructTag> {
  StructTag([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;

  @override
  StructTag $wrapStr(Golang.String s) => StructTag(s);

  @override
  String get $goType => 'reflect.StructTag';

  @override
  List<String> get $methods => const ['Get', 'Lookup'];

  /// `StructTag.Get(key)`.
  Golang.String get(Golang.String key) => lookup$(key).$1;

  /// `StructTag.Lookup(key)`: a convenção `key:"value" key2:"value2"`, com o
  /// valor entre aspas desfeito pelo `strconv.Unquote` (port do Go).
  (Golang.String, bool) lookup$(Golang.String key) {
    var tag = _v.toBytes();
    final want = key.toBytes();
    while (tag.isNotEmpty) {
      var i = 0;
      while (i < tag.length && tag[i] == 0x20) {
        i++;
      }
      tag = Uint8List.sublistView(tag, i);
      if (tag.isEmpty) break;
      i = 0;
      while (i < tag.length &&
          tag[i] > 0x20 &&
          tag[i] != 0x3a &&
          tag[i] != 0x22 &&
          tag[i] != 0x7f) {
        i++;
      }
      if (i == 0 ||
          i + 1 >= tag.length ||
          tag[i] != 0x3a ||
          tag[i + 1] != 0x22) {
        break;
      }
      final name = Uint8List.sublistView(tag, 0, i);
      tag = Uint8List.sublistView(tag, i + 1);
      i = 1;
      while (i < tag.length && tag[i] != 0x22) {
        if (tag[i] == 0x5c) i++;
        i++;
      }
      if (i >= tag.length) break;
      final qvalue = Golang.String.fromBytes(
        Uint8List.sublistView(tag, 0, i + 1),
      );
      tag = Uint8List.sublistView(tag, i + 1);
      if (_eqBytes(name, want)) {
        final (value, err) = strconv.unquote(qvalue);
        if (err != null) break;
        return (value, true);
      }
    }
    return (Golang.String(), false);
  }
}

bool _eqBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// `reflect.StructField`.
final class StructField extends GoStruct<StructField> {
  StructField({
    Golang.String? name,
    Golang.String? pkgPath,
    this.type,
    StructTag? tag,
    Golang.Uintptr? offset,
    Slice<Golang.Int>? index,
    this.anonymous = false,
  }) : name = name ?? Golang.String(),
       pkgPath = pkgPath ?? Golang.String(),
       tag = tag ?? StructTag(),
       offset = offset ?? Golang.Uintptr(),
       index = index ?? Slice<Golang.Int>.nil(_intElem);

  static final StructField $nil = StructField()..$nilPtr = true;

  Golang.String name;
  Golang.String pkgPath;
  RType? type;
  StructTag tag;
  Golang.Uintptr offset;
  Slice<Golang.Int> index;
  bool anonymous;

  @override
  String get $goType => 'reflect.StructField';

  @override
  List<String> get $valueMethods => const ['IsExported'];

  @override
  List<String> get $ptrMethods => const ['IsExported'];

  @override
  StructField $copy() => StructField(
    name: name,
    pkgPath: pkgPath,
    type: type,
    tag: tag,
    offset: offset,
    index: index,
    anonymous: anonymous,
  );

  @override
  void $set(StructField o) {
    name = o.name;
    pkgPath = o.pkgPath;
    type = o.type;
    tag = o.tag;
    offset = o.offset;
    index = o.index;
    anonymous = o.anonymous;
  }

  @override
  List<Object?> get $fields => [
    name,
    pkgPath,
    type,
    tag,
    offset,
    index,
    anonymous,
  ];

  @override
  List<String> get $fieldNames => const [
    'Name',
    'PkgPath',
    'Type',
    'Tag',
    'Offset',
    'Index',
    'Anonymous',
  ];

  /// `StructField.IsExported()`.
  bool isExported() => pkgPath.length == 0;
}

const _intElem = Elem<Golang.Int>(8, Golang.Int.new);

/// O `StructField` do Go para o campo [i] de [t] ([index]: o caminho).
StructField _structField(RField f, List<int> index) => StructField(
  name: Golang.String.fromDart(f.name),
  pkgPath: Golang.String.fromDart(f.pkg),
  type: f.type,
  tag: StructTag(Golang.String.fromDart(f.tag)),
  offset: Golang.Uintptr(f.offset),
  index: Slice<Golang.Int>.of([for (final i in index) Golang.Int(i)], _intElem),
  anonymous: f.embedded,
);

/// `reflect.Method`.
final class Method extends GoStruct<Method> {
  Method({
    Golang.String? name,
    Golang.String? pkgPath,
    this.type,
    Value? func,
    Golang.Int? index,
  }) : name = name ?? Golang.String(),
       pkgPath = pkgPath ?? Golang.String(),
       func = func ?? Value(),
       index = index ?? Golang.Int();

  static final Method $nil = Method()..$nilPtr = true;

  Golang.String name;
  Golang.String pkgPath;
  RType? type;
  Value func;
  Golang.Int index;

  @override
  String get $goType => 'reflect.Method';

  @override
  List<String> get $valueMethods => const ['IsExported'];

  @override
  List<String> get $ptrMethods => const ['IsExported'];

  @override
  Method $copy() => Method(
    name: name,
    pkgPath: pkgPath,
    type: type,
    func: func.$copy(),
    index: index,
  );

  @override
  void $set(Method o) {
    name = o.name;
    pkgPath = o.pkgPath;
    type = o.type;
    func.$set(o.func);
    index = o.index;
  }

  @override
  List<Object?> get $fields => [name, pkgPath, type, func, index];

  @override
  List<String> get $fieldNames => const [
    'Name',
    'PkgPath',
    'Type',
    'Func',
    'Index',
  ];

  /// `Method.IsExported()`.
  bool isExported() => pkgPath.length == 0;
}

/// `*reflect.ValueError`: método de `Value` chamado num kind errado.
final class ValueError implements GoError, GoOpaqueStruct {
  ValueError({Golang.String? method, Kind? kind})
    : method = method ?? Golang.String(),
      kind = kind ?? Kind();

  Golang.String method;
  Kind kind;

  @override
  Golang.String error() => Golang.String.fromDart(
    kind.toInt() == kInvalid
        ? 'reflect: call of $method on zero Value'
        : 'reflect: call of $method on ${kindName(kind.toInt())} Value',
  );

  @override
  String get $goType => '*reflect.ValueError';

  @override
  List<String> get $methods => const ['Error'];

  @override
  List<Object?> get $fields => [method, kind];

  @override
  List<String> get $fieldNames => const ['Method', 'Kind'];

  @override
  List<String> get $fieldTypes => const ['string', 'reflect.Kind'];
}

Never _kindPanic(String method, int kind) => throw Panic(
  ValueError(method: Golang.String.fromDart(method), kind: Kind(kind)),
);
