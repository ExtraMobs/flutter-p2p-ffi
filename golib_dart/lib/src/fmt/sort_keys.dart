part of '../../fmt.dart';

/// Ordem do internal/fmtsort.compare: nil primeiro; números por valor (NaN
/// antes); strings por bytes; false antes de true; complex pela parte real e
/// depois a imaginária; structs e arrays campo a campo.
///
/// Dois casos o Go ordena por endereço de memória, que não é reproduzível:
/// ponteiros (aqui empatam e ficam na ordem de inserção, que costuma ser a
/// de alocação) e o tipo dinâmico de chaves interface de tipos diferentes.
int _compareKeys(Object? a, Object? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  final ta = _keyType(a), tb = _keyType(b);
  // Limite (⚠️ em docs/mapping-spec.md): o Go compara os endereços dos
  // descritores de tipo, que seguem o layout do linker (nomeados de main,
  // depois string, int8, int64, int, uint, ... no gc 1.25) e mudam com os
  // pacotes linkados; o nome do tipo só dá uma ordem determinística.
  if (ta != tb) return ta.compareTo(tb);
  switch ((a, b)) {
    case (GoValue($nilPtr: true), _) || (_, GoValue($nilPtr: true)):
      return 0;
    case (final bool x, final bool y):
      return x == y ? 0 : (x ? 1 : -1);
    case (final Golang.Complex128 x, final Golang.Complex128 y):
      final c = x.real.compareTo(y.real);
      return c != 0 ? c : x.imag.compareTo(y.imag);
    case (final Golang.Complex64 x, final Golang.Complex64 y):
      final c = x.real.compareTo(y.real);
      return c != 0 ? c : x.imag.compareTo(y.imag);
    case (final Golang.ComplexBase x, final Golang.ComplexBase y):
      return _compareKeys(x.$c, y.$c);
    case (final GoStruct x, final GoStruct y):
      return _compareAll(x.$fields, y.$fields);
    case (final GoArray x, final GoArray y):
      return _compareAll(x.items, y.items);
    case (final Comparable x, final Comparable y):
      return x.compareTo(y);
  }
  return 0; // ponteiros (Addr, Ptr): ordem de inserção
}

int _compareAll(Iterable<Object?> a, Iterable<Object?> b) {
  final ib = b.iterator;
  for (final x in a) {
    ib.moveNext();
    final c = _compareKeys(x, ib.current);
    if (c != 0) return c;
  }
  return 0;
}

String _keyType(Object k) => switch (k) {
  Golang.GoTyped t => t.$goType,
  bool() => 'bool',
  Golang.Complex128() => 'complex128',
  Golang.Complex64() => 'complex64',
  _ => '',
};
