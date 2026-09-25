/// Semântica de valor das structs Go e de ponteiros como valores.
library;

import '../../fixed_types/golang.dart' show GoTyped;

/// Valor Go que ocupa armazenamento próprio (struct, array): o objeto é o
/// próprio endereço, atribuir/passar copia ([$copy]) e `x = y` sobrescreve
/// in-place ([$set]), preservando ponteiros para `x`.
abstract class GoValue<T extends GoValue<T>> implements GoTyped {
  /// `true` na cópia que representa o valor *por valor* dentro de uma
  /// interface; `false` no objeto usado como variável ou apontado por `*T`.
  /// Distingue `x.(T)` de `x.(*T)` e `{...}` de `&{...}` no fmt.
  bool $isValue = false;

  /// `true` só na sentinela `T.$nil`: o ponteiro nil tipado `(*T)(nil)`
  /// guardado numa interface (que, no Go, não é nil). Nunca é mutada.
  bool $nilPtr = false;

  /// Cópia de valor (aninhados copiados; ponteiros, slices, maps
  /// compartilhados, como no Go).
  T $copy();

  /// `x = other` do Go: copia o conteúdo de [other] para este objeto.
  void $set(T other);

  /// Cópia para guardar o valor numa interface.
  T $ifaceCopy() => $copy()..$isValue = true;
}

/// Base de toda struct Go gerada pelo g2d.
///
/// `==` compara campo a campo sobre [$fields] (campos ponteiro vêm como
/// [Addr], comparados por identidade).
abstract class GoStruct<T extends GoStruct<T>> extends GoValue<T> {
  /// Method set de T (valor) e de *T; ver [$methods].
  List<String> get $valueMethods => const [];
  List<String> get $ptrMethods => const [];

  @override
  List<String> get $methods => $isValue ? $valueMethods : $ptrMethods;

  /// Campos em ordem de declaração (ponteiros embrulhados em [Addr]).
  List<Object?> get $fields;

  @override
  bool operator ==(Object other) {
    if (other is! GoStruct<T> || other.runtimeType != runtimeType) return false;
    final a = $fields, b = other.$fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll($fields);
}

/// Um ponteiro Go como valor: igualdade e hash por identidade do alvo.
///
/// Structs apontadas são o próprio objeto (`*T` é `T?`); quando o ponteiro
/// precisa ser comparável ou ir para uma interface, ele é embrulhado aqui.
/// `Addr(null)` é um ponteiro nil tipado: uma interface que o contém não é
/// nil, como no Go.
final class Addr {
  const Addr(this.target);

  final Object? target;

  @override
  bool operator ==(Object other) =>
      other is Addr && identical(other.target, target);

  @override
  int get hashCode => identityHashCode(target);
}
