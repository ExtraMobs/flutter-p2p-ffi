part of '../../strconv.dart';

// ParseFloat: gramática e erros do `internal/strconv/atof.go` do Go 1.26. O
// arredondamento decimal usa BigInt exato (meio-para-par), que dá o mesmo
// resultado do Eisel-Lemire + decimal lento do Go (ambos são o float mais
// próximo); o hexadecimal é a porta de `atofHex`.

int _lc(int c) => c | 0x20;

/// `commonPrefixLenIgnoreCase(s[at:], prefix)`.
int _prefixLen(Uint8List s, int at, String prefix) {
  final n = prefix.length < s.length - at ? prefix.length : s.length - at;
  for (var i = 0; i < n; i++) {
    var c = s[at + i];
    if (c >= 0x41 && c <= 0x5a) c += 0x20;
    if (c != prefix.codeUnitAt(i)) return i;
  }
  return n;
}

/// `special`: (valor, consumidos) ou null.
(double, int)? _special(Uint8List s) {
  if (s.isEmpty) return null;
  var sign = 1;
  var nsign = 0;
  var at = 0;
  var tryInf = false;
  switch (s[0]) {
    case 0x2b || 0x2d:
      if (s[0] == 0x2d) sign = -1;
      nsign = 1;
      at = 1;
      tryInf = true;
    case 0x69 || 0x49:
      tryInf = true;
    case 0x6e || 0x4e:
      if (_prefixLen(s, 0, 'nan') == 3) return (naN().toDouble(), 3);
  }
  if (tryInf) {
    var n = _prefixLen(s, at, 'infinity');
    if (3 < n && n < 8) n = 3;
    if (n == 3 || n == 8) {
      return (sign < 0 ? double.negativeInfinity : double.infinity, nsign + n);
    }
  }
  return null;
}

final double _p2e500 = () {
  var x = 1.0;
  for (var i = 0; i < 500; i++) {
    x *= 2;
  }
  return x;
}();

/// `x * 2^e` exato enquanto o resultado for representável.
double _ldexp(double x, int e) {
  while (e > 500) {
    x *= _p2e500;
    e -= 500;
  }
  while (e < -500) {
    x /= _p2e500;
    e += 500;
  }
  var p = 1.0;
  for (var i = 0; i < e.abs(); i++) {
    p *= 2;
  }
  return e < 0 ? x / p : x * p;
}

/// Constrói o float mais próximo de `num/den` (num > 0), meio-para-par.
/// Devolve (valor ≥ 0, overflow).
(double, bool) _roundRatio(BigInt num, BigInt den, int mantBits, int bias) {
  final minE = bias + 1 - mantBits; // expoente do menor bit (denormal)
  final maxE = -bias - mantBits; // maior expoente do bit baixo: 1023 - 52
  var e2 = num.bitLength - den.bitLength - (mantBits + 1);
  if (e2 < minE) e2 = minE;
  BigInt scaled(int e) =>
      e >= 0 ? (num << 0) ~/ (den << e) : (num << -e) ~/ den;
  // Garante m em [2^mantBits, 2^(mantBits+1)) (ou denormal em e2 == minE).
  var m = scaled(e2);
  while (m >= BigInt.one << (mantBits + 1)) {
    e2++;
    m = scaled(e2);
  }
  while (m < BigInt.one << mantBits && e2 > minE) {
    e2--;
    m = scaled(e2);
  }
  final n2 = e2 >= 0 ? num : num << -e2;
  final d2 = e2 >= 0 ? den << e2 : den;
  final rem = n2 - m * d2;
  final twice = rem << 1;
  final c = twice.compareTo(d2);
  if (c > 0 || (c == 0 && m.isOdd)) m += BigInt.one;
  if (m == BigInt.one << (mantBits + 1)) {
    m >>= 1;
    e2++;
  }
  if (e2 > maxE) return (double.infinity, true);
  return (_ldexp(m.toDouble(), e2), false);
}

bool _underscoreOKFloat(Uint8List s, int end) {
  // `underscoreOK` do Go sobre s[:end] (mesma lógica de `_underscoreOK`).
  return _underscoreOK(
    Golang.String.fromBytes(Uint8List.sublistView(s, 0, end)),
  );
}

