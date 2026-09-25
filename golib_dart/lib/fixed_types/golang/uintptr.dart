// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'src/base.dart';
import 'src/ints.dart';

/// Go uintptr (64 bits): tipo distinto de uint64 em runtime.
final class Uintptr extends Uint64Base<Uintptr> {
  @override
  String get $goType => 'uintptr';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Uintptr([int value = 0]) : super(value);

  /// Go uintptr(v): os 64 bits de qualquer inteiro Go.
  Uintptr.from(IntBase value) : super.from(value);

  /// Mantém os 64 bits baixos do valor exato.
  Uintptr.fromBigInt(BigInt value) : super.fromBigInt(value);

  const Uintptr._(super.$hi, super.$lo) : super.raw();

  @override
  Uintptr $make(int hi, int lo) => Uintptr._(hi, lo);
}
