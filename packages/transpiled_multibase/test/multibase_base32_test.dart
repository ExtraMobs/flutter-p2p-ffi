// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_multibase/transpiled_multibase.dart';
import 'package:multibase/multibase.dart' as mb;
import 'package:test/test.dart';

void main() {
  group('MultibaseUtils base32 (RFC 4648 §10 official test vectors)', () {
    // RFC 4648 section 10 gives these as the canonical base32 test vectors
    // (uppercase, padded, with the "BASE32" alphabet). dart_ipfs uses the
    // multibase "base32" variant: lowercase, unpadded RFC 4648 alphabet.
    const cases = <String, String>{
      '': '',
      'f': 'my',
      'fo': 'mzxq',
      'foo': 'mzxw6',
      'foob': 'mzxw6yq',
      'fooba': 'mzxw6ytb',
      'foobar': 'mzxw6ytboi',
    };

    cases.forEach((input, expected) {
      test('encodes "${input.isEmpty ? "(empty)" : input}" per RFC 4648', () {
        final bytes = Uint8List.fromList(utf8.encode(input));
        final encoded = MultibaseUtils.encode(mb.Multibase.base32, bytes);
        // Empty input still gets the 'b' multibase prefix -- there's no
        // payload, but the string still identifies its (empty) base.
        expect(encoded, equals('b$expected'));
      });

      test(
        'decodes RFC 4648 vector for "${input.isEmpty ? "(empty)" : input}" back to original bytes',
        () {
          if (expected.isEmpty) return; // nothing to decode
          final decoded = MultibaseUtils.decode('b$expected');
          expect(decoded, equals(utf8.encode(input)));
        },
      );
    });
  });

  group('MultibaseUtils base32 leading-zero-byte regression', () {
    // package:multibase's base32 codec was found to diverge from RFC 4648
    // for byte sequences with leading zero bytes (and, more broadly, most
    // inputs -- see the doc comment on MultibaseUtils for the full
    // empirical finding). These pin the specific cases that motivated the
    // fix: encoded length must reflect every input byte, not silently drop
    // leading zeros the way big-integer-based base-N conversion would.
    test('single zero byte round-trips without losing length', () {
      final bytes = Uint8List(1);
      final encoded = MultibaseUtils.encode(mb.Multibase.base32, bytes);
      // 1 byte (8 bits) needs ceil(8/5) = 2 base32 characters, unpadded.
      expect(encoded, equals('baa'));
      expect(MultibaseUtils.decode(encoded), equals(bytes));
    });

    test('all-zero 40-byte sequence round-trips exactly', () {
      final bytes = Uint8List(40);
      final encoded = MultibaseUtils.encode(mb.Multibase.base32, bytes);
      // 40 bytes = 320 bits = exactly 64 base32 characters, no partial group.
      expect(encoded.length, equals(1 + 64)); // +1 for the 'b' prefix
      expect(MultibaseUtils.decode(encoded), equals(bytes));
    });

    test('leading zero byte followed by non-zero data round-trips exactly', () {
      final bytes = Uint8List.fromList([0, 0x9b, 0x53, 0xe3, 0x22]);
      final encoded = MultibaseUtils.encode(mb.Multibase.base32, bytes);
      expect(MultibaseUtils.decode(encoded), equals(bytes));
    });

    test(
      'real-world raw-codec CIDv1 byte sequence with leading-zero digest '
      'encodes to the well-known bafkrei... family prefix',
      () {
        // version(0x01) + codec(raw=0x55) + multihash-fn(sha2-256=0x12) +
        // digest-len(0x20=32) + a 32-byte digest starting with 0x00.
        final bytes = Uint8List.fromList([
          0x01, 0x55, 0x12, 0x20,
          0x00, 0x9b, 0x53, 0xe3, 0x22, 0x2c, 0x3c, 0x1c, //
          0xd8, 0x3f, 0x3c, 0xc8, 0x78, 0x46, 0xfd, 0x36, //
          0xce, 0x7b, 0x73, 0xd1, 0x7d, 0x2e, 0x48, 0xd5, //
          0x49, 0xb1, 0x41, 0xbc, 0x52, 0x41, 0x99, 0x1a, //
        ]);
        final encoded = MultibaseUtils.encode(mb.Multibase.base32, bytes);
        expect(encoded, startsWith('bafkrei'));
        expect(MultibaseUtils.decode(encoded), equals(bytes));
      },
    );
  });
}
