part of '../../strconv.dart';

/// `strconv.ParseFloat(s, bitSize)`.
///
/// Porta de `internal/strconv/atof.go` (Go 1.26), decimal e hexadecimal,
/// `inf`/`infinity`/`nan` (sinal só em `inf`/`infinity`, como o Go).
///
/// Não porta o algoritmo rápido Eisel-Lemire: ele só acelera o caminho comum
/// (o resultado é garantido idêntico ao caminho lento do Go quando os dois
/// concordam, e o Go sempre cai no lento quando não concordam). Em vez de
/// portar os dois, este shim sempre faz a conversão exata — mesma técnica de
/// `_roundDecimal`/`_fixed` em `fixed_types/golang/src/float_format.dart`,
/// mas na direção contrária (decimal → binário): a fração exata
/// `mantissa * 10^expoente` é comparada em [BigInt] com a fronteira de
/// arredondamento (par mais próximo), então o resultado é bit a bit igual ao
/// do Go para toda entrada, só potencialmente mais lento nos casos em que o
/// Go usaria o atalho.
(Golang.Float64, GoError?) parseFloat(Golang.String s, Golang.Int bitSize) {
  final bits = bitSize.toInt() == 32 ? 32 : 64;
  final (v, e) = _atof(s, bits);
  return (
    Golang.Float64(v),
    e == null ? null : NumError('ParseFloat', s, e),
  );
}

(double, GoError?) _atof(Golang.String s, int bitSize) {
  final mantbits = bitSize == 32 ? 23 : 52;
  final expbits = bitSize == 32 ? 8 : 11;
  final bias = bitSize == 32 ? -127 : -1023;

  final (sv, sn, sok) = _specialFloat(s);
  if (sok && sn == s.length) return (sv, null);

  final hex = _scanHexFloat(s);
  if (hex != null) return _atofHex(hex, mantbits, expbits, bias);

  final dec = _scanDecFloat(s);
  if (dec == null) return (0.0, errSyntax);
  return _atofDecimal(dec, mantbits, expbits, bias);
}

/// Prefixo comum de `s` com `prefix` (minúsculo) ignorando maiúsculas.
int _commonPrefixLenIgnoreCase(Golang.String s, int from, String prefix) {
  final n = (prefix.length < s.length - from ? prefix.length : s.length - from);
  for (var i = 0; i < n; i++) {
    if (_lower(s[from + i]) != prefix.codeUnitAt(i)) return i;
  }
  return n;
}

/// Porta de `internal/strconv.special`: `nan` (sem sinal) e `inf`/`infinity`
/// (com sinal opcional), ignorando caixa.
(double, int, bool) _specialFloat(Golang.String s) {
  if (s.length == 0) return (0, 0, false);
  final c0 = s[0];
  if (c0 == 0x2b || c0 == 0x2d) {
    final neg = c0 == 0x2d;
    final n = _commonPrefixLenIgnoreCase(s, 1, 'infinity');
    final nn = (n > 3 && n < 8) ? 3 : n;
    if (nn == 3 || nn == 8) {
      return (neg ? double.negativeInfinity : double.infinity, 1 + nn, true);
    }
    return (0, 0, false);
  }
  if (c0 == 0x69 || c0 == 0x49) {
    final n = _commonPrefixLenIgnoreCase(s, 0, 'infinity');
    final nn = (n > 3 && n < 8) ? 3 : n;
    if (nn == 3 || nn == 8) return (double.infinity, nn, true);
    return (0, 0, false);
  }
  if (c0 == 0x6e || c0 == 0x4e) {
    if (_commonPrefixLenIgnoreCase(s, 0, 'nan') == 3) return (double.nan, 3, true);
    return (0, 0, false);
  }
  return (0, 0, false);
}

/// Dígitos decimais já sem zeros à esquerda: `valor = mag * 10^(dp - nd)`.
class _DecFloat {
  const _DecFloat(this.mag, this.nd, this.dp, this.neg);
  final BigInt mag;
  final int nd;
  final int dp;
  final bool neg;
}

