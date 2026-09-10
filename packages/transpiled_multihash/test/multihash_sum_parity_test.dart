// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/multihash_sum_parity_test.dart
//
// Parity vectors for MultihashUtils.sum(), taken verbatim from go-multihash's
// own sum_test.go (github.com/multiformats/go-multihash), at
// go-ipfs-reference/go-multihash/sum_test.go. Each expected hex string is the
// full multihash (varint code + varint length + digest) that
// `multihash.Sum(data, code, -1)` produces in Go -- proving byte-identical
// behavior, not just "compiles and doesn't throw".
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('MultihashUtils.sum parity with go-multihash', () {
    final cases = <(String name, String input, String expectedHex)>[
      ('identity', 'foo', '0003666f6f'),
      ('sha1', 'foo', '11140beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33'),
      (
        'sha2-256',
        'foo',
        '12202c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      ),
      (
        'sha2-512',
        'foo',
        '1340f7fbba6e0636f890e56fbbf3283e524c6fa3204ae298382d624741d0dc6638326e282c41be5e4254d8820772c5518a2c5a8c0c7f7eda19594a7eb539453e1ed7',
      ),
      (
        'sha3-512',
        'foo',
        '14404bca2b137edc580fe50a88983ef860ebaca36c857b1f492839d6d7392452a63c82cbebc68e3b70a2a1480b4bb5d437a7cba6ecf9d89f9ff3ccd14cd6146ea7e7',
      ),
      (
        'sha3-224',
        'beep boop',
        '171c0da73a89549018df311c0a63250e008f7be357f93ba4e582aaea32b8',
      ),
      (
        'sha3-256',
        'beep boop',
        '1620828705da60284b39de02e3599d1f39e6c1df001f5dbf63c9ec2d2c91a95a427f',
      ),
      (
        'sha3-384',
        'beep boop',
        '153075a9cff1bcfbe8a7025aa225dd558fb002769d4bf3b67d2aaf180459172208bea989804aefccf060b583e629e5f41e8d',
      ),
      (
        'dbl-sha2-256',
        'foo',
        '5620c7ade88fc7a21498a6a5e5c385e1f68bed822b72aa63c4a9a48a02c2466ee29e',
      ),
      (
        'keccak-256',
        'foo',
        '1b2041b1a0649752af1b28b3dc29a1556eee781e4a4c3a1f7f53f90fa834de098c4d',
      ),
      (
        'keccak-512',
        'beep boop',
        '1d40e161c54798f78eba3404ac5e7e12d27555b7b810e7fd0db3f25ffa0c785c438331b0fbb6156215f69edf403c642e5280f4521da9bd767296ec81f05100852e78',
      ),
      ('md5', 'foo', 'd50110acbd18db4cc2f85cedef654fccc4a4d8'),
    ];

    for (final (name, input, expectedHex) in cases) {
      test(name, () {
        final mh = MultihashUtils.sum(name, Uint8List.fromList(utf8.encode(input)));
        expect(_hex(mh.toBytes()), equals(expectedHex));
      });
    }

    test('unsupported algorithm throws', () {
      expect(
        () => MultihashUtils.sum('blake3', Uint8List(0)),
        throwsUnsupportedError,
      );
    });
  });
}
