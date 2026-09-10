// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p-record's own validator_test.go
// (go-ipfs-reference/go-libp2p-record/validator_test.go, TestSplitPath).
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';
import 'package:test/test.dart';

const _badPaths = [
  'foo/bar/baz',
  '//foo/bar/baz',
  '/ns',
  'ns',
  'ns/',
  '',
  '//',
  '/',
  '////',
];

void main() {
  group('splitKey', () {
    test('splits a three-segment path', () {
      final (ns, key) = splitKey('/foo/bar/baz');
      expect(ns, equals('foo'));
      expect(key, equals('bar/baz'));
    });

    test('splits a two-segment path', () {
      final (ns, key) = splitKey('/foo/bar');
      expect(ns, equals('foo'));
      expect(key, equals('bar'));
    });

    for (final badPath in _badPaths) {
      test('rejects bad path "$badPath"', () {
        expect(
          () => splitKey(badPath),
          throwsA(isA<InvalidRecordTypeException>()),
        );
      });
    }
  });
}
