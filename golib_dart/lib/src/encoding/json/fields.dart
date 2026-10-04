part of '../../../encoding/json.dart';

// `typeFields` de `encode.go`, `tags.go` e `fold.go`: os campos JSON de uma
// struct (tag, embutidos com a regra do campo dominante, `omitempty`,
// `omitzero`, `string`) e a dobra de caixa do casamento no decode.

/// `field`.
final class _Field {
  _Field(this.name, this.index, this.typ);

  /// Nome JSON (bytes UTF-8 do Go).
  Uint8List name;
  bool tag = false;
  final List<int> index;
  final RType typ;
  bool omitEmpty = false;
  bool omitZero = false;
  bool Function(reflect.Value)? isZero;
  bool quoted = false;

  /// `"nome":` com e sem escape HTML.
  List<int> nameNonEsc = const [];
  List<int> nameEscHTML = const [];

  _EncFn? encoder;

  _Field copy() => _Field(name, index, typ)
    ..tag = tag
    ..omitEmpty = omitEmpty
    ..omitZero = omitZero
    ..isZero = isZero
    ..quoted = quoted
    ..nameNonEsc = nameNonEsc
    ..nameEscHTML = nameEscHTML
    ..encoder = encoder;
}

/// `structFields`.
final class _StructFields {
  _StructFields(this.list, this.byExactName, this.byFoldedName);
  final List<_Field> list;

  /// Chaves: os bytes do nome como string Latin-1 (injetivo).
  final Map<String, _Field> byExactName;
  final Map<String, _Field> byFoldedName;
}

String _key(List<int> b) => String.fromCharCodes(b);

/// `parseTag` + `tagOptions.Contains`.
(Uint8List, List<String>) _parseTag(Uint8List tag) {
  final i = tag.indexOf(0x2c);
  if (i < 0) return (tag, const []);
  final opts = String.fromCharCodes(tag.sublist(i + 1)).split(',');
  return (Uint8List.sublistView(tag, 0, i), opts);
}

const _tagPunct = r"!#$%&()*+-./:;<=>?@[]^_{|}~ ";

/// `isValidTag`.
bool _isValidTag(Uint8List s) {
  if (s.isEmpty) return false;
  for (final c in _gsb(s).runes()) {
    if (c < 0x80 && _tagPunct.contains(String.fromCharCode(c))) continue;
    if (!unicode.isLetter(Golang.Int32(c)) &&
        !unicode.isDigit(Golang.Int32(c))) {
      return false;
    }
  }
  return true;
}

/// `foldName`: ASCII em maiúsculas; o resto pelo menor da órbita do
/// `unicode.SimpleFold`.
String _foldName(List<int> inb) {
  final out = <int>[];
  var i = 0;
  while (i < inb.length) {
    final c = inb[i];
    if (c < 0x80) {
      out.add(c >= 0x61 && c <= 0x7a ? c - 0x20 : c);
      i++;
      continue;
    }
    final (r, n) = _decodeRune(inb, i);
    _appendRune(out, _foldRune(r));
    i += n;
  }
  return _key(out);
}

int _foldRune(int r) {
  for (;;) {
    final r2 = unicode.simpleFold(Golang.Int32(r)).toInt();
    if (r2 <= r) return r2;
    r = r2;
  }
}

int _compareIndex(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return a.length.compareTo(b.length);
}

final Map<RType, _StructFields> _fieldCache = {};

_StructFields _cachedTypeFields(RType t) => _fieldCache[t] ??= _typeFields(t);

bool _isQuotableKind(int k) => switch (k) {
  reflect.kBool ||
  reflect.kInt ||
  reflect.kInt8 ||
  reflect.kInt16 ||
  reflect.kInt32 ||
  reflect.kInt64 ||
  reflect.kUint ||
  reflect.kUint8 ||
  reflect.kUint16 ||
  reflect.kUint32 ||
  reflect.kUint64 ||
  reflect.kUintptr ||
  reflect.kFloat32 ||
  reflect.kFloat64 ||
  reflect.kString => true,
  _ => false,
};

/// `IsZero()` de um valor cujo method set tem o método (`isZeroer`): o
/// Dart chama o método `isZero` da classe gerada.
bool _callIsZero(Object? x) => (x as dynamic).isZero() as bool;

