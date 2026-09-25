// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go uint32: `int` normalizado a 32 bits sem sinal.
final class Uint32 extends Uint32Base<Uint32> {
  @override
  String get $goType => 'uint32';

  /// Converte truncando à largura, como o Go; zero por padrão.
  Uint32([int value = 0]) : super(value);

  /// Go uint32(v): trunca os bits de qualquer inteiro Go.
  Uint32.from(IntBase value) : super.from(value);

  /// Trunca o valor exato à largura.
  Uint32.fromBigInt(BigInt value) : super.fromBigInt(value);

  @override
  Uint32 $make(int v) => Uint32(v);
}