/// Combina `readFloat`+`decimal.set` do Go: escaneia o token decimal inteiro
/// (a string toda; `ParseFloat` não aceita sufixo), dígitos com `_`, um `.`
/// e um `e`/`E` opcionais, e valida os underscores como o Go (mesma regra de
/// `_underscoreOK` dos inteiros).
_DecFloat? _scanDecFloat(Golang.String s) {
  final n = s.length;
  var i = 0;
  var neg = false;
  if (i < n && (s[i] == 0x2b || s[i] == 0x2d)) {
    neg = s[i] == 0x2d;
    i++;
  }
  var sawdot = false, sawdigits = false, underscores = false;
  var mag = BigInt.zero;
  var nd = 0, dp = 0;
  while (i < n) {
    final c = s[i];
    if (c == 0x5f) {
      underscores = true;
      i++;
      continue;
    }
    if (c == 0x2e) {
      if (sawdot) break;
      sawdot = true;
      dp = nd;
      i++;
      continue;
    }
    if (c >= 0x30 && c <= 0x39) {
      sawdigits = true;
      if (c == 0x30 && nd == 0) {
        dp--;
        i++;
        continue;
      }
      mag = mag * BigInt.from(10) + BigInt.from(c - 0x30);
      nd++;
      i++;
      continue;
    }
    break;
  }
  if (!sawdigits) return null;
  if (!sawdot) dp = nd;
  if (i < n && (s[i] == 0x65 || s[i] == 0x45)) {
    i++;
    if (i >= n) return null;
    var esign = 1;
    if (s[i] == 0x2b) {
      i++;
    } else if (s[i] == 0x2d) {
      esign = -1;
      i++;
    }
    if (i >= n || s[i] < 0x30 || s[i] > 0x39) return null;
    var e = 0;
    while (i < n && (s[i] == 0x5f || (s[i] >= 0x30 && s[i] <= 0x39))) {
      if (s[i] == 0x5f) {
        underscores = true;
        i++;
        continue;
      }
      if (e < 10000) e = e * 10 + (s[i] - 0x30);
      i++;
    }
    dp += e * esign;
  }
  if (i != n) return null;
  if (underscores && !_underscoreOK(s)) return null;
  return _DecFloat(mag, nd, dp, neg);
}

/// `x` (positivo) deslocado por `k` bits de um [BigInt]: `k>=0` multiplica,
/// `k<0` divide (truncando, como um `Shift` de potência de dois exato).
BigInt _bigShift(BigInt x, int k) => k >= 0 ? (x << k) : (x >> -k);

/// Porta de `decimal.floatBits`, com a fração exata `mag * 10^(dp-nd)` em
/// [BigInt] no lugar do array de dígitos decimais do Go (mesma matemática:
/// escala por potências de dois até `[2^mantbits, 2^(mantbits+1))`,
/// arredondando par mais próximo).
(double, GoError?) _atofDecimal(_DecFloat dec, int mantbits, int expbits, int bias) {
  if (dec.nd == 0) return (dec.neg ? -0.0 : 0.0, null);
  final e10 = dec.dp - dec.nd;
  var num = dec.mag;
  var den = BigInt.one;
  if (e10 >= 0) {
    num = num * BigInt.from(10).pow(e10);
  } else {
    den = BigInt.from(10).pow(-e10);
  }
  var binExp = num.bitLength - den.bitLength;
  while (num < _bigShift(den, binExp)) {
    binExp--;
  }
  while (num >= _bigShift(den, binExp + 1)) {
    binExp++;
  }
  final minExp = bias + 1;
  var expUsed = binExp < minExp ? minExp : binExp;
  final maxExpField = (1 << expbits) - 1;
  final shift = mantbits - expUsed;
  final sNum = shift >= 0 ? (num << shift) : num;
  final sDen = shift >= 0 ? den : (den << -shift);
  var q = sNum ~/ sDen;
  final r = sNum - q * sDen;
  final twice = r * BigInt.two;
  if (twice > sDen || (twice == sDen && q.isOdd)) q += BigInt.one;
  // Arredondar pode ter levado a mantissa a `2^(mantbits+1)` (ex.: 1.111...
  // → 10.000...): meio bit a mais no expoente, como no Go.
  if (q == BigInt.one << (mantbits + 1)) {
    q = q >> 1;
    expUsed++;
  }
  if (expUsed - bias >= maxExpField) {
    return (dec.neg ? double.negativeInfinity : double.infinity, errRange);
  }
  if ((q & (BigInt.one << mantbits)) == BigInt.zero) {
    expUsed = bias; // subnormal ou zero
  }
  final frac = Golang.Uint64.fromBigInt(q & ((BigInt.one << mantbits) - BigInt.one));
  final storedExp = (expUsed - bias) & maxExpField;
  return (_assembleFloat(dec.neg, storedExp, frac, mantbits), null);
}

/// Mantissa/expoente de um hexadecimal (`0x1.8p3`): até 16 dígitos hex
/// exatos em [Golang.Uint64] (o resto vira `trunc`, como o `readFloat` do
/// Go), expoente `p` obrigatório.
class _HexFloat {
  const _HexFloat(this.neg, this.mantissa, this.exp, this.trunc);
  final bool neg;
  final Golang.Uint64 mantissa;
  final int exp;
  final bool trunc;
}

