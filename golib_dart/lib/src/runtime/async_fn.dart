/// Função síncrona vista como valor de uma classe de func `async` (M4,
/// `g2d/analysis/color.py`): o g2d dá a todo valor de uma assinatura Go o
/// mesmo tipo Dart, `Future<R> Function(...)` se alguma função que suspende
/// vira valor dela. Uma função síncrona (declarada, method value, da stdlib)
/// que entra nessa classe é embrulhada aqui; quem chama pelo valor espera.
library;

Future<R> Function() async0<R>(R Function() f) =>
    () async => f();

Future<R> Function(A) async1<R, A>(R Function(A) f) =>
    (a) async => f(a);

Future<R> Function(A, B) async2<R, A, B>(R Function(A, B) f) =>
    (a, b) async => f(a, b);

Future<R> Function(A, B, C) async3<R, A, B, C>(R Function(A, B, C) f) =>
    (a, b, c) async => f(a, b, c);

Future<R> Function(A, B, C, D) async4<R, A, B, C, D>(
  R Function(A, B, C, D) f,
) => (a, b, c, d) async => f(a, b, c, d);

Future<R> Function(A, B, C, D, E) async5<R, A, B, C, D, E>(
  R Function(A, B, C, D, E) f,
) => (a, b, c, d, e) async => f(a, b, c, d, e);

Future<R> Function(A, B, C, D, E, F) async6<R, A, B, C, D, E, F>(
  R Function(A, B, C, D, E, F) f,
) => (a, b, c, d, e, g) async => f(a, b, c, d, e, g);

Future<R> Function(A, B, C, D, E, F, G) async7<R, A, B, C, D, E, F, G>(
  R Function(A, B, C, D, E, F, G) f,
) => (a, b, c, d, e, g, h) async => f(a, b, c, d, e, g, h);

Future<R> Function(A, B, C, D, E, F, G, H) async8<R, A, B, C, D, E, F, G, H>(
  R Function(A, B, C, D, E, F, G, H) f,
) => (a, b, c, d, e, g, h, i) async => f(a, b, c, d, e, g, h, i);
