// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go int (64 bits): tipo distinto de int64 em runtime (type switch,
/// assertions, reflexão); a aritmética vem de [Int64Base].
final class Int extends Int64Base<Int> {
  @override
  String get $goType => 'int';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Int([int value = 0]) : super(value);

  /// Go int(v): os 64 bits de qualquer inteiro Go.
  Int.from(IntBase value) : super.from(value);

  /// Mantém os 64 bits baixos do valor exato.
  Int.fromBigInt(BigInt value) : super.fromBigInt(value);

  const Int._(super.$hi, super.$lo) : super.raw();

  @override
  Int $make(int hi, int lo) => Int._(hi, lo);
}
