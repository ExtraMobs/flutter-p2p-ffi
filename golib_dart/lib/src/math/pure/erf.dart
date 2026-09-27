part of '../pure.dart';

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
