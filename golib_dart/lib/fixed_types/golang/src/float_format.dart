// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

/// Go `strconv.FormatFloat(x, 'g', -1, bits)` — o `%v` de float32/float64:
/// menor quantidade de dígitos que reconstrói o valor na largura `bits`;
/// notação exponencial quando o expoente decimal é < -4 ou >= 6.
String formatGoFloat(double x, int bits) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? '+Inf' : '-Inf';
  if (x == 0) return x.isNegative ? '-0' : '0';
  final sign = x.isNegative ? '-' : '';
  final (digits, exp) = _shortest(x.abs(), bits);
  if (exp < -4 || exp >= 6) {
    final mantissa = digits.length == 1
        ? digits
        : '${digits[0]}.${digits.substring(1)}';
    final e = exp.abs().toString().padLeft(2, '0');
    return '$sign${mantissa}e${exp < 0 ? '-' : '+'}$e';
  }
  if (exp < 0) return '${sign}0.${'0' * (-exp - 1)}$digits';
  if (digits.length <= exp + 1) return '$sign${digits.padRight(exp + 1, '0')}';
  return '$sign${digits.substring(0, exp + 1)}.${digits.substring(exp + 1)}';
}

/// Dígitos significativos (sem zeros à direita) e expoente decimal do
/// primeiro dígito. binary64: o `toStringAsExponential()` do Dart já é o
/// mais curto. binary32: menor precisão `p` cujo arredondamento decimal exato
/// (meio → par, como o Ryu do Go) volta ao mesmo binary32.
(String, int) _shortest(double x, int bits) {
  if (bits == 32) {
    final probe = ByteData(4);
    for (var p = 1; p <= 9; p++) {
      final (digits, exp) = _roundDecimal(x, p);
      probe.setFloat32(0, double.parse('${digits}e${exp - p + 1}'));
      if (probe.getFloat32(0) == x) return (_trimZeros(digits), exp);
    }
  }
  final s = x.toStringAsExponential();
  final i = s.indexOf('e');
  return (
    _trimZeros(s.substring(0, i).replaceFirst('.', '')),
    int.parse(s.substring(i + 1)),
  );
}

String _trimZeros(String digits) {
  var end = digits.length;
  while (end > 1 && digits[end - 1] == '0') {
    end--;
  }
  return digits.substring(0, end);
}

/// `x` (> 0, finito) com exatamente `p` dígitos significativos, arredondado
/// meio-para-par sobre o valor binário exato. Devolve (dígitos, expoente).
(String, int) _roundDecimal(double x, int p) {
  final b = ByteData(8)..setFloat64(0, x);
  // getUint64 não existe no dart2js: duas metades de 32 bits.
  final hi = b.getUint32(0), lo = b.getUint32(4);
  final field = (hi >> 20) & 0x7ff;
  final frac = (BigInt.from(hi & 0xfffff) << 32) | BigInt.from(lo);
  final mant = field == 0 ? frac : frac | (BigInt.one << 52);
  final e2 = field == 0 ? -1074 : field - 1075;
  var exp = int.parse(x.toStringAsExponential().split('e')[1]);
  final low = BigInt.from(10).pow(p - 1);
  final high = low * BigInt.from(10);
  while (true) {
    var num = mant, den = BigInt.one;
    if (e2 >= 0) {
      num <<= e2;
    } else {
      den <<= -e2;
    }
    final k = p - 1 - exp;
    if (k >= 0) {
      num *= BigInt.from(10).pow(k);
    } else {
      den *= BigInt.from(10).pow(-k);
    }
    var q = num ~/ den;
    final twice = (num - q * den) * BigInt.two;
    if (twice > den || (twice == den && q.isOdd)) q += BigInt.one;
    if (q >= high) {
      exp++;
    } else if (q < low) {
      exp--;
    } else {
      return (q.toString(), exp);
    }
  }
}
