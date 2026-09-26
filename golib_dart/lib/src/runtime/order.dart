/// Builtins `min` e `max` do Go (1.21) sobre operandos ordenados.
library;

/// `min(x, y, ...)` de inteiros ou strings: o menor pela ordem do tipo.
/// Devolve o próprio operando (preserva tipos nomeados).
T minOf<T>(List<T> xs, bool Function(T a, T b) less) {
  var r = xs[0];
  for (var i = 1; i < xs.length; i++) {
    if (less(xs[i], r)) r = xs[i];
  }
  return r;
}

/// `max(x, y, ...)` de inteiros ou strings.
T maxOf<T>(List<T> xs, bool Function(T a, T b) less) {
  var r = xs[0];
  for (var i = 1; i < xs.length; i++) {
    if (less(r, xs[i])) r = xs[i];
  }
  return r;
}

/// `min` de floats: qualquer NaN dá NaN e `-0.0` é menor que `+0.0`.
T minFloat<T>(List<T> xs, double Function(T) d) =>
    _pickFloat(xs, d, (a, b) => a < b || (a == 0 && b == 0 && a.isNegative));

/// `max` de floats: qualquer NaN dá NaN e `+0.0` é maior que `-0.0`.
T maxFloat<T>(List<T> xs, double Function(T) d) =>
    _pickFloat(xs, d, (a, b) => a > b || (a == 0 && b == 0 && !a.isNegative));

T _pickFloat<T>(
  List<T> xs,
  double Function(T) d,
  bool Function(double a, double b) better,
) {
  var r = xs[0];
  for (var i = 0; i < xs.length; i++) {
    final v = d(xs[i]);
    if (v.isNaN) return xs[i];
    if (i > 0 && better(v, d(r))) r = xs[i];
  }
  return r;
}
