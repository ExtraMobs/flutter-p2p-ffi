/// Porta do código Go puro do pacote `math` (Go 1.26.5; derivado do FreeBSD
/// msun/fdlibm e do Cephes) sobre `double`: o resultado do `math` do Go sem
/// assembly (386, arm, riscv64, wasm...), bit a bit, igual em VM, JS e Wasm.
/// No amd64 o gc usa assembly em Exp e Log (e, por elas, em Pow, Log2,
/// Log10, Gamma...), com outro algoritmo: pode diferir no último bit.
///
/// As expressões constantes do Go (`1 / Ln10`, `Pi / 4`...) são dobradas com
/// precisão arbitrária antes de virar float64; aqui entram já dobradas.
// ignore_for_file: library_prefixes
library;

import 'dart:math' as dm;
import 'dart:typed_data';

import '../../fixed_types/golang.dart' as Golang;
import '../../math/bits.dart' as bits;

final ByteData _b = ByteData(8);

int _hi(double x) {
  _b.setFloat64(0, x);
  return _b.getUint32(0);
}

int _lo(double x) {
  _b.setFloat64(0, x);
  return _b.getUint32(4);
}

double _make(int hi, int lo) {
  _b
    ..setUint32(0, hi & 0xffffffff)
    ..setUint32(4, lo & 0xffffffff);
  return _b.getFloat64(0);
}

Golang.Uint64 _bits(double x) {
  _b.setFloat64(0, x);
  return Golang.Uint64().$make(_b.getUint32(0), _b.getUint32(4));
}

double _frombits(Golang.Uint64 v) => _make(v.$hi, v.$lo);

Golang.Uint64 _u64(int hi, int lo) => Golang.Uint64().$make(hi, lo);

const double _smallestNormal = 2.2250738585072014e-308; // 2**-1022
const double _two52 = 4503599627370496.0;
const double _pi = 3.141592653589793;
const double _sqrt2Half = 0.7071067811865476; // Sqrt2/2
const double _invLn10 = 0.4342944819032518; // 1/Ln10
const double _invLn2 = 1.4426950408889634; // 1/Ln2
const double _fourOverPi = 1.2732395447351628; // 4/Pi
const double _piOver4 = 0.7853981633974483; // Pi/4
const double _piOver2 = 1.5707963267948966; // Pi/2
const double _ln2Hi = 6.93147180369123816490e-01;
const double _ln2Lo = 1.90821492927058770002e-10;

/// `math.Frexp`: f == frac × 2**exp, |frac| em [½, 1).
(double, int) frexp(double f) {
  if (f == 0 || f.isInfinite || f.isNaN) return (f, 0);
  var exp = 0;
  if (f.abs() < _smallestNormal) {
    f *= _two52;
    exp = -52;
  }
  final hi = _hi(f);
  exp += ((hi >> 20) & 0x7ff) - 1023 + 1;
  return (_make((hi & 0x800fffff) | (1022 << 20), _lo(f)), exp);
}

/// `math.Ldexp`: frac × 2**exp.
double ldexp(double frac, int exp) {
  if (frac == 0 || frac.isInfinite || frac.isNaN) return frac;
  if (frac.abs() < _smallestNormal) {
    frac *= _two52;
    exp -= 52;
  }
  final hi = _hi(frac), lo = _lo(frac);
  exp += ((hi >> 20) & 0x7ff) - 1023;
  if (exp < -1075) return frac < 0 ? -0.0 : 0.0; // underflow
  if (exp > 1023) {
    return frac < 0 ? double.negativeInfinity : double.infinity;
  }
  var m = 1.0;
  if (exp < -1022) {
    // denormal
    exp += 53;
    m = 1.0 / 9007199254740992.0; // 2**-53
  }
  return m * _make((hi & 0x800fffff) | ((exp + 1023) << 20), lo);
}

/// `math.Exp`.
double exp(double x) {
  const log2e = 1.44269504088896338700e+00;
  const overflow = 7.09782712893383973096e+02;
  const underflow = -7.45133219101941108420e+02;
  const nearZero = 1.0 / (1 << 28);
  if (x.isNaN) return x;
  if (x > overflow) return double.infinity;
  if (x < underflow) return 0;
  if (-nearZero < x && x < nearZero) return 1 + x;
  var k = 0;
  if (x < 0) {
    k = (log2e * x - 0.5).toInt();
  } else if (x > 0) {
    k = (log2e * x + 0.5).toInt();
  }
  final hi = x - k.toDouble() * _ln2Hi;
  final lo = k.toDouble() * _ln2Lo;
  return _expmulti(hi, lo, k);
}

// e**r × 2**k com r = hi - lo e |r| ≤ ln(2)/2.
double _expmulti(double hi, double lo, int k) {
  const p1 = 1.66666666666666657415e-01;
  const p2 = -2.77777777770155933842e-03;
  const p3 = 6.61375632143793436117e-05;
  const p4 = -1.65339022054652515390e-06;
  const p5 = 4.13813679705723846039e-08;
  final r = hi - lo;
  final t = r * r;
  final c = r - t * (p1 + t * (p2 + t * (p3 + t * (p4 + t * p5))));
  final y = 1 - ((lo - (r * c) / (2 - c)) - hi);
  return ldexp(y, k);
}

