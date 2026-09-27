part of '../pure.dart';

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
