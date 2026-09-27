part of '../pure.dart';

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
