// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

void main() {
  test('CIDv1 rejects nonminimal multiformats header varints', () {
    for (final bytes in [
      [1, 0xf0, 0, 0x12, 32, ...List.filled(32, 0)],
      [1, 0x70, 0x92, 0, 32, ...List.filled(32, 0)],
      [1, 0x70, 0x12, 0xa0, 0, ...List.filled(32, 0)],
    ]) {
      expect(
        () => Cid.fromBytes(Uint8List.fromList(bytes)),
        throwsFormatException,
      );
    }
  });
}
