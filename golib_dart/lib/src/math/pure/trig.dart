part of '../pure.dart';

const List<double> _sin = [
  1.58962301576546568060e-10,
  -2.50507477628578072866e-8,
  2.75573136213857245213e-6,
  -1.98412698295895385996e-4,
  8.33333333332211858878e-3,
  -1.66666666666666307295e-1,
];

const List<double> _cos = [
  -1.13585365213876817300e-11,
  2.08757008419747316778e-9,
  -2.75573141792967388112e-7,
  2.48015872888517045348e-5,
  -1.38888888888730564116e-3,
  4.16666666666665929218e-2,
];

const double _pi4a = 7.85398125648498535156e-1;

const double _pi4b = 3.77489470793079817668e-8;

const double _pi4c = 2.69515142907905952645e-15;

const double _reduceThreshold = 536870912.0;

// 1 << 29

double _sinPoly(double z, double zz) =>
    z +
    z *
        zz *
        ((((((_sin[0] * zz) + _sin[1]) * zz + _sin[2]) * zz + _sin[3]) * zz +
                    _sin[4]) *
                zz +
            _sin[5]);

double _cosPoly(double zz) =>
    1.0 -
    0.5 * zz +
    zz *
        zz *
        ((((((_cos[0] * zz) + _cos[1]) * zz + _cos[2]) * zz + _cos[3]) * zz +
                    _cos[4]) *
                zz +
            _cos[5]);

// Octante j (0..7) e z = x mod Pi/4 de x >= 0 (sin, cos, sincos).
(int, double) _octant(double x) {
  if (x >= _reduceThreshold) return _trigReduce(x);
  var j = (x * _fourOverPi).toInt(); // < 2**30
  var y = j.toDouble();
  if (j & 1 == 1) {
    j++;
    y++;
  }
  j &= 7;
  return (j, ((x - y * _pi4a) - y * _pi4b) - y * _pi4c);
}

/// `math.Cos`.
double cos(double x) {
  if (x.isNaN || x.isInfinite) return double.nan;
  var sign = false;
  var (j, z) = _octant(x.abs());
  if (j > 3) {
    j -= 4;
    sign = !sign;
  }
  if (j > 1) sign = !sign;
  final zz = z * z;
  final y = (j == 1 || j == 2) ? _sinPoly(z, zz) : _cosPoly(zz);
  return sign ? -y : y;
}

/// `math.Sin`.
double sin(double x) {
  if (x == 0 || x.isNaN) return x;
  if (x.isInfinite) return double.nan;
  var sign = false;
  if (x < 0) {
    x = -x;
    sign = true;
  }
  var (j, z) = _octant(x);
  if (j > 3) {
    sign = !sign;
    j -= 4;
  }
  final zz = z * z;
  final y = (j == 1 || j == 2) ? _cosPoly(zz) : _sinPoly(z, zz);
  return sign ? -y : y;
}

/// `math.Sincos`.
(double, double) sincos(double x) {
  if (x == 0) return (x, 1);
  if (x.isNaN || x.isInfinite) return (double.nan, double.nan);
  var sinSign = false, cosSign = false;
  if (x < 0) {
    x = -x;
    sinSign = true;
  }
  var (j, z) = _octant(x);
  if (j > 3) {
    j -= 4;
    sinSign = !sinSign;
    cosSign = !cosSign;
  }
  if (j > 1) cosSign = !cosSign;
  final zz = z * z;
  var c = _cosPoly(zz);
  var s = _sinPoly(z, zz);
  if (j == 1 || j == 2) (s, c) = (c, s);
  if (cosSign) c = -c;
  if (sinSign) s = -s;
  return (s, c);
}

const List<double> _tanP = [
  -1.30936939181383777646e4,
  1.15351664838587416140e6,
  -1.79565251976484877988e7,
];

const List<double> _tanQ = [
  1.00000000000000000000e0,
  1.36812963470692954678e4,
  -1.32089234440210967447e6,
  2.50083801823357915839e7,
  -5.38695755929454629881e7,
];

/// `math.Tan`.
double tan(double x) {
  if (x == 0 || x.isNaN) return x;
  if (x.isInfinite) return double.nan;
  var sign = false;
  if (x < 0) {
    x = -x;
    sign = true;
  }
  int j;
  double y, z;
  if (x >= _reduceThreshold) {
    (j, z) = _trigReduce(x);
  } else {
    j = (x * _fourOverPi).toInt();
    y = j.toDouble();
    if (j & 1 == 1) {
      j++;
      y++;
    }
    z = ((x - y * _pi4a) - y * _pi4b) - y * _pi4c;
  }
  final zz = z * z;
  if (zz > 1e-14) {
    y =
        z +
        z *
            (zz *
                (((_tanP[0] * zz) + _tanP[1]) * zz + _tanP[2]) /
                ((((zz + _tanQ[1]) * zz + _tanQ[2]) * zz + _tanQ[3]) * zz +
                    _tanQ[4]));
  } else {
    y = z;
  }
  if (j & 2 == 2) y = -1 / y;
  return sign ? -y : y;
}

