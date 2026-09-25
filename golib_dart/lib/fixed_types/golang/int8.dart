// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

import 'uint8.dart';

/// Go int8: `int` normalizado a 8 bits com sinal.
final class Int8 extends Int8Base<Int8> {
  @override
  String get $goType => 'int8';

  /// Converte truncando à largura, como o Go; zero por padrão.
  Int8([int value = 0]) : super(value);

  /// Go int8(v): trunca os bits de qualquer inteiro Go.
  Int8.from(IntBase value) : super.from(value);

  /// Trunca o valor exato à largura.
  Int8.fromBigInt(BigInt value) : super.fromBigInt(value);

  /// Go int8(uint8Value), preservando o padrão de bits.
  Int8.fromUint8(Uint8 value) : super(value.$v);

  /// Go uint8(int8Value), preservando o padrão de bits.
  Uint8 toUint8() => Uint8($v);

  @override
  Int8 $make(int v) => Int8(v);
}