_HexFloat? _scanHexFloat(Golang.String s) {
  final n = s.length;
  var i = 0;
  var neg = false;
  if (i < n && (s[i] == 0x2b || s[i] == 0x2d)) {
    neg = s[i] == 0x2d;
    i++;
  }
  if (!(i + 1 < n && s[i] == 0x30 && (s[i + 1] | 0x20) == 0x78)) return null;
  i += 2;
  var sawdot = false, sawdigits = false, underscores = false, trunc = false;
  var nd = 0, ndMant = 0, dp = 0;
  var mant = Golang.Uint64();
  while (i < n) {
    final c = s[i];
    if (c == 0x5f) {
      underscores = true;
      i++;
      continue;
    }
    if (c == 0x2e) {
      if (sawdot) break;
      sawdot = true;
      dp = nd;
      i++;
      continue;
    }
    var digit = -1;
    if (c >= 0x30 && c <= 0x39) {
      digit = c - 0x30;
    } else {
      final lc = _lower(c);
      if (lc >= 0x61 && lc <= 0x66) digit = lc - 0x61 + 10;
    }
    if (digit < 0) break;
    sawdigits = true;
    if (digit == 0 && nd == 0) {
      dp--;
      i++;
      continue;
    }
    nd++;
    if (ndMant < 16) {
      mant = mant * Golang.Uint64(16) + Golang.Uint64(digit);
      ndMant++;
    } else {
      trunc = true;
    }
    i++;
  }
  if (!sawdigits) return null;
  if (!sawdot) dp = nd;
  dp *= 4;
  ndMant *= 4;
  if (i < n && (s[i] | 0x20) == 0x70) {
    i++;
    if (i >= n) return null;
    var esign = 1;
    if (s[i] == 0x2b) {
      i++;
    } else if (s[i] == 0x2d) {
      esign = -1;
      i++;
    }
    if (i >= n || s[i] < 0x30 || s[i] > 0x39) return null;
    var e = 0;
    while (i < n && (s[i] == 0x5f || (s[i] >= 0x30 && s[i] <= 0x39))) {
      if (s[i] == 0x5f) {
        underscores = true;
        i++;
        continue;
      }
      if (e < 10000) e = e * 10 + (s[i] - 0x30);
      i++;
    }
    dp += e * esign;
  } else {
    return null; // expoente `p` é obrigatório em hexadecimal
  }
  if (i != n) return null;
  if (underscores && !_underscoreOK(s)) return null;
  final exp = mant == Golang.Uint64() ? 0 : dp - ndMant;
  return _HexFloat(neg, mant, exp, trunc);
}

/// Porta de `internal/strconv.atofHex`: arredonda a mantissa hexadecimal
/// (já um inteiro exato) para `1+mantbits` bits, par mais próximo.
(double, GoError?) _atofHex(_HexFloat h, int mantbits, int expbits, int bias) {
  final zero = Golang.Uint64();
  final one = Golang.Uint64(1);
  final maxExp = (1 << expbits) + bias - 2;
  final minExp = bias + 1;
  var exp = h.exp + mantbits;
  var mant = h.mantissa;
  while (mant != zero && (mant >> (mantbits + 2)) == zero) {
    mant = mant << 1;
    exp--;
  }
  if (h.trunc) mant = mant | one;
  while ((mant >> (1 + mantbits + 2)) != zero) {
    mant = (mant >> 1) | (mant & one);
    exp++;
  }
  while (mant > one && exp < minExp - 2) {
    mant = (mant >> 1) | (mant & one);
    exp++;
  }
  var round = mant & Golang.Uint64(3);
  mant = mant >> 2;
  round = round | (mant & one);
  exp += 2;
  if (round == Golang.Uint64(3)) {
    mant = mant + one;
    if (mant == (one << (1 + mantbits))) {
      mant = mant >> 1;
      exp++;
    }
  }
  if ((mant >> mantbits) == zero) exp = bias;
  GoError? err;
  if (exp > maxExp) {
    mant = one << mantbits;
    exp = maxExp + 1;
    err = errRange;
  }
  final maxExpField = (1 << expbits) - 1;
  final frac = mant & ((one << mantbits) - one);
  final storedExp = (exp - bias) & maxExpField;
  return (_assembleFloat(h.neg, storedExp, frac, mantbits), err);
}

/// `sinal | expoente com viés | fração` como `double`, sem passar por um
/// inteiro de 64 bits só (proibido no JS): as duas metades de 32 bits vão
/// direto para o `ByteData`, como em `float_format.dart`.
double _assembleFloat(bool neg, int storedExp, Golang.Uint64 frac, int mantbits) {
  if (mantbits == 52) {
    final hi = (neg ? 0x80000000 : 0) | (storedExp << 20) | (frac.$hi & 0xfffff);
    final b = ByteData(8)
      ..setUint32(0, hi)
      ..setUint32(4, frac.$lo);
    return b.getFloat64(0);
  }
  final word = (neg ? 0x80000000 : 0) | (storedExp << 23) | frac.$lo;
  final b = ByteData(4)..setUint32(0, word);
  return b.getFloat32(0);
}