// Dígitos binários de 4/Pi (Payne-Hanek), palavras de 64 bits.
final List<Golang.Uint64> _mPi4 = [
  for (final (hi, lo) in const [
    (0x00000000, 0x00000001),
    (0x45f306dc, 0x9c882a53),
    (0xf84eafa3, 0xea69bb81),
    (0xb6c52b32, 0x78872083),
    (0xfca2c757, 0xbd778ac3),
    (0x6e48dc74, 0x849ba5c0),
    (0x0c925dd4, 0x13a32439),
    (0xfc3bd639, 0x62534e7d),
    (0xd1046bea, 0x5d768909),
    (0xd338e04d, 0x68befc82),
    (0x7323ac73, 0x06a673e9),
    (0x3908bf17, 0x7bf25076),
    (0x3ff12fff, 0xbc0b301f),
    (0xde5e2316, 0xb414da3e),
    (0xda6cfd9e, 0x4f96136e),
    (0x9e8c7ecd, 0x3cbfd45a),
    (0xea4f758f, 0xd7cbe2f6),
    (0x7a0e73ef, 0x14a525d4),
    (0xd7f6bf62, 0x3f1aba10),
    (0xac06608d, 0xf8f6d757),
  ])
    _u64(hi, lo),
];

// Redução de Payne-Hanek por Pi/4 (x grande): octante e o resto em radianos.
(int, double) _trigReduce(double x) {
  if (x < _piOver4) return (0, x);
  var ix = _bits(x);
  final exp = ((ix.$hi >> 20) & 0x7ff) - 1023 - 52;
  ix = ix.andNot(_u64(0x7ff00000, 0));
  ix = ix | _u64(0x100000, 0);
  final digit = (exp + 61) ~/ 64, bitshift = (exp + 61) % 64;
  Golang.Uint64 word(int i) =>
      (_mPi4[i] << bitshift) | (_mPi4[i + 1] >> (64 - bitshift));
  final z0 = word(digit), z1 = word(digit + 1), z2 = word(digit + 2);
  final (z2hi, _) = bits.mul64(z2, ix);
  final (z1hi, z1lo) = bits.mul64(z1, ix);
  final z0lo = z0 * ix;
  final (lo, c) = bits.add64(z1lo, z2hi, _u64(0, 0));
  var (hi, _) = bits.add64(z0lo, z1hi, c);
  var j = (hi >> 61).toInt();
  hi = (hi << 3) | (lo >> 61);
  final lz = bits.leadingZeros64(hi).toInt();
  final e = 1023 - (lz + 1);
  hi = (hi << (lz + 1)) | (lo >> (64 - (lz + 1)));
  hi = hi >> (64 - 52);
  hi = hi | (_u64(0, e) << 52);
  var z = _frombits(hi);
  if (j & 1 == 1) {
    j++;
    j &= 7;
    z--;
  }
  return (j, z * _piOver4);
}

// Série do atan em [0, 0.66].
double _xatan(double x) {
  const p0 = -8.750608600031904122785e-01;
  const p1 = -1.615753718733365076637e+01;
  const p2 = -7.500855792314704667340e+01;
  const p3 = -1.228866684490136173410e+02;
  const p4 = -6.485021904942025371773e+01;
  const q0 = 2.485846490142306297962e+01;
  const q1 = 1.650270098316988542046e+02;
  const q2 = 4.328810604912902668951e+02;
  const q3 = 4.853903996359136964868e+02;
  const q4 = 1.945506571482613964425e+02;
  var z = x * x;
  z =
      z *
      ((((p0 * z + p1) * z + p2) * z + p3) * z + p4) /
      (((((z + q0) * z + q1) * z + q2) * z + q3) * z + q4);
  return x * z + x;
}

double _satan(double x) {
  const morebits = 6.123233995736765886130e-17;
  const halfMorebits = 3.061616997868383e-17; // 0.5*Morebits
  const tan3pio8 = 2.41421356237309504880;
  if (x <= 0.66) return _xatan(x);
  if (x > tan3pio8) return _piOver2 - _xatan(1 / x) + morebits;
  return _piOver4 + _xatan((x - 1) / (x + 1)) + halfMorebits;
}

/// `math.Atan`.
double atan(double x) {
  if (x == 0) return x;
  if (x > 0) return _satan(x);
  return -_satan(-x);
}