/// `math.Log`.
double log(double x) {
  const l1 = 6.666666666666735130e-01;
  const l2 = 3.999999999940941908e-01;
  const l3 = 2.857142874366239149e-01;
  const l4 = 2.222219843214978396e-01;
  const l5 = 1.818357216161805012e-01;
  const l6 = 1.531383769920937332e-01;
  const l7 = 1.479819860511658591e-01;
  if (x.isNaN || x == double.infinity) return x;
  if (x < 0) return double.nan;
  if (x == 0) return double.negativeInfinity;
  var (f1, ki) = frexp(x);
  if (f1 < _sqrt2Half) {
    f1 *= 2;
    ki--;
  }
  final f = f1 - 1;
  final k = ki.toDouble();
  final s = f / (2 + f);
  final s2 = s * s;
  final s4 = s2 * s2;
  final t1 = s2 * (l1 + s4 * (l3 + s4 * (l5 + s4 * l7)));
  final t2 = s4 * (l2 + s4 * (l4 + s4 * l6));
  final r = t1 + t2;
  final hfsq = 0.5 * f * f;
  return k * _ln2Hi - ((hfsq - (s * (hfsq + r) + k * _ln2Lo)) - f);
}

/// `math.Log10`.
double log10(double x) => log(x) * _invLn10;

/// `math.Log2`: potências de dois exatas.
double log2(double x) {
  final (frac, exp) = frexp(x);
  if (frac == 0.5) return (exp - 1).toDouble();
  return log(frac) * _invLn2 + exp.toDouble();
}

/// `math.Log1p`: log(1+x) preciso perto de zero.
double log1p(double x) {
  const sqrt2M1 = 4.142135623730950488017e-01;
  const sqrt2HalfM1 = -2.928932188134524755992e-01;
  const small = 1.0 / (1 << 29);
  const tiny = 1.0 / 18014398509481984.0; // 2**-54 (sem shift: 32 bits no JS)
  const two53 = 9007199254740992.0;
  const lp1 = 6.666666666666735130e-01;
  const lp2 = 3.999999999940941908e-01;
  const lp3 = 2.857142874366239149e-01;
  const lp4 = 2.222219843214978396e-01;
  const lp5 = 1.818357216161805012e-01;
  const lp6 = 1.531383769920937332e-01;
  const lp7 = 1.479819860511658591e-01;
  if (x < -1 || x.isNaN) return double.nan;
  if (x == -1) return double.negativeInfinity;
  if (x == double.infinity) return double.infinity;
  final absx = x.abs();
  var f = 0.0;
  var iu = 0; // mantissa de u (< 2**52, exata no JS)
  var k = 1;
  if (absx < sqrt2M1) {
    if (absx < small) {
      if (absx < tiny) return x;
      return x - x * x * 0.5;
    }
    if (x > sqrt2HalfM1) {
      k = 0;
      f = x;
      iu = 1;
    }
  }
  var c = 0.0;
  if (k != 0) {
    double u;
    if (absx < two53) {
      u = 1.0 + x;
      k = (_hi(u) >> 20) - 1023;
      if (k > 0) {
        c = 1.0 - (u - x);
      } else {
        c = x - (u - 1.0);
      }
      c /= u;
    } else {
      u = x;
      k = (_hi(u) >> 20) - 1023;
      c = 0;
    }
    final mhi = _hi(u) & 0xfffff, lo = _lo(u);
    iu = mhi * 4294967296 + lo;
    if (iu < 0x0006a09e667f3bcd) {
      u = _make(mhi | 0x3ff00000, lo); // normaliza u
    } else {
      k++;
      u = _make(mhi | 0x3fe00000, lo); // normaliza u/2
      iu = (0x0010000000000000 - iu) ~/ 4;
    }
    f = u - 1.0;
  }
  final hfsq = 0.5 * f * f;
  final kd = k.toDouble();
  if (iu == 0) {
    // |f| < 2**-20
    if (f == 0) {
      if (k == 0) return 0;
      c += kd * _ln2Lo;
      return kd * _ln2Hi + c;
    }
    final r = hfsq * (1.0 - 0.66666666666666666 * f);
    if (k == 0) return f - r;
    return kd * _ln2Hi - ((r - (kd * _ln2Lo + c)) - f);
  }
  final s = f / (2.0 + f);
  final z = s * s;
  final r =
      z *
      (lp1 +
          z * (lp2 + z * (lp3 + z * (lp4 + z * (lp5 + z * (lp6 + z * lp7))))));
  if (k == 0) return f - (hfsq - s * (hfsq + r));
  return kd * _ln2Hi - ((hfsq - (s * (hfsq + r) + (kd * _ln2Lo + c))) - f);
}

