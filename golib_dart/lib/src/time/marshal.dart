part of '../../time.dart';

// Porta de `Format`/`AppendFormat`/`GoString` de `time/format.go` e de
// `AppendBinary`/`MarshalBinary`/`UnmarshalBinary`/`MarshalJSON`/
// `UnmarshalJSON`/`AppendText`/`MarshalText`/`UnmarshalText` de
// `time/time.go` do Go 1.26.5. Os métodos de [Time] (`time_type.dart`) são
// wrappers finos para estas funções.

typedef _Bytes = Slice<Golang.Uint8>;

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

/// `append(b, s...)` com [s] string de bytes.
_Bytes _appendByteString(_Bytes b, String s) =>
    b.append([for (final c in s.codeUnits) Golang.Uint8(c)]);

/// `[]byte` → string de bytes.
String _byteSliceString(_Bytes b) =>
    String.fromCharCodes([for (final x in b.items) x.toInt()]);

_Bytes _nilBytes() => Slice<Golang.Uint8>.nil(_byteElem);

GoError _errorsNew(String s) => ErrorString(_fromByteString(s));

Golang.String _formatImpl(Time t, Golang.String layout) =>
    _fromByteString(_formatBytes(t, _bytesOf(layout)));

_Bytes _appendFormatImpl(Time t, _Bytes b, Golang.String layout) =>
    _appendByteString(b, _formatBytes(t, _bytesOf(layout)));

/// `GoString()`: `time.Date(2009, time.November, 10, 23, 0, 0, 0, time.UTC)`.
Golang.String _goStringImpl(Time t) {
  final (_, _, days, secOfDay) = t._locabs();
  final (year, month, day) = _daysToDate(days);
  final (hour, minute, second) = _clockOfSecOfDay(secOfDay);
  final b = StringBuffer('time.Date(');
  _appendInt(b, year, 0);
  b.write(', time.${_longMonthNames[month - 1]}, ');
  b.write('$day, $hour, $minute, $second, ${t._nsecInt()}, ');
  final l = t.location();
  if (identical(l, _utcSentinel)) {
    b.write('time.UTC');
  } else if (identical(l, _localSentinel)) {
    b.write('time.Local');
  } else {
    b.write('time.Location(${_quote(_zoneBytes(l._name))})');
  }
  b.write(')');
  return _fromByteString(b.toString());
}

/// Os 8 bytes big-endian de um int64.
List<int> _be64(Golang.Int64 v) {
  final u = v.toBigInt().toUnsigned(64);
  return [
    for (var i = 7; i >= 0; i--) ((u >> (8 * i)) & BigInt.from(0xff)).toInt(),
  ];
}

/// `AppendBinary(b)`.
(_Bytes, GoError?) _appendBinaryImpl(Time t, _Bytes b) {
  var offsetMin = 0; // minutos a leste de UTC; -1 é UTC
  var offsetSec = 0;
  var version = 1;
  if (t.loc == null || identical(t.loc, _utcSentinel)) {
    offsetMin = -1;
  } else {
    var (_, offset) = t._zoneInfo();
    if (offset % 60 != 0) {
      version = 2;
      offsetSec = offset.remainder(60);
    }
    offset = offset ~/ 60;
    if (offset < -32768 || offset == -1 || offset > 32767) {
      return (b, _errorsNew('Time.MarshalBinary: unexpected zone offset'));
    }
    offsetMin = offset;
  }
  final nsec = t._nsecInt();
  final out = [
    version,
    ..._be64(t._secInternal()),
    (nsec >> 24) & 0xff,
    (nsec >> 16) & 0xff,
    (nsec >> 8) & 0xff,
    nsec & 0xff,
    (offsetMin >> 8) & 0xff,
    offsetMin & 0xff,
    if (version == 2) offsetSec & 0xff,
  ];
  return (b.append([for (final x in out) Golang.Uint8(x)]), null);
}

/// `MarshalBinary()`.
(_Bytes, GoError?) _marshalBinaryImpl(Time t) {
  final (b, err) = _appendBinaryImpl(t, _nilBytes());
  if (err != null) return (_nilBytes(), err);
  return (b, null);
}

/// `(*Time).UnmarshalBinary(data)`.
GoError? _unmarshalBinaryImpl(Time t, _Bytes data) {
  final buf = [for (final x in data.items) x.toInt()];
  if (buf.isEmpty) return _errorsNew('Time.UnmarshalBinary: no data');
  final version = buf[0];
  if (version != 1 && version != 2) {
    return _errorsNew('Time.UnmarshalBinary: unsupported version');
  }
  final wantLen = version == 2 ? 16 : 15;
  if (buf.length != wantLen) {
    return _errorsNew('Time.UnmarshalBinary: invalid length');
  }
  var sec = BigInt.zero;
  for (var i = 1; i <= 8; i++) {
    sec = (sec << 8) | BigInt.from(buf[i]);
  }
  var nsec = buf[9] * 0x1000000 + buf[10] * 0x10000 + buf[11] * 0x100 + buf[12];
  if (nsec >= 0x80000000) nsec -= 0x100000000; // int32
  var off16 = buf[13] * 0x100 + buf[14];
  if (off16 >= 0x8000) off16 -= 0x10000; // int16
  var offset = off16 * 60;
  if (version == 2) offset += buf[15];

  t
    ..wall = Golang.Int64(nsec).toUint64()
    ..ext = Golang.Int64.fromBigInt(sec.toSigned(64))
    ..loc = null;
  if (offset == -60) {
    t._setLocation(_utcSentinel);
  } else if (_localSentinel._lookup().$2 == offset) {
    t._setLocation(_localSentinel);
  } else {
    t._setLocation(Location._('', offset));
  }
  return null;
}

/// `MarshalJSON()`.
(_Bytes, GoError?) _marshalJSONImpl(Time t) {
  final (s, err) = _strictRFC3339(t);
  if (err != null) {
    return (_nilBytes(), _errorsNew('Time.MarshalJSON: $err'));
  }
  return (_appendByteString(_nilBytes(), '"$s"'), null);
}

/// `(*Time).UnmarshalJSON(data)`.
GoError? _unmarshalJSONImpl(Time t, _Bytes data) {
  final s = _byteSliceString(data);
  if (s == 'null') return null;
  // O Go não desfaz escapes JSON aqui (go.dev/issue/47353).
  if (s.length < 2 || s[0] != '"' || s[s.length - 1] != '"') {
    return _errorsNew('Time.UnmarshalJSON: input is not a JSON string');
  }
  final (r, err) = _parseStrictRFC3339(s.substring(1, s.length - 1));
  t.$set(r);
  return err;
}

/// `appendTo(b, errPrefix)`: `AppendText`/`MarshalText`.
(_Bytes, GoError?) _appendTextImpl(Time t, _Bytes b, String errPrefix) {
  final (s, err) = _strictRFC3339(t);
  if (err != null) return (_nilBytes(), _errorsNew('$errPrefix$err'));
  return (_appendByteString(b, s), null);
}

/// `(*Time).UnmarshalText(data)`.
GoError? _unmarshalTextImpl(Time t, _Bytes data) {
  final (r, err) = _parseStrictRFC3339(_byteSliceString(data));
  t.$set(r);
  return err;
}
