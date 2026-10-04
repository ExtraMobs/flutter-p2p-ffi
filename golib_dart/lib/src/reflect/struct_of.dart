part of '../../reflect.dart';

// `reflect.StructOf`: tipo struct montado em runtime. O valor é um
// [DynStruct] (uma classe só para todos esses tipos, com os campos numa
// lista); o descritor é um `RType<DynStruct>` comum, com layout amd64
// calculado no primeiro uso (tamanho -1, como o das structs genéricas).

/// Os dados de um tipo de `StructOf` que os valores dele compartilham.
final class _DynShape {
  _DynShape(this.types, this.names);

  /// Tipo de cada campo.
  final List<RType> types;

  /// Nome Go de cada campo (`%+v`).
  final List<String> names;

  late final RType<DynStruct> rt;

  /// Texto Go do tipo de cada campo (`%#v`).
  late final List<String> typeNames = [for (final t in types) t.$str];

  /// `(*T)(nil)` numa interface.
  late final DynStruct nilPtr = zero()..$nilPtr = true;

  DynStruct zero() => DynStruct._(this, [for (final t in types) t.$zero()]);
}

/// Valor de uma struct de `reflect.StructOf`: os campos na representação
/// do código gerado (struct/array aninhado é o próprio objeto, copiado com
/// o valor).
final class DynStruct extends GoStruct<DynStruct> implements Typed {
  DynStruct._(this._shape, this._vals);

  final _DynShape _shape;
  final List<Object?> _vals;

  @override
  RType get $rtype => _shape.rt;

  @override
  String get $goType => _shape.rt.$str;

  @override
  DynStruct $copy() {
    final ts = _shape.types;
    return DynStruct._(_shape, [
      for (var i = 0; i < ts.length; i++)
        ts[i].$isValueKind ? (_vals[i] as GoValue).$copy() : _vals[i],
    ]);
  }

  @override
  void $set(DynStruct o) {
    final ts = _shape.types;
    for (var i = 0; i < ts.length; i++) {
      _put(i, o._vals[i]);
    }
  }

  void _put(int i, Object? v) {
    if (_shape.types[i].$isValueKind) {
      (_vals[i] as GoValue).$setAny(v as Object);
    } else {
      _vals[i] = v;
    }
  }

  @override
  List<Object?> get $fields {
    final ts = _shape.types;
    return [
      for (var i = 0; i < ts.length; i++)
        switch (ts[i].$kind) {
          kPointer => Addr(_vals[i]),
          kInterface => dynField(_vals[i]),
          _ => _vals[i],
        },
    ];
  }

  @override
  List<String> get $fieldNames => _shape.names;

  @override
  List<String> get $fieldTypes => _shape.typeNames;

  /// `==` do Go: mesmo tipo e campos iguais; tipo não comparável panica.
  @override
  bool operator ==(Object other) {
    if (other is! DynStruct || !identical(other._shape, _shape)) return false;
    if (!_shape.rt.$isComparable) {
      throw Panic(
        RuntimeError(
          'runtime error: comparing uncomparable type ${_shape.rt.$str}',
        ),
      );
    }
    return super == other;
  }

  @override
  int get hashCode => super.hashCode;
}

/// Tipos de `StructOf` já criados, pelo texto (mais pacotes e embutidos);
/// tipos de campo comparados por identidade.
final _structOfCache = <String, List<(List<RType>, RType)>>{};