// Soma k ao expoente de y (Float64bits(y) + uint64(k)<<52).
double _addExp(double y, int k) => _make(_hi(y) + k * 0x100000, _lo(y));

/// `math.Expm1`: e**x - 1 preciso perto de zero.
double expm1(double x) {
  const othreshold = 7.09782712893383973096e+02;
  const ln2X56 = 3.88162421113569373274e+01;
  const ln2HalfX3 = 1.03972077083991796413e+00;
  const ln2Half = 3.46573590279972654709e-01;
  const invLn2 = 1.44269504088896338700e+00;
  const tiny = 1.0 / 18014398509481984.0; // 2**-54 (sem shift: 32 bits no JS)
  const q1 = -3.33333333333331316428e-02;
  const q2 = 1.58730158725481460165e-03;
  const q3 = -7.93650757867487942473e-05;
  const q4 = 4.00821782732936239552e-06;
  const q5 = -2.01099218183624371326e-07;
  if (x == double.infinity || x.isNaN) return x;
  if (x == double.negativeInfinity) return -1;
  var absx = x;
  var sign = false;
  if (x < 0) {
    absx = -absx;
    sign = true;
  }
  if (absx >= ln2X56) {
    if (sign) return -1;
    if (absx >= othreshold) return double.infinity;
  }
  var c = 0.0;
  var k = 0;
  if (absx > ln2Half) {
    double hi, lo;
    if (absx < ln2HalfX3) {
      if (!sign) {
        hi = x - _ln2Hi;
        lo = _ln2Lo;
        k = 1;
      } else {
        hi = x + _ln2Hi;
        lo = -_ln2Lo;
        k = -1;
      }
    } else {
      if (!sign) {
        k = (invLn2 * x + 0.5).toInt();
      } else {
        k = (invLn2 * x - 0.5).toInt();
      }
      final t = k.toDouble();
      hi = x - t * _ln2Hi;
      lo = t * _ln2Lo;
    }
    x = hi - lo;
    c = (hi - x) - lo;
  } else if (absx < tiny) {
    return x;
  } else {
    k = 0;
  }
  final hfx = 0.5 * x;
  final hxs = x * hfx;
  final r1 = 1 + hxs * (q1 + hxs * (q2 + hxs * (q3 + hxs * (q4 + hxs * q5))));
  var t = 3 - r1 * hfx;
  var e = hxs * ((r1 - t) / (6.0 - x * t));
  if (k == 0) return x - (x * e - hxs);
  e = (x * (e - c) - c);
  e -= hxs;
  if (k == -1) return 0.5 * (x - e) - 0.5;
  if (k == 1) {
    if (x < -0.25) return -2 * (e - (x + 0.5));
    return 1 + 2 * (x - e);
  }
  if (k <= -2 || k > 56) {
    var y = 1 - (e - x);
    y = _addExp(y, k);
    return y - 1;
  }
  if (k < 20) {
    final t = _make(0x3ff00000 - (1 << (21 - k)), 0); // 1-2**-k
    var y = t - (e - x);
    y = _addExp(y, k);
    return y;
  }
  t = _make((0x3ff - k) << 20, 0); // 2**-k
  var y = x - (e + t);
  y++;
  y = _addExp(y, k);
  return y;
}

bool _isOddInt(double x) {
  if (x.abs() >= 9007199254740992.0) return false;
  final (xi, xf) = modf(x);
  return xf == 0 && xi.toInt().isOdd;
}

/// `math.Modf`: parte inteira e fracionária, com o sinal de f.
(double, double) modf(double f) {
  final i = _trunc(f);
  return (i, _copysign(f - i, f));
}

double _trunc(double x) {
  if (x.isNaN || x.isInfinite || x == 0) return x;
  return _copysign(x.truncateToDouble(), x);
}

double _copysign(double f, double sign) =>
    _make((_hi(f) & 0x7fffffff) | (_hi(sign) & 0x80000000), _lo(f));

bool _signbit(double x) => _hi(x) >= 0x80000000;

