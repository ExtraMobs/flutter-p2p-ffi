part of '../../../encoding/json.dart';

// Porta de `decode.go` (estrutura): o `decodeState` percorre os bytes já
// validados com o mesmo scanner e grava pelo `reflect`.

const _phasePanicMsg = 'JSON decoder out of sync - data changing underfoot?';

Never _phasePanic() => throw Panic(_gs(_phasePanicMsg));

/// `errorContext`.
final class _ErrorContext {
  RType? struct;
  List<String> fieldStack = [];
}

/// `json.Unmarshaler` e `encoding.TextUnmarshaler` como descritores.
final RType _unmarshalerType = reflect.rtNamedIface<Unmarshaler?>(
  'encoding/json',
  'Unmarshaler',
  'json.Unmarshaler',
  const ['UnmarshalJSON'],
);
final RType _textUnmarshalerType = reflect
    .rtNamedIface<encoding.TextUnmarshaler?>(
      'encoding',
      'TextUnmarshaler',
      'encoding.TextUnmarshaler',
      const ['UnmarshalText'],
    );

/// `decodeState`.
final class _DecodeState {
  Uint8List data = Uint8List(0);

  /// O `[]byte` de onde [data] veio: o `UnmarshalJSON` recebe um pedaço
  /// dele, como no Go.
  _Bytes? src;
  int off = 0;
  int opcode = 0;
  final _Scanner scan = _Scanner();
  _ErrorContext? errorContext;
  GoError? savedError;
  bool useNumber = false;
  bool disallowUnknownFields = false;

  int readIndex() => off - 1;

  void init(Uint8List d, _Bytes? s) {
    data = d;
    src = s;
    off = 0;
    savedError = null;
    final ec = errorContext;
    if (ec != null) {
      ec.struct = null;
      ec.fieldStack = [];
    }
  }

  /// `d.data[start:end]` como `[]byte`.
  _Bytes sub(int start, int end) {
    final s = src;
    if (s != null) return s.slice(start, end);
    return _out(Uint8List.sublistView(data, start, end));
  }

  GoError? unmarshal(Object? v) {
    final rv = reflect.valueOf(v);
    if (_k(rv) != reflect.kPointer || rv.isNil$()) {
      return InvalidUnmarshalError(type: reflect.typeOf(v));
    }
    scan.reset();
    scanWhile(_scanSkipSpace);
    final err = value(rv);
    if (err != null) return addErrorContext(err);
    return savedError;
  }

  void saveError(GoError err) {
    savedError ??= addErrorContext(err);
  }

  GoError addErrorContext(GoError err) {
    final ec = errorContext;
    if (ec != null && (ec.struct != null || ec.fieldStack.isNotEmpty)) {
      if (err is UnmarshalTypeError) {
        err.struct = _gs(ec.struct!.$name);
        final stack = [...ec.fieldStack];
        if (err.field.length != 0) stack.add(err.field.toString());
        err.field = _gs(stack.join('.'));
      }
    }
    return err;
  }

  void skip() {
    final s = scan;
    var i = off;
    final depth = s.parseState.length;
    for (;;) {
      final op = s.step(s, data[i]);
      i++;
      if (s.parseState.length < depth) {
        off = i;
        opcode = op;
        return;
      }
    }
  }

  void scanNext() {
    if (off < data.length) {
      opcode = scan.step(scan, data[off]);
      off++;
    } else {
      opcode = scan.eof();
      off = data.length + 1;
    }
  }

  void scanWhile(int op) {
    final s = scan;
    var i = off;
    while (i < data.length) {
      final newOp = s.step(s, data[i]);
      i++;
      if (newOp != op) {
        opcode = newOp;
        off = i;
        return;
      }
    }
    off = data.length + 1;
    opcode = scan.eof();
  }

  void rescanLiteral() {
    var i = off;
    switch (data[i - 1]) {
      case 0x22:
        for (; i < data.length; i++) {
          final c = data[i];
          if (c == 0x5c) {
            i++;
          } else if (c == 0x22) {
            i++;
            break;
          }
        }
      case 0x30 ||
          0x31 ||
          0x32 ||
          0x33 ||
          0x34 ||
          0x35 ||
          0x36 ||
          0x37 ||
          0x38 ||
          0x39 ||
          0x2d:
        for (; i < data.length; i++) {
          final c = data[i];
          if (!(_isDigit(c) ||
              c == 0x2e ||
              c == 0x65 ||
              c == 0x45 ||
              c == 0x2b ||
              c == 0x2d)) {
            break;
          }
        }
      case 0x74:
        i += 3;
      case 0x66:
        i += 4;
      case 0x6e:
        i += 3;
    }
    if (i < data.length) {
      opcode = _stateEndValue(scan, data[i]);
    } else {
      opcode = _scanEnd;
    }
    off = i + 1;
  }

  GoError? value(reflect.Value v) {
    switch (opcode) {
      case _scanBeginArray:
        if (v.isValid()) {
          final err = this.array(v);
          if (err != null) return err;
        } else {
          skip();
        }
        scanNext();
      case _scanBeginObject:
        if (v.isValid()) {
          final err = this.object(v);
          if (err != null) return err;
        } else {
          skip();
        }
        scanNext();
      case _scanBeginLiteral:
        final start = readIndex();
        rescanLiteral();
        if (v.isValid()) {
          final err = this.literalStore(
            Uint8List.sublistView(data, start, readIndex()),
            v,
            false,
          );
          if (err != null) return err;
        }
      default:
        _phasePanic();
    }
    return null;
  }

  /// `valueQuoted`: o literal de um campo `,string` (nil, string ou
  /// [_unquoted]).
  Object? valueQuoted() {
    switch (opcode) {
      case _scanBeginArray || _scanBeginObject:
        skip();
        scanNext();
      case _scanBeginLiteral:
        final v = this.literalInterface();
        if (v == null || v is Golang.String) return v;
      default:
        _phasePanic();
    }
    return _unquoted;
  }
}