/// `reflect.StructOf(fields)`.
RType? structOf(Slice<StructField> fields) {
  final fs = fields.items.toList();
  if (fs.isEmpty) return rtEmptyStruct;
  var pkgpath = '';
  final seen = <String>{};
  final repr = StringBuffer('struct {');
  final key = StringBuffer();
  final types = <RType>[];
  for (var i = 0; i < fs.length; i++) {
    final f = fs[i];
    final name = f.name.toString();
    if (name.isEmpty) _structOfPanic('reflect.StructOf: field $i has no name');
    if (!_validFieldName(f.name)) {
      _structOfPanic('reflect.StructOf: field $i has invalid name');
    }
    final ft =
        f.type ?? _structOfPanic('reflect.StructOf: field $i has no type');
    final fpkg = f.pkgPath.toString();
    if (f.anonymous && fpkg.isNotEmpty) {
      _structOfPanic(
        'reflect.StructOf: field "$name" is anonymous but has PkgPath set',
      );
    }
    if (fpkg.isEmpty) {
      final c = name.codeUnitAt(0);
      if (c >= 0x61 && c <= 0x7a || c == 0x5f) {
        _structOfPanic(
          'reflect.StructOf: field "$name" is unexported but missing PkgPath',
        );
      }
    }
    if (fpkg.isNotEmpty) {
      if (pkgpath.isEmpty) {
        pkgpath = fpkg;
      } else if (pkgpath != fpkg) {
        _structOfPanic(
          'reflect.Struct: fields with different PkgPath $pkgpath and $fpkg',
        );
      }
    }
    if (f.anonymous) {
      _checkEmbedded(ft, i, fs.length);
    } else {
      repr.write(' $name');
    }
    if (!seen.add(name) && name != '_') {
      _structOfPanic('reflect.StructOf: duplicate field $name');
    }
    repr.write(' ${ft.$str}');
    final tag = f.tag.$str;
    if (tag.length > 0) repr.write(' ${strconv.quote(tag)}');
    if (i < fs.length - 1) repr.write(';');
    key.write('\x00$fpkg\x00${f.anonymous}');
    types.add(ft);
  }
  repr.write(' }');
  final str = repr.toString();
  final list = _structOfCache['$str$key'] ??= [];
  for (final (ts, t) in list) {
    var same = true;
    for (var i = 0; same && i < ts.length; i++) {
      same = identical(ts[i], types[i]);
    }
    if (same) return t;
  }
  final shape = _DynShape(types, [for (final f in fs) f.name.toString()]);
  final rfields = [
    for (var i = 0; i < fs.length; i++)
      RField(
        shape.names[i],
        fs[i].pkgPath.toString(),
        () => types[i],
        tag: fs[i].tag.$str.toString(),
        embedded: fs[i].anonymous,
        get: (o) => (o as DynStruct)._vals[i],
        set: (o, v) => (o as DynStruct)._put(i, v),
      ),
  ];
  final t = shape.rt = rtStruct<DynStruct>(
    '',
    '',
    str,
    size: -1,
    align: -1,
    zero: shape.zero,
    fields: () => rfields,
    ptrs: types.any((t) => t.$ptrs),
    nil: () => shape.nilPtr,
  );
  list.add((types, t));
  return t;
}

Never _structOfPanic(String msg) => throw Panic(Golang.String.fromDart(msg));

/// `isValidFieldName` do Go: letra (ou `_`) e depois letras e dígitos.
bool _validFieldName(Golang.String name) {
  var first = true;
  for (final c in name.runes()) {
    final letter =
        c >= 0x61 && c <= 0x7a ||
        c >= 0x41 && c <= 0x5a ||
        c == 0x5f ||
        c >= 0x80 && unicode.isLetter(Golang.Rune(c));
    if (first && !letter) return false;
    if (!letter && !unicode.isDigit(Golang.Rune(c))) return false;
    first = false;
  }
  return !first;
}

/// As restrições do Go para campo embutido de `StructOf` (os métodos do
/// embutido não são promovidos aqui: ver o ⚠️ em docs/mapping-spec.md).
void _checkEmbedded(RType ft, int i, int n) {
  if (ft.$kind == kPointer) {
    final k = ft.$elem!.$kind;
    if (k == kPointer || k == kInterface) {
      _structOfPanic(
        'reflect.StructOf: illegal embedded field type ${ft.$str}',
      );
    }
  }
  void exportedOnly(List<String> ms) {
    for (final m in ms) {
      if (m.isNotEmpty && !_exportedName(m)) {
        _structOfPanic(
          'reflect: embedded interface with unexported method(s) not implemented',
        );
      }
    }
  }

  switch (ft.$kind) {
    case kInterface:
      exportedOnly(ft.$methods);
    case kPointer:
      final e = ft.$elem!;
      final ms = ft.$name.isEmpty ? e.$ptrMethods : ft.$methods;
      if (ms.isNotEmpty) {
        if (i > 0) {
          _structOfPanic(
            'reflect: embedded type with methods not implemented if type is not first field',
          );
        }
        if (n > 1) {
          _structOfPanic(
            'reflect: embedded type with methods not implemented if there is more than one field',
          );
        }
        exportedOnly(ms);
      }
      exportedOnly(e.$methods);
    default:
      if (ft.$name.isNotEmpty || ft.$methods.isNotEmpty) {
        if (i > 0 && ft.$methods.isNotEmpty) {
          _structOfPanic(
            'reflect: embedded type with methods not implemented if type is not first field',
          );
        }
        if (n > 1 && _directIface(ft)) {
          _structOfPanic(
            'reflect: embedded type with methods not implemented for non-pointer type',
          );
        }
        exportedOnly(ft.$methods);
      }
  }
}

bool _exportedName(String m) {
  final c = m.substring(0, 1);
  return c.toUpperCase() == c && c.toLowerCase() != c;
}

/// O valor do tipo cabe direto na palavra de uma interface (`IsDirectIface`
/// do Go): ponteiros e struct/array de um elemento assim.
bool _directIface(RType t) => switch (t.$kind) {
  kPointer || kChan || kMap || kFunc || kUnsafePointer => true,
  kStruct =>
    !t.$opaque && t.$fields.length == 1 && _directIface(t.$fields[0].type),
  kArray => t.$len == 1 && _directIface(t.$elem!),
  _ => false,
};