/// `math.Pow`.
double pow(double x, double y) {
  if (y == 0 || x == 1) return 1;
  if (y == 1) return x;
  if (x.isNaN || y.isNaN) return double.nan;
  if (x == 0) {
    if (y < 0) {
      if (_signbit(x) && _isOddInt(y)) return double.negativeInfinity;
      return double.infinity;
    }
    if (y > 0) {
      if (_signbit(x) && _isOddInt(y)) return x;
      return 0;
    }
  } else if (y.isInfinite) {
    if (x == -1) return 1;
    if ((x.abs() < 1) == (y == double.infinity)) return 0;
    return double.infinity;
  } else if (x.isInfinite) {
    if (x == double.negativeInfinity) return pow(1 / x, -y); // Pow(-0, -y)
    if (y < 0) return 0;
    if (y > 0) return double.infinity;
  } else if (y == 0.5) {
    return _sqrt(x);
  } else if (y == -0.5) {
    return 1 / _sqrt(x);
  }
  var (yi, yf) = modf(y.abs());
  if (yf != 0 && x < 0) return double.nan;
  if (yi >= 9223372036854775808.0) {
    // yi par e enorme: overflow ou underflow para todo x exceto -1
    if (x == -1) return 1;
    if ((x.abs() < 1) == (y > 0)) return 0;
    return double.infinity;
  }
  var a1 = 1.0;
  var ae = 0;
  if (yf != 0) {
    if (yf > 0.5) {
      yf--;
      yi++;
    }
    a1 = exp(yf * log(x));
  }
  var (x1, xe) = frexp(x);
  // int64(yi) < 2**63: os bits de yi, do menos significativo para o mais.
  for (var i = yi; i != 0; i = (i / 2).floorToDouble()) {
    if (xe < -(1 << 12) || (1 << 12) < xe) {
      ae += xe;
      break;
    }
    if (i % 2 == 1) {
      a1 *= x1;
      ae += xe;
    }
    x1 *= x1;
    xe *= 2; // xe pode ser negativo: `<<` no JS é de 32 bits sem sinal
    if (x1 < .5) {
      x1 += x1;
      xe--;
    }
  }
  if (y < 0) {
    a1 = 1 / a1;
    ae = -ae;
  }
  return ldexp(a1, ae);
}

// IEEE (arredondamento correto em toda plataforma); Sqrt(-0) = -0.
double _sqrt(double x) => dm.sqrt(x);

final Golang.Uint64 _signMask = _u64(0x80000000, 0);
final Golang.Uint64 _uvone = _u64(0x3ff00000, 0);
final Golang.Uint64 _fracMask = _u64(0xfffff, 0xffffffff);

/// `math.Round`: meio para longe de zero.
double round(double x) {
  var b = _bits(x);
  var e = (b.$hi >> 20) & 0x7ff;
  if (e < 1023) {
    b = b & _signMask; // ±0
    if (e == 1022) b = b | _uvone; // ±1
  } else if (e < 1023 + 52) {
    e -= 1023;
    b = b + (_u64(0x80000, 0) >> e); // half >> e
    b = b.andNot(_fracMask >> e);
  }
  return _frombits(b);
}

/// `math.RoundToEven`: meio para o par.
double roundToEven(double x) {
  var b = _bits(x);
  var e = (b.$hi >> 20) & 0x7ff;
  if (e >= 1023) {
    e -= 1023;
    final halfMinusUlp = _u64(0x7ffff, 0xffffffff);
    // `shift-e` é uint no Go: negativo dá a volta e o shift zera.
    final odd = e > 52 ? _u64(0, 0) : (b >> (52 - e)) & _u64(0, 1);
    b = b + ((halfMinusUlp + odd) >> e);
    b = b.andNot(_fracMask >> e);
  } else if (e == 1022 && (b & _fracMask) != _u64(0, 0)) {
    b = (b & _signMask) | _uvone; // ±1
  } else {
    b = b & _signMask; // ±0
  }
  return _frombits(b);
}

/// `math.Nextafter`.
double nextafter(double x, double y) {
  if (x.isNaN || y.isNaN) return double.nan;
  if (x == y) return x;
  if (x == 0) return _copysign(_make(0, 1), y);
  if ((y > x) == (x > 0)) return _frombits(_bits(x) + _u64(0, 1));
  return _frombits(_bits(x) - _u64(0, 1));
}

/// `math.Cbrt`.
double cbrt(double x) {
  const b1 = 715094163;
  const b2 = 696219795;
  const c = 5.42857142857142815906e-01;
  const d = -7.05306122448979611050e-01;
  const e = 1.41428571428571436819e+00;
  const f = 1.60714285714285720630e+00;
  const g = 3.57142857142857150787e-01;
  if (x == 0 || x.isNaN || x.isInfinite) return x;
  var sign = false;
  if (x < 0) {
    x = -x;
    sign = true;
  }
  // cbrt grosseira com 5 bits
  final three = _u64(0, 3);
  var t = _frombits(_bits(x) ~/ three + _u64(b1, 0));
  if (x < _smallestNormal) {
    t = 18014398509481984.0; // 2**54
    t *= x;
    t = _frombits(_bits(t) ~/ three + _u64(b2, 0));
  }
  // nova cbrt com 23 bits
  var r = t * t / x;
  var s = c + r * t;
  t *= g + f / (s + e + d / s);
  // corta para 22 bits, maior que cbrt(x)
  t = _frombits(
    (_bits(t) & _u64(0xffffffff, 0xc0000000)) + _u64(0, 0x40000000),
  );
  // uma iteração de Newton até 53 bits, erro < 0.667 ulp
  s = t * t;
  r = x / s;
  final w = t + t;
  r = (r - t) / (w + r);
  t = t + t * r;
  return sign ? -t : t;
}

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
const double _reduceThreshold = 536870912.0; // 1 << 29

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

