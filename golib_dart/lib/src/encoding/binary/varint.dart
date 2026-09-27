part of '../../../encoding/binary.dart';

final _x80 = Golang.Uint64(0x80);

final _x7f = Golang.Uint8(0x7f);

final _hiBit = Golang.Uint8(0x80);

/// `AppendUvarint(buf, x)`.
_Bytes appendUvarint(_Bytes buf, Golang.Uint64 x) {
  while (x >= _x80) {
    buf = buf.append([Golang.Uint8.from(x) | _hiBit]);
    x = x >> 7;
  }
  return buf.append([Golang.Uint8.from(x)]);
}

/// `PutUvarint(buf, x)`: bytes escritos (buf curto: o pânico de índice).
Golang.Int putUvarint(_Bytes buf, Golang.Uint64 x) {
  var i = 0;
  while (x >= _x80) {
    buf[i] = Golang.Uint8.from(x) | _hiBit;
    x = x >> 7;
    i++;
  }
  buf[i] = Golang.Uint8.from(x);
  return Golang.Int(i + 1);
}

/// `Uvarint(buf)`: (valor, n); n == 0 se buf acabou, n < 0 no overflow.
(Golang.Uint64, Golang.Int) uvarint(_Bytes buf) {
  var x = Golang.Uint64(0);
  var s = 0;
  for (var i = 0; i < buf.length; i++) {
    final b = buf[i];
    if (i == 10) return (Golang.Uint64(0), Golang.Int(-(i + 1)));
    if (b.toInt() < 0x80) {
      if (i == 9 && b.toInt() > 1) {
        return (Golang.Uint64(0), Golang.Int(-(i + 1)));
      }
      return (x | (Golang.Uint64.from(b) << s), Golang.Int(i + 1));
    }
    x = x | (Golang.Uint64.from(b & _x7f) << s);
    s += 7;
  }
  return (Golang.Uint64(0), Golang.Int(0));
}

Golang.Uint64 _zigzag(Golang.Int64 x) {
  final ux = Golang.Uint64.from(x) << 1;
  return x < Golang.Int64(0) ? ~ux : ux;
}

/// `AppendVarint(buf, x)`.
_Bytes appendVarint(_Bytes buf, Golang.Int64 x) =>
    appendUvarint(buf, _zigzag(x));

/// `PutVarint(buf, x)`.
Golang.Int putVarint(_Bytes buf, Golang.Int64 x) => putUvarint(buf, _zigzag(x));

Golang.Int64 _unzigzag(Golang.Uint64 ux) {
  final x = Golang.Int64.from(ux >> 1);
  return (ux & Golang.Uint64(1)) != Golang.Uint64(0) ? ~x : x;
}

/// `Varint(buf)`: (valor, n) como em [uvarint].
(Golang.Int64, Golang.Int) varint(_Bytes buf) {
  final (ux, n) = uvarint(buf);
  return (_unzigzag(ux), n);
}

final GoError _errOverflow = ErrorString(
  Golang.String.fromDart('binary: varint overflows a 64-bit integer'),
);

/// `ReadUvarint(r)`.
(Golang.Uint64, GoError?) readUvarint(io.ByteReader? r) {
  var x = Golang.Uint64(0);
  var s = 0;
  for (var i = 0; i < 10; i++) {
    final (b, err) = r!.readByte();
    if (err != null) {
      return (x, i > 0 && identical(err, io.eof) ? io.errUnexpectedEOF : err);
    }
    if (b.toInt() < 0x80) {
      if (i == 9 && b.toInt() > 1) return (x, _errOverflow);
      return (x | (Golang.Uint64.from(b) << s), null);
    }
    x = x | (Golang.Uint64.from(b & _x7f) << s);
    s += 7;
  }
  return (x, _errOverflow);
}

/// `ReadVarint(r)`.
(Golang.Int64, GoError?) readVarint(io.ByteReader? r) {
  final (ux, err) = readUvarint(r);
  return (_unzigzag(ux), err);
}
