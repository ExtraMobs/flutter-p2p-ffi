import 'package:test/test.dart';
import 'package:transpiled_qpack/transpiled_qpack.dart';

void main() {
  group('Encoder/Decoder round trip', () {
    test('encodes and decodes a mix of static-table and literal fields', () {
      final fields = [
        const HeaderField(name: 'foo', value: 'bar'),
        const HeaderField(name: 'lorem', value: 'ipsum'),
        const HeaderField(name: ':status', value: '200'),
        const HeaderField(name: ':method', value: 'GET'),
        const HeaderField(name: 'content-type', value: 'application/json'),
      ];
      final encoder = Encoder();
      final out = <int>[];
      for (final f in fields) {
        out.addAll(encoder.writeField(f));
      }
      final decoded = const Decoder().decode(out).toList();
      expect(decoded, fields);
    });

    test(':status 200 is encoded as static table index 25, not 24', () {
      // static_table.go: index 24 is {":status","103"}; index 25 is
      // {":status","200"}. The 6-bit-prefix indexed-field encoding of 25
      // is a single byte: appendVarInt(6,25) = 25 (since 25 < 63), then
      // XORed with 0xc0 (the "1Txxxxxx" indexed-field pattern) = 0xd9.
      final encoder = Encoder();
      final bytes = encoder.writeField(
        const HeaderField(name: ':status', value: '200'),
      );
      // First two bytes are the Header Block Prefix (Required Insert
      // Count = 0, Delta Base = 0).
      expect(bytes.sublist(0, 2), [0x00, 0x00]);
      expect(bytes[2], 0xd9);
    });

    test('header block prefix is 0x00 0x00 for an empty/zero base', () {
      final encoder = Encoder();
      final bytes = encoder.writeField(const HeaderField(name: 'date'));
      expect(bytes[0], 0x00);
      expect(bytes[1], 0x00);
    });

    test('close() resets the prefix so it is written again', () {
      final encoder = Encoder();
      final first = encoder.writeField(const HeaderField(name: 'date'));
      final second = encoder.writeField(const HeaderField(name: 'date'));
      encoder.close();
      final third = encoder.writeField(const HeaderField(name: 'date'));
      expect(first.length, greaterThan(second.length));
      expect(third.length, first.length);
    });
  });

  group('Huffman codec (RFC 7541 Appendix / hpack_test.go vectors)', () {
    // These are the canonical vectors from
    // golang-x-net/http2/hpack/hpack_test.go TestHuffmanDecode /
    // TestAppendHuffmanString.
    const vectors = {
      'f1e3c2e5f23a6ba0ab90f4ff': 'www.example.com',
      'a8eb10649cbf': 'no-cache',
      '25a849e95ba97d7f': 'custom-key',
      '25a849e95bb8e8b4bf': 'custom-value',
      '6402': '302',
      'aec3771a4b': 'private',
      'd07abe941054d444a8200595040b8166e082a62d1bff':
          'Mon, 21 Oct 2013 20:13:21 GMT',
      '9d29ad171863c78f0b97c8e9ae82ae43d3': 'https://www.example.com',
      '9bd9ab': 'gzip',
      '94e7821dd7f2e6c7b335dfdfcd5b3960d5af27087f3672c1ab270fb5291f958731606'
              '5c003ed4ee5b1063d5007':
          'foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1',
    };

    List<int> hexToBytes(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];

    for (final entry in vectors.entries) {
      test('round trips through the static table encoder/decoder: '
          '${entry.value}', () {
        // Force Huffman-without-name-reference encoding by using a header
        // name that is not in the static table.
        final encoder = Encoder();
        final bytes = encoder.writeField(
          HeaderField(name: 'x-huffman-test', value: entry.value),
        );
        final decoded = const Decoder().decode(bytes).single;
        expect(decoded.value, entry.value);
      });

      test(
        'decodes the known-good Huffman byte vector for: ${entry.value}',
        () {
          // Hand-builds a "Literal Header Field Without Name Reference"
          // (001NHxxx) frame whose NAME is plain ASCII "x" (no Huffman, so no
          // hand-computed Huffman bytes are needed for it) and whose VALUE is
          // exactly the known-good Huffman byte vector from
          // golang-x-net/http2/hpack/hpack_test.go. This exercises the actual
          // `_huffmanCodes`/`_huffmanCodeLen` tables against ground truth,
          // not just self-consistency between this port's own encoder and
          // decoder.
          final huffmanValueBytes = hexToBytes(entry.key);
          expect(
            huffmanValueBytes.length,
            lessThan(127),
            reason: 'test assumes a single-byte 7-bit varint length prefix',
          );
          final frame = <int>[
            0x00, 0x00, // Header Block Prefix: Required Insert Count/Base = 0
            0x21, // 001 0 0001: literal w/o name ref, name not Huffman, len 1
            0x78, // 'x'
            0x80 | huffmanValueBytes.length, // value: Huffman flag + length
            ...huffmanValueBytes,
          ];
          final decoded = const Decoder().decode(frame).single;
          expect(decoded.name, 'x');
          expect(decoded.value, entry.value);
        },
      );
    }
  });
}
