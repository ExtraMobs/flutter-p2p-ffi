// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

import 'uint32.dart';

/// Go int32 (e rune): `int` normalizado a 32 bits com sinal.
final class Int32 extends Int32Base<Int32> {
  @override
  String get $goType => 'int32';

  /// Converte truncando à largura, como o Go; zero por padrão.
  Int32([int value = 0]) : super(value);

  /// Go int32(v): trunca os bits de qualquer inteiro Go.
  Int32.from(IntBase value) : super.from(value);

  /// Trunca o valor exato à largura.
  Int32.fromBigInt(BigInt value) : super.fromBigInt(value);

  /// Go int32(uint32Value), preservando o padrão de bits.
  Int32.fromUint32(Uint32 value) : super(value.$v);

  /// Go uint32(int32Value), preservando o padrão de bits.
  Uint32 toUint32() => Uint32($v);

  @override
  Int32 $make(int v) => Int32(v);
}
