// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

import 'uint16.dart';

/// Go int16: `int` normalizado a 16 bits com sinal.
final class Int16 extends Int16Base<Int16> {
  @override
  String get $goType => 'int16';

  /// Converte truncando à largura, como o Go; zero por padrão.
  Int16([int value = 0]) : super(value);

  /// Go int16(v): trunca os bits de qualquer inteiro Go.
  Int16.from(IntBase value) : super.from(value);

  /// Trunca o valor exato à largura.
  Int16.fromBigInt(BigInt value) : super.fromBigInt(value);

  /// Go int16(uint16Value), preservando o padrão de bits.
  Int16.fromUint16(Uint16 value) : super(value.$v);

  /// Go uint16(int16Value), preservando o padrão de bits.
  Uint16 toUint16() => Uint16($v);

  @override
  Int16 $make(int v) => Int16(v);
}
