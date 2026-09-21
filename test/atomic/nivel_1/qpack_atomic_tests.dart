// Atomic tests (AGENTS.md Regra 24) for packages/transpiled_qpack, the port
// of github.com/quic-go/qpack (commit
// c415cad59091662a20b7b1c4505fbb177dbda0e3). Level 1: pure/unit, no I/O.
//
// Covers every public symbol: [HeaderField] (constructor, isPseudo,
// operator ==, hashCode, toString), [Encoder] (writeField, close) and
// [Decoder] (decode). Round-trip vectors below are transcribed from
// go-ipfs-reference/qpack/{static_table.go,decoder_test.go} and
// go-ipfs-reference/golang-x-net/http2/hpack/hpack_test.go
// (TestHuffmanDecode / TestAppendHuffmanString), not invented.

import 'package:test/test.dart';
import 'package:transpiled_qpack/transpiled_qpack.dart';

List<int> _hexToBytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

void main() {
  group('HeaderField [Atomic Audit]', () {
    test('HeaderField() - value defaults to the empty string', () {
      const hf = HeaderField(name: ':authority');
      expect(hf.name, ':authority');
      expect(hf.value, '');
    });

    test('HeaderField() - stores both name and value when given', () {
      const hf = HeaderField(name: ':path', value: '/');
      expect(hf.name, ':path');
      expect(hf.value, '/');
    });

    test('isPseudo() - returns true for a name starting with a colon', () {
      expect(
        const HeaderField(name: ':method', value: 'GET').isPseudo(),
        isTrue,
      );
    });

    test('isPseudo() - returns false for a regular header name', () {
      expect(const HeaderField(name: 'content-type').isPseudo(), isFalse);
    });

    test('isPseudo() - returns false for an empty name', () {
      expect(const HeaderField(name: '').isPseudo(), isFalse);
    });

    test('operator ==() - two fields with the same name/value are equal', () {
      expect(
        const HeaderField(name: 'age', value: '0'),
        const HeaderField(name: 'age', value: '0'),
      );
    });

    test('operator ==() - a different value makes fields unequal', () {
      expect(
        const HeaderField(name: 'age', value: '0') ==
            const HeaderField(name: 'age', value: '1'),
        isFalse,
      );
    });

    test('operator ==() - a different name makes fields unequal', () {
      expect(
        const HeaderField(name: 'age', value: '0') ==
            const HeaderField(name: 'date', value: '0'),
        isFalse,
      );
    });

    test('operator ==() - is false when compared to a non-HeaderField', () {
      // ignore: unrelated_type_equality_checks
      expect(const HeaderField(name: 'age') == '0', isFalse);
    });

    test('hashCode - equal fields hash the same', () {
      expect(
        const HeaderField(name: 'age', value: '0').hashCode,
        const HeaderField(name: 'age', value: '0').hashCode,
      );
    });

    test('hashCode - is usable as a Set/Map key for deduplication', () {
      final set = {
        const HeaderField(name: 'age', value: '0'),
        const HeaderField(name: 'age', value: '0'),
        const HeaderField(name: 'age', value: '1'),
      };
      expect(set, hasLength(2));
    });

    test('toString() - includes both the name and the value', () {
      final s = const HeaderField(name: 'cookie', value: 'a=b').toString();
      expect(s, contains('cookie'));
      expect(s, contains('a=b'));
    });
  });

  group('Encoder [Atomic Audit]', () {
    test('writeField() - emits the Header Block Prefix on the first call', () {
      final bytes = Encoder().writeField(const HeaderField(name: 'date'));
      // Required Insert Count = 0, Delta Base = 0.
      expect(bytes[0], 0x00);
      expect(bytes[1], 0x00);
    });

    test('writeField() - omits the prefix on subsequent calls', () {
      final encoder = Encoder();
      encoder.writeField(const HeaderField(name: 'date'));
      final second = encoder.writeField(const HeaderField(name: 'server'));
      // No repeated 0x00 0x00 prefix bytes on the second write.
      expect(second, isNot(contains(equals(0x00))));
    });

    test('writeField() - encodes a static-table field with a matching value '
        'as a single indexed byte (plus prefix on first write)', () {
      // static_table.go index 25 is {":status","200"}; the encoderMap
      // second-level lookup for ":status"/"200" resolves to 25, not the
      // base name index 24 ({"status","103"}). 25 < 63 (the 6-bit prefix
      // limit), so appendVarInt(6, 25) is a single byte 25, then XORed
      // with the indexed-field pattern 0xc0: 25 ^ 0xc0's OR = 0xd9.
      final bytes = Encoder().writeField(
        const HeaderField(name: ':status', value: '200'),
      );
      expect(bytes, [0x00, 0x00, 0xd9]);
    });

    test('writeField() - encodes a static-table field name with a custom '
        'value as a literal-with-name-reference, not an indexed field', () {
      // "content-type" is index 44 in the static table, but "text/xml" is
      // not one of its predefined values, so this must fall back to
      // writeLiteralFieldWithNameReference instead of writeIndexedField.
      final bytes = Encoder().writeField(
        const HeaderField(name: 'content-type', value: 'text/xml'),
      );
      // Byte after the prefix: appendVarInt(4, 44) with 44 >= 15 (the
      // 4-bit prefix limit of 2^4-1=15) spills into a continuation byte,
      // then gets the 01NTxxxx pattern (T=1) XORed in (0x50). Just check
      // it is NOT the single-byte indexed-field encoding, and that the
      // literal pattern bits (0x40) are set on the first content byte.
      expect(bytes.length, greaterThan(3));
      expect(bytes[2] & 0xc0, 0x40);
    });

    test('writeField() - falls back to a literal without name reference for '
        'a name not present in the static table', () {
      final bytes = Encoder().writeField(
        const HeaderField(name: 'x-custom-header', value: 'x'),
      );
      // 001xxxxx pattern.
      expect(bytes[2] & 0xe0, 0x20);
    });

    test('close() - resets the encoder so the prefix is emitted again', () {
      final encoder = Encoder();
      final first = encoder.writeField(const HeaderField(name: 'date'));
      encoder.close();
      final afterClose = encoder.writeField(const HeaderField(name: 'date'));
      expect(afterClose, first);
    });
  });

  group('Decoder [Atomic Audit]', () {
    test('decode() - round trips fields written by Encoder', () {
      final fields = [
        const HeaderField(name: 'foo', value: 'bar'),
        const HeaderField(name: 'lorem', value: 'ipsum'),
      ];
      final encoder = Encoder();
      final out = <int>[];
      for (final f in fields) {
        out.addAll(encoder.writeField(f));
      }
      expect(const Decoder().decode(out).toList(), fields);
    });

    test('decode() - resolves indexed fields from the static table', () {
      // static_table.go entries 20 and 42:
      // 20 = {":method","POST"}, 42 = {"content-encoding","br"}.
      // decoder_test.go's `indexedField` fixture builds exactly this.
      final data = <int>[0x00, 0x00, 0x80 | 0x40 | 20, 0x80 | 0x40 | 42];
      final decoded = const Decoder().decode(data).toList();
      expect(decoded, [
        const HeaderField(name: ':method', value: 'POST'),
        const HeaderField(name: 'content-encoding', value: 'br'),
      ]);
    });

    test('decode() - decodes the canonical RFC 7541 Huffman vector for '
        '"www.example.com"', () {
      // hpack_test.go TestHuffmanDecode: "f1e3c2e5f23a6ba0ab90f4ff" ->
      // "www.example.com". Wrapped in a literal-without-name-reference
      // frame whose name is plain ASCII "x" (length 1, no Huffman, so no
      // hand-computed Huffman bytes are needed for the name).
      final value = _hexToBytes('f1e3c2e5f23a6ba0ab90f4ff');
      final frame = <int>[
        0x00, 0x00, // Header Block Prefix
        0x21, // 001 0 0001: literal w/o name ref, name not Huffman, len 1
        0x78, // 'x'
        0x80 | value.length, // Huffman flag + 7-bit length prefix
        ...value,
      ];
      final decoded = const Decoder().decode(frame).single;
      expect(decoded.name, 'x');
      expect(decoded.value, 'www.example.com');
    });

    test('decode() - throws FormatException for a non-zero Required Insert '
        'Count', () {
      // This port has no dynamic table, so this port -- like upstream --
      // rejects a non-zero Required Insert Count.
      final data = <int>[0x01, 0x00];
      expect(
        () => const Decoder().decode(data).toList(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'expected Required Insert Count to be zero',
          ),
        ),
      );
    });

    test('decode() - throws FormatException for a non-zero Delta Base', () {
      final data = <int>[0x00, 0x01];
      expect(
        () => const Decoder().decode(data).toList(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'expected Base to be zero',
          ),
        ),
      );
    });

    test(
      'decode() - throws FormatException for an unknown field type byte',
      () {
        // 0x10 is 000x0000, matching none of 1xxxxxxx / 01xxxxxx / 001xxxxx.
        final data = <int>[0x00, 0x00, 0x10];
        expect(
          () => const Decoder().decode(data).toList(),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'unexpected type byte: 0x10',
            ),
          ),
        );
      },
    );

    test('decode() - throws FormatException for an out-of-range static table '
        'index', () {
      // decoder_test.go: index 10000 does not exist (table has 99
      // entries), and Go's invalidIndexError message is reproduced
      // verbatim.
      // appendVarInt(6, 10000): 10000 >= 63, so the first byte's low 6 bits
      // are all 1 (0x3f | 0xc0 flags = 0xff), then continuation bytes for
      // 10000-63=9937: 9937 = 0x26D1 -> low7=0x51|0x80=0xd1, next=9937>>7=77
      // -> 77<128 so final byte 77=0x4d.
      final frame = <int>[0x00, 0x00, 0xff, 0xd1, 0x4d];
      expect(
        () => const Decoder().decode(frame).toList(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'invalid indexed representation index 10000',
          ),
        ),
      );
    });

    test('decode() - throws FormatException when the dynamic table flag bit '
        'is unset on an indexed field', () {
      // 0x80 sets the indexed-field pattern but not the 0x40 static-table
      // bit, meaning "reference the dynamic table" -- unsupported here.
      final data = <int>[0x00, 0x00, 0x80 | 20];
      expect(
        () => const Decoder().decode(data).toList(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'no dynamic table',
          ),
        ),
      );
    });

    test('decode() - throws FormatException on truncated input mid-field', () {
      // A literal-without-name-reference type byte with no following
      // length/name bytes at all.
      final data = <int>[0x00, 0x00, 0x20];
      expect(
        () => const Decoder().decode(data).toList(),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode() - an empty header block decodes to no fields', () {
      final data = <int>[0x00, 0x00];
      expect(const Decoder().decode(data).toList(), isEmpty);
    });
  });
}
