// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/cid_prefix_test.dart
//
// Parity with go-cid's TestNewPrefixV1/TestNewPrefixV0
// (go-ipfs-reference/go-cid/cid_test.go): build a Prefix, Sum() it against
// data, and confirm the result matches a Cid built the "manual" way, and
// that round-tripping a Cid's own .prefix reproduces the same Prefix.
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

void main() {
  group('Prefix', () {
    final data = Uint8List.fromList(utf8.encode('this is some test content'));

    test('v1 prefix.sum matches a manually-built Cid', () {
      final prefix = Prefix(
        version: 1,
        codec: 'dag-cbor',
        mhType: 'sha2-256',
        mhLength: 32,
      );
      final c1 = prefix.sum(data);
      final c2 = Cid.v1('dag-cbor', MultihashUtils.sum('sha2-256', data));

      expect(c1, equals(c2));
      expect(c1.prefix, equals(prefix));
      expect(c1.prefix, equals(c2.prefix));
    });

    test('v0 prefix.sum matches a manually-built Cid', () {
      final prefix = Prefix(
        version: 0,
        codec: 'dag-pb',
        mhType: 'sha2-256',
        mhLength: 32,
      );
      final c1 = prefix.sum(data);
      final mh = MultihashUtils.sum('sha2-256', data);
      final c2 = Cid.v0(Uint8List.fromList(mh.digest));

      expect(c1, equals(c2));
      expect(c1.prefix, equals(prefix));
      expect(c1.prefix, equals(c2.prefix));
    });

    test('prefix equality is structural, not identity', () {
      final a = Prefix(
        version: 1,
        codec: 'raw',
        mhType: 'sha2-256',
        mhLength: 32,
      );
      final b = Prefix(
        version: 1,
        codec: 'raw',
        mhType: 'sha2-256',
        mhLength: 32,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('decodes Bitswap prefix bytes and honors digest truncation', () {
      final prefix = Prefix.fromBytes(Uint8List.fromList([1, 0x55, 0x12, 20]));
      final cid = prefix.sum(data);

      expect(
        prefix,
        Prefix(
          version: 1,
          codec: 'raw',
          mhType: 'sha2-256',
          mhLength: 20,
        ),
      );
      expect(cid.multihash.size, 20);
    });
  });
}
