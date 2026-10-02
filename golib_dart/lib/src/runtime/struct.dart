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

  /// Method set de T (valor) e de *T (nomes Go ordenados). No Dart a
  /// classe é a mesma para T e *T (e declara as interfaces dos dois), então
  /// quem testa uma interface sobre um valor ([$isValue]) confere também
  /// [$methods] (`go.isIface`).
  List<String> get $valueMethods => const [];
  List<String> get $ptrMethods => const [];

  @override
  List<String> get $methods => $isValue ? $valueMethods : $ptrMethods;

  /// Cópia de valor (aninhados copiados; ponteiros, slices, maps
  /// compartilhados, como no Go).
  T $copy();

  /// `x = other` do Go: copia o conteúdo de [other] para este objeto.
  void $set(T other);

  /// Cópia para guardar o valor numa interface.
  T $ifaceCopy() => $copy()..$isValue = true;

  /// X é exatamente `T?` (a classe deste valor)? Distingue, num alvo
  /// `*S` do `errors.As`, "ponteiro para esta struct" (não aceita um S por
  /// valor) de "interface que S implementa". Genéricos reificados: vale em
  /// VM, JS e Wasm.
  bool $classIs<X>() => <T?>[] is List<X> && <X>[] is List<T?>;
}

/// Base de toda struct Go gerada pelo g2d.
///
/// `==` compara campo a campo sobre [$fields] (campos ponteiro vêm como
/// [Addr], comparados por identidade).
abstract class GoStruct<T extends GoStruct<T>> extends GoValue<T> {
  /// Campos em ordem de declaração (ponteiros embrulhados em [Addr]).
  List<Object?> get $fields;

  /// Nomes Go dos campos de [$fields] (`%+v`; embutido = nome do tipo).
  List<String> get $fieldNames;

  /// Nomes Go dos tipos dos campos de [$fields], para o `%#v` (`[]int`,
  /// `*main.P`, `error`): o valor Dart de um campo slice/map/ponteiro/
  /// interface não diz o próprio tipo Go. Vazio: o g2d não precisou (campos
  /// só de básicos e structs).
  List<String> get $fieldTypes => const [];

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

/// Structs do runtime que não são [GoStruct] (os erros concretos de
/// `errors`/`fmt`, comparados por identidade como o ponteiro do Go), mas
/// que o `%#v` imprime campo a campo: `&errors.errorString{s:"x"}`.
abstract interface class GoOpaqueStruct implements GoTyped {
  /// Campos em ordem de declaração do Go.
  List<Object?> get $fields;

  /// Nomes Go dos campos.
  List<String> get $fieldNames;

  /// Nomes Go dos tipos dos campos (ver [GoStruct.$fieldTypes]).
  List<String> get $fieldTypes;
}

/// `struct{}`: a struct vazia é o mesmo tipo em qualquer pacote Go, então tem
/// uma classe só no runtime (as outras structs anônimas ainda são uma classe
/// por library, `TODO/P1-design-anonimas-canonicas.md`). Canais `chan
/// struct{}` (ex. `context.Context.Done()`) atravessam pacotes e shims.
final class EmptyStruct extends GoStruct<EmptyStruct> {
  EmptyStruct();

  /// `(*struct{})(nil)` dentro de uma interface (não é nil no Go).
  static final EmptyStruct $nil = EmptyStruct()..$nilPtr = true;

  @override
  String get $goType => 'struct {}';

  @override
  EmptyStruct $copy() => EmptyStruct();

  @override
  void $set(EmptyStruct o) {}

  @override
  List<Object?> get $fields => const [];

  @override
  List<String> get $fieldNames => const [];
}
