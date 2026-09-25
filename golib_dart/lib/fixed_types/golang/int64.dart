// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

import 'uint64.dart';

/// Go int64: duas palavras de 32 bits em complemento de dois.
final class Int64 extends Int64Base<Int64> {
  @override
  String get $goType => 'int64';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Int64([int value = 0]) : super(value);

  /// Go int64(v): os 64 bits de qualquer inteiro Go.
  Int64.from(IntBase value) : super.from(value);

  /// Mantém os 64 bits baixos do valor exato.
  Int64.fromBigInt(BigInt value) : super.fromBigInt(value);

  const Int64._(super.$hi, super.$lo) : super.raw();

  /// Go int64(uint64Value), preservando o padrão de bits.
  Int64.fromUint64(Uint64 value) : super.raw(value.$hi, value.$lo);

  /// Go uint64(int64Value), preservando o padrão de bits.
  Uint64 toUint64() => Uint64.from(this);

  /// Fronteira explícita com o Dart, não uma conversão Go: lança quando o
  /// int da plataforma não representa o valor exatamente.
  int toIntExact() {
    final result = toInt();
    if (BigInt.from(result) != toBigInt()) {
      throw UnsupportedError('Dart int cannot represent this Int64 exactly');
    }
    return result;
  }

  @override
  Int64 $make(int hi, int lo) => Int64._(hi, lo);
}
