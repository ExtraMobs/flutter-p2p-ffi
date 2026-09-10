// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

void main() {
  test('public Decode and Cast preserve the Go slice contract', () {
    final bytes = Uint8List.fromList([0, 1, 42]);
    final value = decode(bytes);
    expect(identical(cast(bytes), bytes), isTrue);
    bytes[2] = 43;
    expect(value.digest, [43]);
    expect(() => cast(Uint8List.fromList([0, 0, 99])), throwsFormatException);
  });
  test('MHFromBytes preserves uint63 code without a native int boundary', () {
    final bytes = Uint8List.fromList([...List.filled(8, 255), 127, 0, 99]);
    final (count, hash) = mhFromBytes(bytes);
    expect(count, 10);
    expect(hash, bytes.sublist(0, 10));
    final decoded = MultihashUtils.decode(hash);
    expect(decoded.code.toBigInt(), (BigInt.one << 63) - BigInt.one);
    expect(decoded.toBytes(), hash);
  });
  test('MHFromBytes consumes one multihash and preserves slice aliasing', () {
    final bytes = Uint8List.fromList([0, 1, 42, 99]);
    final (count, hash) = mhFromBytes(bytes);
    expect(count, 3);
    expect(hash, [0, 1, 42]);
    bytes[2] = 43;
    expect(hash, [0, 1, 43]);
    expect(() => MultihashUtils.decode(bytes), throwsFormatException);
  });
  test('Go Decode accepts zero digest and unknown codes', () {
    final empty = MultihashUtils.decode(Uint8List.fromList([0, 0]));
    expect(empty.name, 'identity');
    expect(empty.digest, isEmpty);
    final input = Uint8List.fromList([0x99, 1, 1, 0xaa]);
    final unknown = MultihashUtils.decode(input);
    expect(unknown.code.toBigInt(), BigInt.from(0x99));
    expect(unknown.name, '');
    expect(unknown.toBytes(), input);
    input[3] = 0xbb;
    expect(unknown.digest, [0xbb]);
  });

  test(
    'Go Decode rejects truncation, nonminimal varints and trailing data',
    () {
      for (final bytes in <List<int>>[
        [],
        [0],
        [0, 1],
        [0, 0, 1],
        [0x80, 0, 0],
        [0, 0x80, 0],
        [0, 0x80, 0x80, 0x80, 0x80, 8],
      ]) {
        expect(
          () => MultihashUtils.decode(Uint8List.fromList(bytes)),
          throwsFormatException,
          reason: '$bytes',
        );
      }
    },
  );
}
