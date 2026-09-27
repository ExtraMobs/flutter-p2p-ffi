part of '../pure.dart';

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
