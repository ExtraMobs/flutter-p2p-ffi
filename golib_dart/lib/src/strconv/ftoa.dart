part of '../../strconv.dart';

/// `strconv.FormatFloat(f, fmt, prec, bitSize)`.
///
/// `'e' 'E' 'f' 'g' 'G'` reusam [formatGoFloatFmt] (`fixed_types`): dígitos
/// exatos em [BigInt], "mais curto" (`prec<0`) igual ao Ryu do Go (mesmo
/// valor: o mais curto que arredonda de volta ao `double`/`float32`
/// original é único). `'b' 'x' 'X'` são novos aqui.
Golang.String formatFloat(
  Golang.Float64 f,
  Golang.Uint8 fmt,
  Golang.Int prec,
  Golang.Int bitSize,
) => Golang.String.fromDart(
  _ftoa(f.toDouble(), fmt.toInt(), prec.toInt(), bitSize.toInt()),
);

/// `strconv.AppendFloat(dst, f, fmt, prec, bitSize)`.
Slice<Golang.Uint8> appendFloat(
  Slice<Golang.Uint8> dst,
  Golang.Float64 f,
  Golang.Uint8 fmt,
  Golang.Int prec,
  Golang.Int bitSize,
) => dst.append(_asciiBytes(formatFloat(f, fmt, prec, bitSize)));

String _ftoa(double x, int fmtChar, int prec, int bitSize) {
  if (bitSize != 32 && bitSize != 64) {
    throw Panic(
      Golang.String.fromDart('strconv: illegal AppendFloat/FormatFloat bitSize'),
    );
  }
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? '+Inf' : '-Inf';
  switch (fmtChar) {
    case 0x65: // e
    case 0x45: // E
    case 0x66: // f
    case 0x67: // g
    case 0x47: // G
      return formatGoFloatFmt(x, String.fromCharCode(fmtChar), prec, bitSize);
    case 0x62: // b
      return _fmtB(x, bitSize);
    case 0x78: // x
      return _fmtX(x, prec, false, bitSize);
    case 0x58: // X
      return _fmtX(x, prec, true, bitSize);
    default:
      // Go devolve o literal `%<fmt>` em silêncio (não há verbo inválido
      // para uma função que não lê um formato do usuário como o `fmt`).
      return '%${String.fromCharCode(fmtChar)}';
  }
}

/// Sinal, mantissa (com o bit implícito, se normal) e expoente (com viés já
/// somado) de `x`, arredondado para `bitSize` bits — igual ao início de
/// `genericFtoa` do Go. Só usado por `'b'`/`'x'`/`'X'`, que operam nos bits
/// crus (as outras letras já saem exatas de [formatGoFloatFmt]).
({bool neg, Golang.Uint64 mant, int exp}) _decompose(double x, int bitSize) {
  final mantbits = bitSize == 32 ? 23 : 52;
  final bias = bitSize == 32 ? -127 : -1023;
  bool neg;
  int rawExp;
  Golang.Uint64 frac;
  if (bitSize == 32) {
    final b = ByteData(4)..setFloat32(0, x);
    final u = b.getUint32(0);
    neg = (u >> 31) != 0;
    rawExp = (u >> 23) & 0xff;
    frac = Golang.Uint64(u & 0x7fffff);
  } else {
    final b = ByteData(8)..setFloat64(0, x);
    final hi = b.getUint32(0), lo = b.getUint32(4);
    neg = (hi >> 31) != 0;
    rawExp = (hi >> 20) & 0x7ff;
    frac = (Golang.Uint64(hi & 0xfffff) << 32) | Golang.Uint64(lo);
  }
  var exp = rawExp;
  var mant = frac;
  if (exp == 0) {
    exp = 1; // desnormalizado: expoente efetivo é `1 + bias`
  } else {
    mant = mant | (Golang.Uint64(1) << mantbits);
  }
  exp += bias;
  return (neg: neg, mant: mant, exp: exp);
}

