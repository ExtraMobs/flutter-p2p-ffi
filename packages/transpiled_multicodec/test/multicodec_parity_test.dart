// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/multicodec_parity_test.dart
//
// Parity check for the go-multicodec table
// (github.com/multiformats/go-multicodec code_table.go), extracted
// mechanically (not hand-transcribed) from that file's `Name Code = 0xNN //
// canonical-name` declarations -- see lib/src/cid/multicodec.dart's header
// comment. This test spot-checks a sample spanning the whole file (not
// every one of the 603 entries, which would just restate the source) and
// specifically covers the codes where the previous ~30-entry table here had
// drifted from the real registry.
import 'package:transpiled_multicodec/transpiled_multicodec.dart';
import 'package:test/test.dart';

void main() {
  group('Multicodec parity with go-multicodec code_table.go', () {
    test('has all 603 entries from the real table', () {
      expect(Multicodec.count, equals(603));
    });

    test('round-trip: every code -> name -> code is stable', () {
      for (final name in Multicodec.supported) {
        final code = Multicodec.code(name);
        expect(Multicodec.name(code), equals(name));
      }
    });

    test('spot-check values across the file', () {
      final expected = <String, int>{
        'identity': 0x00,
        'cidv1': 0x01,
        'ip4': 0x04,
        'sha2-256': 0x12,
        'blake3': 0x1e,
        'dns': 0x35,
        'raw': 0x55,
        'dag-pb': 0x70,
        'dag-cbor': 0x71,
        'libp2p-key': 0x72,
        'secp256k1-pub': 0xe7,
        'ed25519-pub': 0xed,
        'udp': 0x0111,
        'p2p-circuit': 0x0122,
        'p2p': 0x01a5,
        'onion3': 0x01bd,
        'quic': 0x01cc,
        'quic-v1': 0x01cd,
        'webtransport': 0x01d1,
        'certhash': 0x01d2,
        'http': 0x01e0,
        'car': 0x0202,
        'ed25519-priv': 0x1300,
        'blake2b-256': 0xb220,
        'skein1024-1024': 0xb3e0,
        'aes-gcm-256': 0x2000,
        'plaintextv2': 0x706c61,
      };
      expected.forEach((name, code) {
        expect(Multicodec.code(name), equals(code), reason: name);
        expect(Multicodec.name(code), equals(name), reason: name);
      });
    });

    test(
      '0x300 range matches the real table, not the previous drifted names',
      () {
        // The table here used to invent 'ipld-ns'/'ipfs-ns'/'ipns-ns' at
        // these codes; the real go-multicodec entries are these three.
        expect(Multicodec.name(0x300), equals('ipns-record'));
        expect(Multicodec.name(0x301), equals('libp2p-peer-record'));
        expect(Multicodec.name(0x302), equals('libp2p-relay-rsvp'));
        expect(Multicodec.supports('ipld-ns'), isFalse);
        expect(Multicodec.supports('ipfs-ns'), isFalse);
        expect(Multicodec.supports('ipns-ns'), isFalse);
      },
    );

    test('no duplicate codes or names', () {
      final names = Multicodec.supported;
      expect(names.toSet().length, equals(names.length));
      final codes = names.map(Multicodec.code).toList();
      expect(codes.toSet().length, equals(codes.length));
    });
  });
}
