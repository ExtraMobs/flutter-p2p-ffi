part of '../../../encoding/json.dart';

// Porta de `encode.go`: um codificador por tipo (cache por descritor, com
// a indireção do Go para tipos recursivos), escrito sobre o `reflect`.

/// `encOpts` como bits: `quoted` (opção `,string`) e `escapeHTML`.
const _optQuoted = 1, _optEscapeHTML = 2;

typedef _EncFn = void Function(_EncodeState e, reflect.Value v, int opts);

/// Kind do Value (`kInvalid` para o Value zero).
int _k(reflect.Value v) => v.$t?.$kind ?? reflect.kInvalid;

/// `startDetectingCyclesAfter`.
const _startDetectingCyclesAfter = 1000;

/// `encodeState`: a saída e o rastreio de ciclos.
final class _EncodeState {
  final List<int> buf = [];
  int ptrLevel = 0;
  final Map<Object, bool> ptrSeen = {};

  void writeString(String s) => buf.addAll(s.codeUnits);
  void writeByte(int c) => buf.add(c);

  /// `marshal`: o `jsonError` interno vira o erro devolvido.
  GoError? marshal(Object? v, int opts) {
    try {
      reflectValue(reflect.valueOf(v), opts);
      return null;
    } on _JsonError catch (je) {
      return je.err;
    }
  }

  Never error(GoError err) => throw _JsonError(err);

  void reflectValue(reflect.Value v, int opts) =>
      _valueEncoder(v)(this, v, opts);

  /// Entra num nível de ponteiro/map/slice; depois de 1000, [key] repetida
  /// é um ciclo. Devolve a chave a soltar no fim (ou null).
  Object? enter(reflect.Value v, Object? Function() key) {
    if (++ptrLevel <= _startDetectingCyclesAfter) return null;
    final k = key();
    if (k == null) return null;
    if (ptrSeen.containsKey(k)) {
      error(
        UnsupportedValueError(
          value: v,
          str: _gs('encountered a cycle via ${v.type()!.$str}'),
        ),
      );
    }
    ptrSeen[k] = true;
    return k;
  }

  void leave(Object? k) {
    if (k != null) ptrSeen.remove(k);
  }
}

/// Chave de identidade (o endereço do Go): o objeto, por identidade.
final class _Ident {
  _Ident(this.o);
  final Object o;
  @override
  bool operator ==(Object other) => other is _Ident && identical(other.o, o);
  @override
  int get hashCode => identityHashCode(o);
}

/// `isEmptyValue` (`omitempty`).
bool _isEmptyValue(reflect.Value v) {
  switch (_k(v)) {
    case reflect.kArray || reflect.kMap || reflect.kSlice || reflect.kString:
      return v.len().toInt() == 0;
    case reflect.kBool ||
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
        reflect.kInterface ||
        reflect.kPointer:
      return v.isZero();
  }
  return false;
}

final Map<RType, _EncFn> _encoderCache = {};

_EncFn _valueEncoder(reflect.Value v) {
  final t = v.$t;
  if (t == null) return _invalidValueEncoder;
  return _typeEncoder(t);
}

/// `typeEncoder`: o codificador de t, com cache. Um tipo recursivo vê a
/// indireção enquanto o seu próprio codificador é montado.
_EncFn _typeEncoder(RType t) {
  final f = _encoderCache[t];
  if (f != null) return f;
  _EncFn? real;
  _encoderCache[t] = (e, v, opts) => real!(e, v, opts);
  real = _newTypeEncoder(t, true);
  _encoderCache[t] = real;
  return real;
}

/// `json.Marshaler`, `encoding.TextMarshaler` e `isZeroer` como descritores
/// de interface (o `Implements` do Go é por method set).
final RType _marshalerType = reflect.rtNamedIface<Marshaler?>(
  'encoding/json',
  'Marshaler',
  'json.Marshaler',
  const ['MarshalJSON'],
);
final RType _textMarshalerType = reflect.rtNamedIface<encoding.TextMarshaler?>(
  'encoding',
  'TextMarshaler',
  'encoding.TextMarshaler',
  const ['MarshalText'],
);
final RType _isZeroerType = reflect.rtNamedIface<Object?>(
  'encoding/json',
  'isZeroer',
  'json.isZeroer',
  const ['IsZero'],
);

bool _implements(RType t, RType u) => reflect.TypeApi(t).implements(u);