/// `math.Mod`: resto de x/y com o sinal de x.
double mod(double x, double y) {
  if (y == 0 || x.isInfinite || x.isNaN || y.isNaN) return double.nan;
  y = y.abs();
  final (yfr, yexp) = frexp(y);
  var r = x;
  if (x < 0) r = -x;
  while (r >= y) {
    var (rfr, rexp) = frexp(r);
    if (rfr < yfr) rexp = rexp - 1;
    r = r - ldexp(y, rexp - yexp);
  }
  if (x < 0) r = -r;
  return r;
}

const List<double> _lgamA = [
  7.72156649015328655494e-02,
  3.22467033424113591611e-01,
  6.73523010531292681824e-02,
  2.05808084325167332806e-02,
  7.38555086081402883957e-03,
  2.89051383673415629091e-03,
  1.19270763183362067845e-03,
  5.10069792153511336608e-04,
  2.20862790713908385557e-04,
  1.08011567247583939954e-04,
  2.52144565451257326939e-05,
  4.48640949618915160150e-05,
];
const List<double> _lgamR = [
  1.0,
  1.39200533467621045958e+00,
  7.21935547567138069525e-01,
  1.71933865632803078993e-01,
  1.86459191715652901344e-02,
  7.77942496381893596434e-04,
  7.32668430744625636189e-06,
];
const List<double> _lgamS = [
  -7.72156649015328655494e-02,
  2.14982415960608852501e-01,
  3.25778796408930981787e-01,
  1.46350472652464452805e-01,
  2.66422703033638609560e-02,
  1.84028451407337715652e-03,
  3.19475326584100867617e-05,
];
const List<double> _lgamT = [
  4.83836122723810047042e-01,
  -1.47587722994593911752e-01,
  6.46249402391333854778e-02,
  -3.27885410759859649565e-02,
  1.79706750811820387126e-02,
  -1.03142241298341437450e-02,
  6.10053870246291332635e-03,
  -3.68452016781138256760e-03,
  2.25964780900612472250e-03,
  -1.40346469989232843813e-03,
  8.81081882437654011382e-04,
  -5.38595305356740546715e-04,
  3.15632070903625950361e-04,
  -3.12754168375120860518e-04,
  3.35529192635519073543e-04,
];
const List<double> _lgamU = [
  -7.72156649015328655494e-02,
  6.32827064025093366517e-01,
  1.45492250137234768737e+00,
  9.77717527963372745603e-01,
  2.28963728064692451092e-01,
  1.33810918536787660377e-02,
];
const List<double> _lgamV = [
  1.0,
  2.45597793713041134822e+00,
  2.12848976379893395361e+00,
  7.69285150456672783825e-01,
  1.04222645593369134254e-01,
  3.21709242282423911810e-03,
];
const List<double> _lgamW = [
  4.18938533204672725052e-01,
  8.33333333333329678849e-02,
  -2.77777777728775536470e-03,
  7.93650558643019558500e-04,
  -5.95187557450339963135e-04,
  8.36339918996282139126e-04,
  -1.63092934096575273989e-03,
];

