part of '../../../encoding/json.dart';

// `encode.go` (compostos): struct, map (chaves ordenadas), slice, array
// e ponteiro.

_EncFn _newStructEncoder(RType t) {
  final fields = _cachedTypeFields(t);
  return (e, v, opts) {
    var next = 0x7b;
    fieldLoop:
    for (final f in fields.list) {
      var fv = v;
      for (final i in f.index) {
        if (_k(fv) == reflect.kPointer) {
          if (fv.isNil$()) continue fieldLoop;
          fv = fv.elem$();
        }
        fv = fv.field(Golang.Int(i));
      }
      if ((f.omitEmpty && _isEmptyValue(fv)) ||
          (f.omitZero &&
              (f.isZero == null && fv.isZero() ||
                  (f.isZero != null && f.isZero!(fv))))) {
        continue;
      }
      e.writeByte(next);
      next = 0x2c;
      e.buf.addAll(opts & _optEscapeHTML != 0 ? f.nameEscHTML : f.nameNonEsc);
      final o = (opts & _optEscapeHTML) | (f.quoted ? _optQuoted : 0);
      f.encoder!(e, fv, o);
    }
    if (next == 0x7b) {
      e.writeString('{}');
    } else {
      e.writeByte(0x7d);
    }
  };
}

_EncFn _newMapEncoder(RType t) {
  switch (t.$key!.$kind) {
    case reflect.kString ||
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
        reflect.kUintptr:
      break;
    default:
      if (!_implements(t.$key!, _textMarshalerType)) {
        return _unsupportedTypeEncoder;
      }
  }
  final elemEnc = _typeEncoder(t.$elem!);
  return (e, v, opts) {
    if (v.isNil$()) {
      e.writeString('null');
      return;
    }
    final seen = e.enter(v, () => _Ident(v.$rep!));
    e.writeByte(0x7b);
    final sv = <(Uint8List, reflect.Value)>[];
    final mi = v.mapRange();
    while (mi.next()) {
      final (ks, err) = _resolveKeyName(mi.key());
      if (err != null) {
        e.error(
          _errorf(
            'json: encoding error for type ${_q(v.type()!.$str.codeUnits)}: '
            '${_q(err.error().toBytes())}',
          ),
        );
      }
      sv.add((ks, mi.value$()));
    }
    sv.sort((a, b) => _compareBytes(a.$1, b.$1));
    for (var i = 0; i < sv.length; i++) {
      if (i > 0) e.writeByte(0x2c);
      _appendString(e.buf, sv[i].$1, opts & _optEscapeHTML != 0);
      e.writeByte(0x3a);
      elemEnc(e, sv[i].$2, opts);
    }
    e.writeByte(0x7d);
    e.ptrLevel--;
    e.leave(seen);
  };
}

int _compareBytes(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return a.length.compareTo(b.length);
}

/// `resolveKeyName`: string, `TextMarshaler` ou inteiro.
(Uint8List, GoError?) _resolveKeyName(reflect.Value k) {
  if (_k(k) == reflect.kString) return (k.string().toBytes(), null);
  final t = k.$t!;
  if (_implements(t, _textMarshalerType)) {
    final tm = _assertIface<encoding.TextMarshaler>(k.$iface(), const [
      'MarshalText',
    ], t);
    if (tm != null) {
      if (_k(k) == reflect.kPointer && k.isNil$()) return (Uint8List(0), null);
      final (buf, err) = tm.marshalText();
      return (_in(buf), err);
    }
  }
  switch (_k(k)) {
    case reflect.kInt ||
        reflect.kInt8 ||
        reflect.kInt16 ||
        reflect.kInt32 ||
        reflect.kInt64:
      return (strconv.formatInt(k.int$(), Golang.Int(10)).toBytes(), null);
    case reflect.kUint ||
        reflect.kUint8 ||
        reflect.kUint16 ||
        reflect.kUint32 ||
        reflect.kUint64 ||
        reflect.kUintptr:
      return (strconv.formatUint(k.uint(), Golang.Int(10)).toBytes(), null);
  }
  throw Panic(_gs('unexpected map key type'));
}

void _encodeByteSlice(_EncodeState e, reflect.Value v, int opts) {
  if (v.isNil$()) {
    e.writeString('null');
    return;
  }
  e.writeByte(0x22);
  _base64Encode(e.buf, _in(v.bytes()));
  e.writeByte(0x22);
}

_EncFn _newSliceEncoder(RType t) {
  if (t.$elem!.$kind == reflect.kUint8) {
    final p = t.$elem!.ptrTo();
    if (!_implements(p, _marshalerType) &&
        !_implements(p, _textMarshalerType)) {
      return _encodeByteSlice;
    }
  }
  final arrayEnc = _newArrayEncoder(t);
  return (e, v, opts) {
    if (v.isNil$()) {
      e.writeString('null');
      return;
    }
    final seen = e.enter(v, () {
      final s = v.$rep as Slice;
      return s.length == 0 ? null : (s.addr(0), s.length);
    });
    arrayEnc(e, v, opts);
    e.ptrLevel--;
    e.leave(seen);
  };
}

_EncFn _newArrayEncoder(RType t) {
  final elemEnc = _typeEncoder(t.$elem!);
  return (e, v, opts) {
    e.writeByte(0x5b);
    final n = v.len().toInt();
    for (var i = 0; i < n; i++) {
      if (i > 0) e.writeByte(0x2c);
      elemEnc(e, v.index(Golang.Int(i)), opts);
    }
    e.writeByte(0x5d);
  };
}

_EncFn _newPtrEncoder(RType t) {
  final elemEnc = _typeEncoder(t.$elem!);
  return (e, v, opts) {
    if (v.isNil$()) {
      e.writeString('null');
      return;
    }
    final seen = e.enter(v, () => _Ident(v.$rep!));
    elemEnc(e, v.elem$(), opts);
    e.ptrLevel--;
    e.leave(seen);
  };
}

_EncFn _condAddrEncoder(_EncFn canAddrEnc, _EncFn elseEnc) =>
    (e, v, opts) => v.canAddr() ? canAddrEnc(e, v, opts) : elseEnc(e, v, opts);
