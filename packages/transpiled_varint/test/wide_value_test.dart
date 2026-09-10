// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

void main() {
  test('FromUvarint preserves bit 32 on every runtime', () {
    final (value, count) = fromUvarint(
      Uint8List.fromList([0x80, 0x80, 0x80, 0x80, 0x10]),
    );
    expect(value.toBigInt(), BigInt.from(4294967296));
    expect(count, 5);
  });
}
