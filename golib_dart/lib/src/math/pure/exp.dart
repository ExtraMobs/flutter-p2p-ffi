part of '../pure.dart';

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
