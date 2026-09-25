// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go uint64: duas palavras de 32 bits sem sinal; conversão trunca
/// módulo 2^64, como no Go.
final class Uint64 extends Uint64Base<Uint64> {
  @override
  String get $goType => 'uint64';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Uint64([int value = 0]) : super(value);

  /// Go uint64(v): os 64 bits de qualquer inteiro Go.
  Uint64.from(IntBase value) : super.from(value);

  /// Mantém os 64 bits baixos do valor exato.
  Uint64.fromBigInt(BigInt value) : super.fromBigInt(value);

  const Uint64._(super.$hi, super.$lo) : super.raw();

  @override
  Uint64 $make(int hi, int lo) => Uint64._(hi, lo);
}