/// `atof32`/`atof64`: (valor, consumidos, erro).
(double, int, _E?) _atof(Uint8List s, int bitSize) {
  final sp = _special(s);
  if (sp != null) {
    return (
      bitSize == 32 ? Golang.Float32(sp.$1).toDouble() : sp.$1,
      sp.$2,
      null,
    );
  }
  final mantBits = bitSize == 32 ? 23 : 52;
  final bias = bitSize == 32 ? -127 : -1023;
  var i = 0;
  var neg = false;
  if (i >= s.length) return (0, 0, _E.syntax);
  if (s[i] == 0x2b) {
    i++;
  } else if (s[i] == 0x2d) {
    i++;
    neg = true;
  }
  var base = 10;
  var expChar = 0x65;
  var hex = false;
  if (i + 2 < s.length && s[i] == 0x30 && _lc(s[i + 1]) == 0x78) {
    base = 16;
    i += 2;
    expChar = 0x70;
    hex = true;
  }
  const maxSig = 800;
  var underscores = false;
  var sawDot = false;
  var sawDigits = false;
  var nd = 0; // dígitos significativos vistos (sem zeros à esquerda)
  var dp = 0;
  var trunc = false;
  final digits = StringBuffer(); // mantissa (até maxSig dígitos)
  var kept = 0;
  loop:
  for (; i < s.length; i++) {
    final c = s[i];
    switch (c) {
      case 0x5f:
        underscores = true;
        continue loop;
      case 0x2e:
        if (sawDot) break loop;
        sawDot = true;
        dp = nd;
        continue loop;
    }
    final isDec = c >= 0x30 && c <= 0x39;
    final isHex = base == 16 && _lc(c) >= 0x61 && _lc(c) <= 0x66;
    if (!isDec && !isHex) break;
    sawDigits = true;
    if (c == 0x30 && nd == 0) {
      dp--;
      continue;
    }
    nd++;
    if (kept < maxSig) {
      digits.writeCharCode(c);
      kept++;
    } else if (c != 0x30) {
      trunc = true;
    }
  }
  if (!sawDigits) return (0, i, _E.syntax);
  if (!sawDot) dp = nd;
  if (base == 16) dp *= 4;
  var e = 0;
  if (i < s.length && _lc(s[i]) == expChar) {
    i++;
    if (i >= s.length) return (0, i, _E.syntax);
    var esign = 1;
    if (s[i] == 0x2b) {
      i++;
    } else if (s[i] == 0x2d) {
      i++;
      esign = -1;
    }
    if (i >= s.length || s[i] < 0x30 || s[i] > 0x39) {
      return (0, i, _E.syntax);
    }
    for (
      ;
      i < s.length && ((s[i] >= 0x30 && s[i] <= 0x39) || s[i] == 0x5f);
      i++
    ) {
      if (s[i] == 0x5f) {
        underscores = true;
        continue;
      }
      if (e < 10000) e = e * 10 + s[i] - 0x30;
    }
    dp += e * esign;
  } else if (base == 16) {
    return (0, i, _E.syntax);
  }
  if (underscores && !_underscoreOKFloat(s, i)) return (0, i, _E.syntax);

  final text = digits.toString();
  final sign = neg ? -1.0 : 1.0;
  if (text.isEmpty) return (neg ? -0.0 : 0.0, i, null);
  var mant = BigInt.parse(text, radix: base);
  if (mant == BigInt.zero) return (neg ? -0.0 : 0.0, i, null);
  // valor = mant * (base^-kept) * 2^dp (hex) ou 10^dp (decimal), com dp a
  // posição do ponto decimal em relação ao primeiro dígito significativo.
  if (hex) {
    // dp em bits: valor = 0.d1d2... (hex) * 2^dp  ⇒ mant/16^kept * 2^dp.
    var exp2 = dp - kept * 4;
    if (trunc) {
      mant = (mant << 1) | BigInt.one; // sticky
      exp2 -= 1;
    }
    final (v, ovf) = exp2 >= 0
        ? _roundRatio(mant << exp2, BigInt.one, mantBits, bias)
        : _roundRatio(mant, BigInt.one << -exp2, mantBits, bias);
    return (sign * v, i, ovf ? _E.range : null);
  }
  if (dp > 310) return (sign * double.infinity, i, _E.range);
  if (dp < -330) return (neg ? -0.0 : 0.0, i, null);
  var exp10 = dp - kept;
  if (trunc) {
    mant = mant * BigInt.from(10) + BigInt.one; // sticky
    exp10 -= 1;
  }
  final (v, ovf) = exp10 >= 0
      ? _roundRatio(
          mant * BigInt.from(10).pow(exp10),
          BigInt.one,
          mantBits,
          bias,
        )
      : _roundRatio(mant, BigInt.from(10).pow(-exp10), mantBits, bias);
  var r = v;
  if (v == 0.0) return (neg ? -0.0 : 0.0, i, null);
  r = sign * v;
  return (r, i, ovf ? _E.range : null);
}

/// `strconv.ParseFloat(s, bitSize)`.
(Golang.Float64, GoError?) parseFloat(Golang.String s, Golang.Int bitSize) {
  final b = s.toBytes();
  final (f, n, e) = _atof(b, bitSize.toInt() == 32 ? 32 : 64);
  if (n != b.length) {
    return (Golang.Float64(), _NumError('ParseFloat', s, errSyntax));
  }
  if (e == null) return (Golang.Float64(f), null);
  return (
    Golang.Float64(e == _E.syntax ? 0.0 : f),
    _toError('ParseFloat', s, 0, bitSize.toInt(), e),
  );
}