/// `typeFields`: os campos que o JSON reconhece em t, em ordem de índice.
_StructFields _typeFields(RType t) {
  var current = <_Field>[];
  var next = <_Field>[_Field(Uint8List(0), const [], t)];
  var count = <RType, int>{};
  var nextCount = <RType, int>{};
  final visited = <RType>{};
  final fields = <_Field>[];

  while (next.isNotEmpty) {
    final tmp = current;
    current = next;
    next = tmp..clear();
    count = nextCount;
    nextCount = {};

    for (final f in current) {
      if (!visited.add(f.typ)) continue;
      final rfs = f.typ.$fields;
      for (var i = 0; i < rfs.length; i++) {
        final sf = rfs[i];
        final exported = sf.pkg.isEmpty;
        if (sf.embedded) {
          var st = sf.type;
          if (st.$kind == reflect.kPointer) st = st.$elem!;
          if (!exported && st.$kind != reflect.kStruct) continue;
        } else if (!exported) {
          continue;
        }
        final tag = reflect.StructTag(_gs(sf.tag)).get(_gs('json')).toBytes();
        if (tag.length == 1 && tag[0] == 0x2d) continue;
        var (name, opts) = _parseTag(tag);
        if (!_isValidTag(name)) name = Uint8List(0);
        final index = [...f.index, i];

        var ft = sf.type;
        if (ft.$name.isEmpty && ft.$kind == reflect.kPointer) ft = ft.$elem!;

        final quoted = opts.contains('string') && _isQuotableKind(ft.$kind);

        if (name.isNotEmpty || !sf.embedded || ft.$kind != reflect.kStruct) {
          final tagged = name.isNotEmpty;
          if (name.isEmpty) name = _gs(sf.name).toBytes();
          final field = _Field(name, index, ft)
            ..tag = tagged
            ..omitEmpty = opts.contains('omitempty')
            ..omitZero = opts.contains('omitzero')
            ..quoted = quoted;
          final esc = <int>[];
          _appendHTMLEscape(esc, name);
          field.nameEscHTML = [0x22, ...esc, 0x22, 0x3a];
          field.nameNonEsc = [0x22, ...name, 0x22, 0x3a];
          if (field.omitZero) field.isZero = _isZeroFn(sf.type);

          fields.add(field);
          if ((count[f.typ] ?? 0) > 1) {
            // Dois campos no mesmo nível com a mesma struct embutida: os
            // dois se anulam (o dominantField vê a duplicata).
            fields.add(fields.last.copy());
          }
          continue;
        }

        nextCount[ft] = (nextCount[ft] ?? 0) + 1;
        if (nextCount[ft] == 1) {
          next.add(_Field(_gs(ft.$name).toBytes(), index, ft));
        }
      }
    }
  }

  fields.sort((a, b) {
    final c = _compareBytes(a.name, b.name);
    if (c != 0) return c;
    final d = a.index.length.compareTo(b.index.length);
    if (d != 0) return d;
    if (a.tag != b.tag) return a.tag ? -1 : 1;
    return _compareIndex(a.index, b.index);
  });

  final out = <_Field>[];
  for (var i = 0, advance = 0; i < fields.length; i += advance) {
    final fi = fields[i];
    for (advance = 1; i + advance < fields.length; advance++) {
      if (_compareBytes(fields[i + advance].name, fi.name) != 0) break;
    }
    if (advance == 1) {
      out.add(fi);
      continue;
    }
    final dominant = _dominantField(fields.sublist(i, i + advance));
    if (dominant != null) out.add(dominant);
  }

  out.sort((a, b) => _compareIndex(a.index, b.index));

  for (final f in out) {
    f.encoder = _typeEncoder(_typeByIndex(t, f.index));
  }
  final exact = <String, _Field>{};
  final folded = <String, _Field>{};
  for (final f in out) {
    exact[_key(f.name)] = f;
    folded.putIfAbsent(_foldName(f.name), () => f);
  }
  return _StructFields(out, exact, folded);
}

/// `dominantField`: o mais raso; empate de profundidade e de tag anula.
_Field? _dominantField(List<_Field> fields) {
  if (fields.length > 1 &&
      fields[0].index.length == fields[1].index.length &&
      fields[0].tag == fields[1].tag) {
    return null;
  }
  return fields[0];
}

/// `typeByIndex`.
RType _typeByIndex(RType t, List<int> index) {
  for (final i in index) {
    if (t.$kind == reflect.kPointer) t = t.$elem!;
    t = t.$fields[i].type;
  }
  return t;
}

/// O `isZero` de um campo `omitzero` cujo tipo tem `IsZero() bool`.
bool Function(reflect.Value)? _isZeroFn(RType t) {
  if (t.$kind == reflect.kInterface && _implements(t, _isZeroerType)) {
    return (v) =>
        v.isNil$() ||
        (_k(v.elem$()) == reflect.kPointer && v.elem$().isNil$()) ||
        _callIsZero(v.interface());
  }
  if (t.$kind == reflect.kPointer && _implements(t, _isZeroerType)) {
    return (v) => v.isNil$() || _callIsZero(v.interface());
  }
  if (_implements(t, _isZeroerType)) {
    return (v) => _callIsZero(v.interface());
  }
  if (_implements(t.ptrTo(), _isZeroerType)) {
    return (v) {
      if (!v.canAddr()) {
        final v2 = reflect.new$(v.type()).elem$();
        v2.set(v);
        v = v2;
      }
      return _callIsZero(v.addr$().interface());
    };
  }
  return null;
}
