part of '../pure.dart';

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
