// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go uint8 (e byte): `int` normalizado a 8 bits sem sinal.
final class Uint8 extends Uint8Base<Uint8> {
  @override
  String get $goType => 'uint8';

  /// Converte truncando à largura, como o Go; zero por padrão.
  Uint8([int value = 0]) : super(value);

  /// Go uint8(v): trunca os bits de qualquer inteiro Go.
  Uint8.from(IntBase value) : super.from(value);

  /// Trunca o valor exato à largura.
  Uint8.fromBigInt(BigInt value) : super.fromBigInt(value);

  @override
  Uint8 $make(int v) => Uint8(v);
}
