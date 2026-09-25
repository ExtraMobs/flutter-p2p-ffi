// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go uint (64 bits): tipo distinto de uint64 em runtime; a aritmética
/// vem de [Uint64Base].
final class Uint extends Uint64Base<Uint> {
  @override
  String get $goType => 'uint';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Uint([int value = 0]) : super(value);

  /// Go uint(v): os 64 bits de qualquer inteiro Go.
  Uint.from(IntBase value) : super.from(value);

  /// Mantém os 64 bits baixos do valor exato.
  Uint.fromBigInt(BigInt value) : super.fromBigInt(value);

  const Uint._(super.$hi, super.$lo) : super.raw();

  @override
  Uint $make(int hi, int lo) => Uint._(hi, lo);
}
