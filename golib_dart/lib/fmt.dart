/// Shim do pacote Go `fmt`.
library;

import 'dart:io';

import 'builtin.dart';

/// `fmt.Println`: operandos em `%v` separados por espaço, mais newline.
(int, GoError?) println(List<Object?> a) {
  final s = '${a.map(formatV).join(' ')}\n';
  stdout.write(s);
  return (
    s.length,
    null,
  ); // ponytail: conta UTF-16, não bytes; UTF-8 quando []byte existir
}

/// `fmt.Sprint`: espaço entre operandos quando nenhum dos dois é string.
String sprint(List<Object?> a) {
  final b = StringBuffer();
  for (var i = 0; i < a.length; i++) {
    if (i > 0 && a[i] is! String && a[i - 1] is! String) b.write(' ');
    b.write(formatV(a[i]));
  }
  return b.toString();
}

/// Formatação `%v` do Go para os valores que o runtime conhece.
String formatV(Object? v) => switch (v) {
  null => '<nil>',
  double d => _formatFloat(d),
  GoError e => e.error(),
  _ => v.toString(),
};

/// `strconv.FormatFloat(d, 'g', -1, 64)`: dígitos mínimos, notação
/// exponencial quando o expoente decimal é < -4 ou >= 6.
String _formatFloat(double d) {
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? '+Inf' : '-Inf';
  if (d == 0) return d.isNegative ? '-0' : '0';
  final exp = d.toStringAsExponential(); // mínimo único: "1.5e+7"
  final i = exp.indexOf('e');
  final e = int.parse(exp.substring(i + 1));
  if (e < -4 || e >= 6) {
    final sign = e < 0 ? '-' : '+';
    return '${exp.substring(0, i)}e$sign${e.abs().toString().padLeft(2, '0')}';
  }
  final s = d.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
