/// Operando com o nome Go do tipo estático.
library;

/// Um operando de `fmt.Printf("%#v", x)` cujo tipo estático não deixa rastro
/// no valor Dart (slice/map/array sem nome: `[]int`, `map[string]int`): o g2d
/// o embrulha com o nome Go do tipo; o fmt desembrulha. [under] é o nome do
/// subjacente quando o tipo tem nome (`type IDs []string`: [name] `main.IDs`,
/// [under] `[]string`), de onde saem os nomes dos elementos.
final class TypeTag {
  const TypeTag(this.value, this.name, [this.under]);

  final Object? value;
  final String name;
  final String? under;
}

/// `reflect.Value` visto pelo fmt: o Go imprime o valor que ele guarda
/// (`<invalid reflect.Value>` se inválido), não a struct.
abstract interface class FmtReflectValue {
  bool get $valid;
  Object? get $fmtArg;
}