/// `math.Lgamma`: log|Γ(x)| e o sinal de Γ(x).
(double, int) lgamma(double x) {
  const two52 = 4503599627370496.0;
  const two58 = 288230376151711744.0;
  const tiny = 1.0 / 1180591620717411303424.0; // 2**-70
  const tc = 1.46163214496836224576e+00;
  const tf = -1.21486290535849611461e-01;
  const tt = -3.63867699703950536541e-18;
  const yminM1P = 0.7316321449683623; // Ymin - 1 + 0.27
  const yminM1M = 0.19163214496836226; // Ymin - 1 - 0.27
  const yminP = 1.7316321449683623; // Ymin + 0.27
  const yminM = 1.1916321449683622; // Ymin - 0.27
  const tcM1 = 0.46163214496836225; // Tc - 1
  var sign = 1;
  if (x.isNaN || x.isInfinite) return (x, sign);
  if (x == 0) return (double.infinity, sign);
  var neg = false;
  if (x < 0) {
    x = -x;
    neg = true;
  }
  if (x < tiny) {
    if (neg) sign = -1;
    return (-log(x), sign);
  }
  var nadj = 0.0;
  if (neg) {
    if (x >= two52) return (double.infinity, sign); // -inteiro
    final t = _sinPi(x);
    if (t == 0) return (double.infinity, sign); // -inteiro
    nadj = log(_pi / (t * x).abs());
    if (t < 0) sign = -1;
  }
  double lgamma;
  if (x == 1 || x == 2) {
    return (0, sign);
  } else if (x < 2) {
    double y;
    int i;
    if (x <= 0.9) {
      lgamma = -log(x);
      if (x >= yminM1P) {
        y = 1 - x;
        i = 0;
      } else if (x >= yminM1M) {
        y = x - tcM1;
        i = 1;
      } else {
        y = x;
        i = 2;
      }
    } else {
      lgamma = 0;
      if (x >= yminP) {
        y = 2 - x;
        i = 0;
      } else if (x >= yminM) {
        y = x - tc;
        i = 1;
      } else {
        y = x - 1;
        i = 2;
      }
    }
    switch (i) {
      case 0:
        final z = y * y;
        final p1 =
            _lgamA[0] +
            z *
                (_lgamA[2] +
                    z *
                        (_lgamA[4] +
                            z *
                                (_lgamA[6] +
                                    z * (_lgamA[8] + z * _lgamA[10]))));
        final p2 =
            z *
            (_lgamA[1] +
                z *
                    (_lgamA[3] +
                        z *
                            (_lgamA[5] +
                                z *
                                    (_lgamA[7] +
                                        z * (_lgamA[9] + z * _lgamA[11])))));
        final p = y * p1 + p2;
        lgamma += (p - 0.5 * y);
      case 1:
        final z = y * y;
        final w = z * y;
        final p1 =
            _lgamT[0] +
            w *
                (_lgamT[3] +
                    w * (_lgamT[6] + w * (_lgamT[9] + w * _lgamT[12])));
        final p2 =
            _lgamT[1] +
            w *
                (_lgamT[4] +
                    w * (_lgamT[7] + w * (_lgamT[10] + w * _lgamT[13])));
        final p3 =
            _lgamT[2] +
            w *
                (_lgamT[5] +
                    w * (_lgamT[8] + w * (_lgamT[11] + w * _lgamT[14])));
        final p = z * p1 - (tt - w * (p2 + y * p3));
        lgamma += (tf + p);
      default:
        final p1 =
            y *
            (_lgamU[0] +
                y *
                    (_lgamU[1] +
                        y *
                            (_lgamU[2] +
                                y *
                                    (_lgamU[3] +
                                        y * (_lgamU[4] + y * _lgamU[5])))));
        final p2 =
            1 +
            y *
                (_lgamV[1] +
                    y *
                        (_lgamV[2] +
                            y * (_lgamV[3] + y * (_lgamV[4] + y * _lgamV[5]))));
        lgamma += (-0.5 * y + p1 / p2);
    }
  } else if (x < 8) {
    final i = x.toInt();
    final y = x - i.toDouble();
    final p =
        y *
        (_lgamS[0] +
            y *
                (_lgamS[1] +
                    y *
                        (_lgamS[2] +
                            y *
                                (_lgamS[3] +
                                    y *
                                        (_lgamS[4] +
                                            y *
                                                (_lgamS[5] +
                                                    y * _lgamS[6]))))));
    final q =
        1 +
        y *
            (_lgamR[1] +
                y *
                    (_lgamR[2] +
                        y *
                            (_lgamR[3] +
                                y *
                                    (_lgamR[4] +
                                        y * (_lgamR[5] + y * _lgamR[6])))));
    lgamma = 0.5 * y + p / q;
    var z = 1.0;
    // Lgamma(1+s) = Log(s) + Lgamma(s); o switch com fallthrough do Go.
    if (i >= 7) z *= (y + 6);
    if (i >= 6) z *= (y + 5);
    if (i >= 5) z *= (y + 4);
    if (i >= 4) z *= (y + 3);
    if (i >= 3) {
      z *= (y + 2);
      lgamma += log(z);
    }
  } else if (x < two58) {
    final t = log(x);
    final z = 1 / x;
    final y = z * z;
    final w =
        _lgamW[0] +
        z *
            (_lgamW[1] +
                y *
                    (_lgamW[2] +
                        y *
                            (_lgamW[3] +
                                y *
                                    (_lgamW[4] +
                                        y * (_lgamW[5] + y * _lgamW[6])))));
    lgamma = (x - 0.5) * (t - 1) + w;
  } else {
    lgamma = x * (log(x) - 1);
  }
  if (neg) lgamma = nadj - lgamma;
  return (lgamma, sign);
}

// sin(Pi*x) para x > 0 (usado pelo Lgamma de negativos).
double _sinPi(double x) {
  const two52 = 4503599627370496.0;
  const two53 = 9007199254740992.0;
  if (x < 0.25) return -sin(_pi * x);
  var z = x.floorToDouble();
  int n;
  if (z != x) {
    x = mod(x, 2);
    n = (x * 4).toInt();
  } else {
    if (x >= two53) {
      x = 0;
      n = 0;
    } else {
      if (x < two52) z = x + two52; // exato
      n = _lo(z) & 1;
      x = n.toDouble();
      n <<= 2;
    }
  }
  switch (n) {
    case 0:
      x = sin(_pi * x);
    case 1 || 2:
      x = cos(_pi * (0.5 - x));
    case 3 || 4:
      x = sin(_pi * (1 - x));
    case 5 || 6:
      x = -cos(_pi * (x - 1.5));
    default:
      x = sin(_pi * (x - 2));
  }
  return -x;
}

