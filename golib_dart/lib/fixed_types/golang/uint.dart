// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'uint64.dart';
import 'src/base.dart';

/// Go uint (64 bits): tipo distinto de uint64 em runtime.
/// Cada tipo Go é uma classe distinta (type switch, assertions, reflexão);
/// a aritmética vem de [IntBase].
final class Uint extends IntBase<Uint> {
  @override
  String get $goType => 'uint';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Uint([int value = 0]) : _v = Uint64(value);

  /// Mantém os 64 bits baixos.
  Uint.fromBigInt(BigInt value) : _v = Uint64.fromBigInt(value);

  final Uint64 _v;

  @override
  BigInt toBigInt() => _v.toBigInt();

  @override
  Uint $wrap(BigInt v) => Uint.fromBigInt(v);

  /// Cópia defensiva da representação interna (não é formato de protocolo).
  Uint8List toLittleEndianBytes() => _v.toLittleEndianBytes();
}
