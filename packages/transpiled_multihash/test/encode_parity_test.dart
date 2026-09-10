// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

void main() {
  test('Go Codes supports registration beyond the JS safe integer domain', () {
    final wide = Golang.Uint64.fromBigInt(BigInt.parse('9007199254740993'));
    codes[wide] = 'custom-wide';
    try {
      final decoded = MultihashUtils.decode(encode(Uint8List(0), wide));
      expect(decoded.name, 'custom-wide');
      expect(decoded.code, wide);
    } finally {
      codes.remove(wide);
    }
  });
  test('Go EncodeName uses Names and zero value for an unknown name', () {
    final digest = Uint8List.fromList([42]);
    expect(encodeName(digest, 'not-registered'), [0, 1, 42]);
    expect(encodeName(digest, 'sha3'), [0x14, 1, 42]);
    expect(encodeName(digest, 'blake2b-8'), [0x81, 0xe4, 2, 1, 42]);
    names['test-custom'] = Golang.Uint64(0x99);
    try {
      expect(encodeName(digest, 'test-custom'), [0x99, 1, 1, 42]);
    } finally {
      names.remove('test-custom');
    }
  });
  test('Go Encode supports uint64 codes and derives length from digest', () {
    final max = Golang.Uint64.fromBigInt((BigInt.one << 64) - BigInt.one);
    final digest = Uint8List.fromList([42]);
    final bytes = encode(digest, max);
    expect(bytes, [...List.filled(9, 255), 1, 1, 42]);
    digest[0] = 0;
    expect(bytes.last, 42);
    expect(encode(Uint8List(0), Golang.Uint64()), [0, 0]);
    final decoded = DecodedMultihash(
      code: Golang.Uint64(),
      name: 'identity',
      length: 99,
      digest: digest,
    );
    expect(decoded.toBytes(), [0, 1, 0]);
  });
}
