// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';
import 'package:test/test.dart';

void main() {
  group('Record protobuf round-trip', () {
    test('preserves key and value with no timeReceived', () {
      final rec = Record.makePutRecord(
        Uint8List.fromList('/pk/somekey'.codeUnits),
        Uint8List.fromList('some value'.codeUnits),
      );

      final decoded = Record.fromProtobuf(rec.toProtobuf());
      expect(decoded.key, equals(rec.key));
      expect(decoded.value, equals(rec.value));
      expect(decoded.timeReceived, isNull);
    });

    test('preserves timeReceived when set', () {
      final rec = Record(
        key: Uint8List.fromList([1, 2, 3]),
        value: Uint8List.fromList([4, 5, 6]),
        timeReceived: '2024-01-01T00:00:00Z',
      );

      final decoded = Record.fromProtobuf(rec.toProtobuf());
      expect(decoded.key, equals(Uint8List.fromList([1, 2, 3])));
      expect(decoded.value, equals(Uint8List.fromList([4, 5, 6])));
      expect(decoded.timeReceived, equals('2024-01-01T00:00:00Z'));
    });
  });
}
