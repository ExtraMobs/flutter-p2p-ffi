// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'int64.dart';
import 'src/base.dart';

/// Go int (64 bits): tipo distinto de int64 em runtime.
/// Cada tipo Go é uma classe distinta (type switch, assertions, reflexão);
/// a aritmética vem de [IntBase].
final class Int extends IntBase<Int> {
  @override
  String get $goType => 'int';

  /// Converte mantendo os 64 bits baixos; zero por padrão.
  Int([int value = 0]) : _v = Int64(value);

  /// Mantém os 64 bits baixos.
  Int.fromBigInt(BigInt value) : _v = Int64.fromBigInt(value);

  final Int64 _v;

  @override
  BigInt toBigInt() => _v.toBigInt();

  @override
  Int $wrap(BigInt v) => Int.fromBigInt(v);

  /// Cópia defensiva da representação interna (não é formato de protocolo).
  Uint8List toLittleEndianBytes() => _v.toLittleEndianBytes();
}