/// `'b'`: `-ddddddddp±ddd` (mantissa em base 10, expoente binário).
String _fmtB(double x, int bitSize) {
  final mantbits = bitSize == 32 ? 23 : 52;
  final d = _decompose(x, bitSize);
  final sb = StringBuffer();
  if (d.neg) sb.write('-');
  sb.write(formatUint(d.mant, Golang.Int(10)).toDart());
  sb.write('p');
  final e = d.exp - mantbits;
  if (e >= 0) sb.write('+');
  sb.write(e.toString());
  return sb.toString();
}

/// `'x'`/`'X'`: `-0x1.yyyyp±ddd` (fração hexadecimal, expoente binário).
/// Porta de `fmtX` do Go: desloca a mantissa até o bit 60 e arredonda ali
/// (par mais próximo) para não perder bits mesmo deslocando os 64 bits
/// inteiros — por isso [Golang.Uint64] (nada de `int` cru acima de 32 bits
/// no JS) em vez do `uint64` nativo do Go.
String _fmtX(double x, int prec, bool upper, int bitSize) {
  final mantbits = bitSize == 32 ? 23 : 52;
  final d = _decompose(x, bitSize);
  var mant = d.mant;
  var exp = d.exp;
  final zero = Golang.Uint64();
  final one = Golang.Uint64(1);
  if (mant == zero) exp = 0;

  mant = mant << (60 - mantbits);
  while (mant != zero && (mant & (one << 60)) == zero) {
    mant = mant << 1;
    exp--;
  }

  if (prec >= 0 && prec < 15) {
    final shift = prec * 4;
    final extra = (mant << shift) & ((one << 60) - one);
    mant = mant >> (60 - shift);
    if ((extra | (mant & one)) > (one << 59)) mant = mant + one;
    mant = mant << (60 - shift);
    if ((mant & (one << 61)) != zero) {
      mant = mant >> 1;
      exp++;
    }
  }

  final hex = upper ? '0123456789ABCDEF' : '0123456789abcdef';
  final sb = StringBuffer();
  if (d.neg) sb.write('-');
  sb.write('0');
  sb.write(upper ? 'X' : 'x');
  sb.write(((mant >> 60) & one) == one ? '1' : '0');

  mant = mant << 4;
  if (prec < 0 && mant != zero) {
    sb.write('.');
    while (mant != zero) {
      sb.write(hex[((mant >> 60) & Golang.Uint64(15)).toInt()]);
      mant = mant << 4;
    }
  } else if (prec > 0) {
    sb.write('.');
    for (var i = 0; i < prec; i++) {
      sb.write(hex[((mant >> 60) & Golang.Uint64(15)).toInt()]);
      mant = mant << 4;
    }
  }

  sb.write(upper ? 'P' : 'p');
  var e = exp;
  if (e < 0) {
    sb.write('-');
    e = -e;
  } else {
    sb.write('+');
  }
  sb.write(e.toString().padLeft(2, '0'));
  return sb.toString();
}

/// `strconv.FormatComplex(c, fmt, prec, bitSize)`: partes real/imaginária
/// via [formatFloat] (`bitSize/2`: 32 para complex64, 64 para complex128,
/// como o Go), com `+` explícito antes de `i` quando a parte imaginária não
/// tem sinal (`NaN`/`+Inf` sem `-`).
Golang.String formatComplex(
  Golang.Complex128 c,
  Golang.Uint8 fmt,
  Golang.Int prec,
  Golang.Int bitSize,
) {
  if (bitSize.toInt() != 64 && bitSize.toInt() != 128) {
    throw Panic(Golang.String.fromDart('invalid bitSize'));
  }
  final half = Golang.Int(bitSize.toInt() ~/ 2);
  final re = formatFloat(c.real, fmt, prec, half).toDart();
  var im = formatFloat(c.imag, fmt, prec, half).toDart();
  if (!im.startsWith('+') && !im.startsWith('-')) im = '+$im';
  return Golang.String.fromDart('($re${im}i)');
}