_EncFn _newTypeEncoder(RType t, bool allowAddr) {
  if (_isRawMessage(t)) return _rawMessageEncoder;
  if (t.$kind != reflect.kPointer &&
      allowAddr &&
      _implements(t.ptrTo(), _marshalerType)) {
    return _condAddrEncoder(_addrMarshalerEncoder, _newTypeEncoder(t, false));
  }
  if (_implements(t, _marshalerType)) return _marshalerEncoder;
  if (t.$kind != reflect.kPointer &&
      allowAddr &&
      _implements(t.ptrTo(), _textMarshalerType)) {
    return _condAddrEncoder(
      _addrTextMarshalerEncoder,
      _newTypeEncoder(t, false),
    );
  }
  if (_implements(t, _textMarshalerType)) return _textMarshalerEncoder;

  switch (t.$kind) {
    case reflect.kBool:
      return _boolEncoder;
    case reflect.kInt ||
        reflect.kInt8 ||
        reflect.kInt16 ||
        reflect.kInt32 ||
        reflect.kInt64:
      return _intEncoder;
    case reflect.kUint ||
        reflect.kUint8 ||
        reflect.kUint16 ||
        reflect.kUint32 ||
        reflect.kUint64 ||
        reflect.kUintptr:
      return _uintEncoder;
    case reflect.kFloat32:
      return _float32Encoder;
    case reflect.kFloat64:
      return _float64Encoder;
    case reflect.kString:
      return _stringEncoder;
    case reflect.kInterface:
      return _interfaceEncoder;
    case reflect.kStruct:
      return _newStructEncoder(t);
    case reflect.kMap:
      return _newMapEncoder(t);
    case reflect.kSlice:
      return _newSliceEncoder(t);
    case reflect.kArray:
      return _newArrayEncoder(t);
    case reflect.kPointer:
      return _newPtrEncoder(t);
  }
  return _unsupportedTypeEncoder;
}

void _invalidValueEncoder(_EncodeState e, reflect.Value v, int opts) =>
    e.writeString('null');

/// O `MarshalJSON` de [m], compactado (com escape HTML) na saída.
void _writeMarshaled(_EncodeState e, reflect.Value v, Marshaler m, int opts) {
  final (b, err0) = m.marshalJSON();
  var err = err0;
  if (err == null) {
    err = _appendCompact(e.buf, _in(b), opts & _optEscapeHTML != 0);
  }
  if (err != null) {
    e.error(MarshalerError._(v.type(), err, 'MarshalJSON'));
  }
}

void _marshalerEncoder(_EncodeState e, reflect.Value v, int opts) {
  if (_k(v) == reflect.kPointer && v.isNil$()) {
    e.writeString('null');
    return;
  }
  final m = _assertIface<Marshaler>(v.$iface(), const ['MarshalJSON'], v.$t!);
  if (m == null) {
    e.writeString('null');
    return;
  }
  _writeMarshaled(e, v, m, opts);
}

void _addrMarshalerEncoder(_EncodeState e, reflect.Value v, int opts) {
  final va = v.addr$();
  if (va.isNil$()) {
    e.writeString('null');
    return;
  }
  final m = _assertIface<Marshaler>(va.$iface(), const [
    'MarshalJSON',
  ], va.$t!)!;
  _writeMarshaled(e, v, m, opts);
}

void _writeText(
  _EncodeState e,
  reflect.Value v,
  encoding.TextMarshaler m,
  int opts,
) {
  final (b, err) = m.marshalText();
  if (err != null) {
    e.error(MarshalerError._(v.type(), err, 'MarshalText'));
  }
  _appendString(e.buf, _in(b), opts & _optEscapeHTML != 0);
}

void _textMarshalerEncoder(_EncodeState e, reflect.Value v, int opts) {
  if (_k(v) == reflect.kPointer && v.isNil$()) {
    e.writeString('null');
    return;
  }
  final m = _assertIface<encoding.TextMarshaler>(v.$iface(), const [
    'MarshalText',
  ], v.$t!);
  if (m == null) {
    e.writeString('null');
    return;
  }
  _writeText(e, v, m, opts);
}

void _addrTextMarshalerEncoder(_EncodeState e, reflect.Value v, int opts) {
  final va = v.addr$();
  if (va.isNil$()) {
    e.writeString('null');
    return;
  }
  final m = _assertIface<encoding.TextMarshaler>(va.$iface(), const [
    'MarshalText',
  ], va.$t!)!;
  _writeText(e, v, m, opts);
}

/// `json.RawMessage` por descritor: o `MarshalJSON` dele (os bytes, ou
/// `null` para o nil), compactado como o de qualquer `Marshaler`.
void _rawMessageEncoder(_EncodeState e, reflect.Value v, int opts) {
  final m = v.$rep as Slice<Golang.Uint8>;
  final (b, _) = m.marshalJSON();
  final err = _appendCompact(e.buf, _in(b), opts & _optEscapeHTML != 0);
  if (err != null) e.error(MarshalerError._(v.type(), err, 'MarshalJSON'));
}
