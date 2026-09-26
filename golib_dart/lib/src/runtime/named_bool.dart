/// Base dos tipos nomeados sobre bool (`type Flag bool`).
library;

import '../../fixed_types/golang.dart' show GoTyped;

/// `bool` nativo não carrega métodos nem identidade de tipo: o tipo nomeado
/// é uma classe gerada sobre esta base. O código gerado desembrulha [$b]
/// nas condições e embrulha os resultados de `!`, `&&` e `||`.
abstract base class GoBool implements GoTyped {
  const GoBool(this.$b);

  /// O valor Go.
  final bool $b;

  @override
  bool operator ==(Object other) =>
      other is GoBool && other.$goType == $goType && other.$b == $b;

  @override
  int get hashCode => $b.hashCode;

  @override
  String toString() => $b ? 'true' : 'false';
}
