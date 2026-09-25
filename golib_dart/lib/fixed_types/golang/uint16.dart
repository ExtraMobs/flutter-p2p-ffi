// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go uint16: `int` normalizado a 16 bits sem sinal.
final class Uint16 extends Uint16Base<Uint16> {
  @override
  String get $goType => 'uint16';

  /// Converte truncando à largura, como o Go; zero por padrão.
  Uint16([int value = 0]) : super(value);

  /// Go uint16(v): trunca os bits de qualquer inteiro Go.
  Uint16.from(IntBase value) : super.from(value);

  /// Trunca o valor exato à largura.
  Uint16.fromBigInt(BigInt value) : super.fromBigInt(value);

  @override
  Uint16 $make(int v) => Uint16(v);
}
