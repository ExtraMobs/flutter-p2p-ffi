// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_boxo/transpiled_boxo.dart';

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

void main() {
  test('accepts Data before or after a contiguous Links section', () {
    final hash = [0x12, 0x20, ...List.filled(32, 0)];
    final link = [0x12, 36, 0x0a, 34, ...hash];
    for (final bytes in [
      [...link, 0x0a, 0],
      [0x0a, 0, ...link],
    ]) {
      expect(
        DagPbNode.fromBytes(Uint8List.fromList(bytes)).links,
        hasLength(1),
      );
    }
    expect(
      () =>
          DagPbNode.fromBytes(Uint8List.fromList([...link, 0x0a, 0, ...link])),
      throwsA(isA<Exception>()),
    );
  });

  // Locked Boxo DecodeProtobuf -> go-codec-dagpb v1.7.0 DecodeBytes.
  test('accepts empty nodes and optional Data from Go vectors', () {
    for (final encoded in ['', '0a00', '0a0101']) {
      expect(DagPbNode.fromBytes(_hex(encoded)).links, isEmpty);
    }
  });

  test('rejects malformed DAG-PB accepted by generic protobuf', () {
    for (final encoded in [
      '0a000a00', // duplicate Data
      '1a00', // unknown node field
      '1200', // missing Hash
      '12021800', // Tsize without Hash
      '12020a00', // empty Cid
    ]) {
      expect(
        () => DagPbNode.fromBytes(_hex(encoded)),
        throwsA(isA<Exception>()),
        reason: 'Boxo rejects $encoded',
      );
    }
  });
}