const List<double> _gamP = [
  1.60119522476751861407e-04,
  1.19135147006586384913e-03,
  1.04213797561761569935e-02,
  4.76367800457137231464e-02,
  2.07448227648435975150e-01,
  4.94214826801497100753e-01,
  9.99999999999999996796e-01,
];
const List<double> _gamQ = [
  -2.31581873324120129819e-05,
  5.39605580493303397842e-04,
  -4.45641913851797240494e-03,
  1.18139785222060435552e-02,
  3.58236398605498653373e-02,
  -2.34591795718243348568e-01,
  7.14304917030273074085e-02,
  1.00000000000000000320e+00,
];
const List<double> _gamS = [
  7.87311395793093628397e-04,
  -2.29549961613378126380e-04,
  -2.68132617805781232825e-03,
  3.47222221605458667310e-03,
  8.33333333333482257126e-02,
];

// Fórmula de Stirling: Γ(x) = y1 * y2 (em dois fatores contra overflow).
(double, double) _stirling(double x) {
  if (x > 200) return (double.infinity, 1);
  const sqrtTwoPi = 2.506628274631000502417;
  const maxStirling = 143.01608;
  var w = 1 / x;
  w =
      1 +
      w *
          ((((_gamS[0] * w + _gamS[1]) * w + _gamS[2]) * w + _gamS[3]) * w +
              _gamS[4]);
  var y1 = exp(x);
  var y2 = 1.0;
  if (x > maxStirling) {
    final v = pow(x, 0.5 * x - 0.25);
    (y1, y2) = (v, v / y1);
  } else {
    y1 = pow(x, x - 0.5) / y1;
  }
  return (y1, sqrtTwoPi * w * y2);
}

/// `math.Gamma`.
double gamma(double x) {
  const euler = 0.57721566490153286060651209008240243104215933593992;
  if (_isNegInt(x) || x == double.negativeInfinity || x.isNaN) {
    return double.nan;
  }
  if (x == double.infinity) return double.infinity;
  if (x == 0) return _signbit(x) ? double.negativeInfinity : double.infinity;
  var q = x.abs();
  var p = q.floorToDouble();
  if (q > 33) {
    if (x >= 0) {
      final (y1, y2) = _stirling(x);
      return y1 * y2;
    }
    // x negativo e não inteiro: |x| < 2**63.
    var signgam = 1;
    if (p % 2 == 0) signgam = -1;
    var z = q - p;
    if (z > 0.5) {
      p = p + 1;
      z = q - p;
    }
    z = q * sin(_pi * z);
    if (z == 0) return signgam >= 0 ? double.infinity : double.negativeInfinity;
    final (sq1, sq2) = _stirling(q);
    final absz = z.abs();
    final d = absz * sq1 * sq2;
    if (d.isInfinite) {
      z = _pi / absz / sq1 / sq2;
    } else {
      z = _pi / d;
    }
    return signgam.toDouble() * z;
  }
  var z = 1.0;
  while (x >= 3) {
    x = x - 1;
    z = z * x;
  }
  var small = false;
  while (x < 0) {
    if (x > -1e-09) {
      small = true;
      break;
    }
    z = z / x;
    x = x + 1;
  }
  if (!small) {
    while (x < 2) {
      if (x < 1e-09) {
        small = true;
        break;
      }
      z = z / x;
      x = x + 1;
    }
  }
  if (small) {
    if (x == 0) return double.infinity;
    return z / ((1 + euler * x) * x);
  }
  if (x == 2) return z;
  x = x - 2;
  p =
      (((((x * _gamP[0] + _gamP[1]) * x + _gamP[2]) * x + _gamP[3]) * x +
                      _gamP[4]) *
                  x +
              _gamP[5]) *
          x +
      _gamP[6];
  q =
      ((((((x * _gamQ[0] + _gamQ[1]) * x + _gamQ[2]) * x + _gamQ[3]) * x +
                              _gamQ[4]) *
                          x +
                      _gamQ[5]) *
                  x +
              _gamQ[6]) *
          x +
      _gamQ[7];
  return z * p / q;
}

bool _isNegInt(double x) {
  if (x < 0) {
    final (_, xf) = modf(x);
    return xf == 0;
  }
  return false;
}

