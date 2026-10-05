part of '../../../net/netip.dart';

// Formatação textual de `netip.go`: cada `append` do Go é um `_app` (o
// crescimento do cap segue o do Go).

const _digits = '0123456789abcdef';

int _digit(int i) => _digits.codeUnitAt(i);

/// `appendDecimal(b, x)`.
_Bytes _appendDecimal(_Bytes b, int x) {
  if (x >= 100) b = _app(b, [_digit(x ~/ 100)]);
  if (x >= 10) b = _app(b, [_digit(x ~/ 10 % 10)]);
  return _app(b, [_digit(x % 10)]);
}

/// `appendHex(b, x)`: sem zeros à esquerda.
_Bytes _appendHex(_Bytes b, int x) {
  if (x >= 0x1000) b = _app(b, [_digit(x >> 12)]);
  if (x >= 0x100) b = _app(b, [_digit(x >> 8 & 0xf)]);
  if (x >= 0x10) b = _app(b, [_digit(x >> 4 & 0xf)]);
  return _app(b, [_digit(x & 0xf)]);
}

/// `appendHexPad(b, x)`: 4 dígitos.
_Bytes _appendHexPad(_Bytes b, int x) => _app(b, [
  _digit(x >> 12),
  _digit(x >> 8 & 0xf),
  _digit(x >> 4 & 0xf),
  _digit(x & 0xf),
]);

/// `(Addr).appendTo4`.
_Bytes _appendTo4(Addr ip, _Bytes ret) {
  ret = _appendDecimal(ret, ip._v4(0));
  ret = _app(ret, const [0x2e]);
  ret = _appendDecimal(ret, ip._v4(1));
  ret = _app(ret, const [0x2e]);
  ret = _appendDecimal(ret, ip._v4(2));
  ret = _app(ret, const [0x2e]);
  return _appendDecimal(ret, ip._v4(3));
}

/// `(Addr).appendTo4In6`: `::ffff:a.b.c.d[%zona]`.
_Bytes _appendTo4In6(Addr ip, _Bytes ret) {
  ret = _app(ret, '::ffff:'.codeUnits);
  ret = _appendTo4(ip.unmap(), ret);
  if (ip._z != _z6noz) {
    ret = _app(ret, const [0x25]);
    ret = _app(ret, ip.zone().toBytes());
  }
  return ret;
}

/// `(Addr).appendTo6`: RFC 5952 (a maior sequência de zeros vira `::`).
_Bytes _appendTo6(Addr ip, _Bytes ret) {
  var zeroStart = 255, zeroEnd = 255;
  for (var i = 0; i < 8; i++) {
    var j = i;
    while (j < 8 && ip._v6u16(j) == 0) {
      j++;
    }
    final l = j - i;
    // `zeroEnd-zeroStart` é uint8 no Go: 255-255 = 0.
    if (l >= 2 && l > (zeroEnd - zeroStart) & 0xff) {
      zeroStart = i;
      zeroEnd = j;
    }
  }
  for (var i = 0; i < 8; i++) {
    if (i == zeroStart) {
      ret = _app(ret, const [0x3a, 0x3a]);
      i = zeroEnd;
      if (i >= 8) break;
    } else if (i > 0) {
      ret = _app(ret, const [0x3a]);
    }
    ret = _appendHex(ret, ip._v6u16(i));
  }
  if (ip._z != _z6noz) {
    ret = _app(ret, const [0x25]);
    ret = _app(ret, ip.zone().toBytes());
  }
  return ret;
}
