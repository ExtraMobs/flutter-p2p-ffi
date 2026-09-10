// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

void main() {
  test(
    'prefix reconstruction honors hash, truncation, version and identity',
    () async {
      final data = Uint8List.fromList([42, 43]);
      final truncated = await Cid.fromPrefixBytes(
        Uint8List.fromList([1, 0x55, 0x12, 20]),
        data,
      );
      expect(truncated.multihash.length, 20);
      final identity = await Cid.fromPrefixBytes(
        Uint8List.fromList([1, 0x55, 0, 0]),
        data,
      );
      expect(identity.multihash.digest, data);
      final v0 = await Cid.fromPrefixBytes(
        Uint8List.fromList([0, 0x70, 0x12, 32]),
        data,
      );
      expect(v0.version, 0);
      await expectLater(
        Cid.fromPrefixBytes(Uint8List(0), data),
        throwsFormatException,
      );
      await expectLater(
        Cid.fromPrefixBytes(Uint8List.fromList([2, 0x55, 0x12, 32]), data),
        throwsFormatException,
      );
      await expectLater(
        Cid.fromPrefixBytes(Uint8List.fromList([0, 0x70, 0, 32]), data),
        throwsFormatException,
      );
    },
  );
  test('unknown wide codecs survive bytes, identity and prefix', () {
    final wide = Golang.Uint64.fromBigInt(BigInt.parse('9007199254740993'));
    final bytes = Uint8List.fromList([1, ...toUvarint(wide), 0, 1, 42]);
    final cid = Cid.fromBytes(bytes);
    expect(cid.codec, 'unknown');
    expect(cid.codecCode, wide);
    expect(cid.toBytes(), bytes);
    final same = Cid.fromBytes(bytes);
    expect(same, cid);
    expect(same.hashCode, cid.hashCode);
    final other = Cid.fromBytes(
      Uint8List.fromList([1, ...toUvarint(wide + Golang.Uint64(1)), 0, 1, 42]),
    );
    expect(other, isNot(cid));
    final prefix = Prefix.fromBytes(cid.toPrefixBytes());
    expect(prefix, cid.prefix);
    expect(prefix.codecCode, wide);
    expect(prefix.mhTypeCode, Golang.Uint64());
    expect(prefix.sum(Uint8List.fromList([42])), cid);
  });
}