/// `math.Erfc`: 1 - erf(x).
double erfc(double x) {
  const tiny = 1.0 / 72057594037927936.0; // 2**-56
  const erx = 8.45062911510467529297e-01;
  const pp0 = 1.28379167095512558561e-01;
  const pp1 = -3.25042107247001499370e-01;
  const pp2 = -2.84817495755985104766e-02;
  const pp3 = -5.77027029648944159157e-03;
  const pp4 = -2.37630166566501626084e-05;
  const qq1 = 3.97917223959155352819e-01;
  const qq2 = 6.50222499887672944485e-02;
  const qq3 = 5.08130628187576562776e-03;
  const qq4 = 1.32494738004321644526e-04;
  const qq5 = -3.96022827877536812320e-06;
  const pa0 = -2.36211856075265944077e-03;
  const pa1 = 4.14856118683748331666e-01;
  const pa2 = -3.72207876035701323847e-01;
  const pa3 = 3.18346619901161753674e-01;
  const pa4 = -1.10894694282396677476e-01;
  const pa5 = 3.54783043256182359371e-02;
  const pa6 = -2.16637559486879084300e-03;
  const qa1 = 1.06420880400844228286e-01;
  const qa2 = 5.40397917702171048937e-01;
  const qa3 = 7.18286544141962662868e-02;
  const qa4 = 1.26171219808761642112e-01;
  const qa5 = 1.36370839120290507362e-02;
  const qa6 = 1.19844998467991074170e-02;
  const ra0 = -9.86494403484714822705e-03;
  const ra1 = -6.93858572707181764372e-01;
  const ra2 = -1.05586262253232909814e+01;
  const ra3 = -6.23753324503260060396e+01;
  const ra4 = -1.62396669462573470355e+02;
  const ra5 = -1.84605092906711035994e+02;
  const ra6 = -8.12874355063065934246e+01;
  const ra7 = -9.81432934416914548592e+00;
  const sa1 = 1.96512716674392571292e+01;
  const sa2 = 1.37657754143519042600e+02;
  const sa3 = 4.34565877475229228821e+02;
  const sa4 = 6.45387271733267880336e+02;
  const sa5 = 4.29008140027567833386e+02;
  const sa6 = 1.08635005541779435134e+02;
  const sa7 = 6.57024977031928170135e+00;
  const sa8 = -6.04244152148580987438e-02;
  const rb0 = -9.86494292470009928597e-03;
  const rb1 = -7.99283237680523006574e-01;
  const rb2 = -1.77579549177547519889e+01;
  const rb3 = -1.60636384855821916062e+02;
  const rb4 = -6.37566443368389627722e+02;
  const rb5 = -1.02509513161107724954e+03;
  const rb6 = -4.83519191608651397019e+02;
  const sb1 = 3.03380607434824582924e+01;
  const sb2 = 3.25792512996573918826e+02;
  const sb3 = 1.53672958608443695994e+03;
  const sb4 = 3.19985821950859553908e+03;
  const sb5 = 2.55305040643316442583e+03;
  const sb6 = 4.74528541206955367215e+02;
  const sb7 = -2.24409524465858183362e+01;
  const invPoint35 = 2.857142857142857; // 1/0.35
  if (x.isNaN) return double.nan;
  if (x == double.infinity) return 0;
  if (x == double.negativeInfinity) return 2;
  var sign = false;
  if (x < 0) {
    x = -x;
    sign = true;
  }
  if (x < 0.84375) {
    double temp;
    if (x < tiny) {
      temp = x;
    } else {
      final z = x * x;
      final r = pp0 + z * (pp1 + z * (pp2 + z * (pp3 + z * pp4)));
      final s = 1 + z * (qq1 + z * (qq2 + z * (qq3 + z * (qq4 + z * qq5))));
      final y = r / s;
      if (x < 0.25) {
        temp = x + x * y;
      } else {
        temp = 0.5 + (x * y + (x - 0.5));
      }
    }
    return sign ? 1 + temp : 1 - temp;
  }
  if (x < 1.25) {
    final s = x - 1;
    final p =
        pa0 +
        s * (pa1 + s * (pa2 + s * (pa3 + s * (pa4 + s * (pa5 + s * pa6)))));
    final q =
        1 + s * (qa1 + s * (qa2 + s * (qa3 + s * (qa4 + s * (qa5 + s * qa6)))));
    return sign ? 1 + erx + p / q : 1 - erx - p / q;
  }
  if (x < 28) {
    final s = 1 / (x * x);
    double r, ss;
    if (x < invPoint35) {
      r =
          ra0 +
          s *
              (ra1 +
                  s *
                      (ra2 +
                          s *
                              (ra3 +
                                  s *
                                      (ra4 +
                                          s * (ra5 + s * (ra6 + s * ra7))))));
      ss =
          1 +
          s *
              (sa1 +
                  s *
                      (sa2 +
                          s *
                              (sa3 +
                                  s *
                                      (sa4 +
                                          s *
                                              (sa5 +
                                                  s *
                                                      (sa6 +
                                                          s *
                                                              (sa7 +
                                                                  s * sa8)))))));
    } else {
      if (sign && x > 6) return 2;
      r =
          rb0 +
          s * (rb1 + s * (rb2 + s * (rb3 + s * (rb4 + s * (rb5 + s * rb6)))));
      ss =
          1 +
          s *
              (sb1 +
                  s *
                      (sb2 +
                          s *
                              (sb3 +
                                  s *
                                      (sb4 +
                                          s * (sb5 + s * (sb6 + s * sb7))))));
    }
    final z = _make(_hi(x), 0); // x com 20 bits de precisão
    final rr = exp(-z * z - 0.5625) * exp((z - x) * (z + x) + r / ss);
    return sign ? 2 - rr / x : rr / x;
  }
  return sign ? 2 : 0;
}
