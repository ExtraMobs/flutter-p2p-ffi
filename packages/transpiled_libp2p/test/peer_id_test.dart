// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:test/test.dart';

// Real go-libp2p core/peer test vector (core/peer/peer_test.go's `man`
// keyset): a base64-encoded, crypto.pb-wrapped RSA private key, and the
// base58 peer ID it's known to produce (`hpkpMan`).
const _manPeerIdBase58 = 'QmcJeseojbPW9hSejUM1sQ1a2QmbrryPK4Z8pWbRUPaYEn';
const _manPrivateKeyBase64 =
    'CAASqAkwggSkAgEAAoIBAQC3hjPtPli71gFNzGJ6rUhYdb65BDwW7IrniEaZKi6z'
    'tW4Iz0MouEJY8GPG1iQfqZKp5w9H2ENh4I1bk2dsezrJ7Nneg4Eqd78CmeHTAgaP'
    '3PKsxohdMo/TOFNxwl8SkEF8FyVbio2TCoijYNHUuprZuq7MPEAJYr3Z1eEkM/xR'
    'pMp3YI9S2SYsZQxbmmQ0/GfHOEvYajdow1qttreVTQkvmCppKtNLEU5InpX/W5fe'
    'aQCj0pd7l74daZgM2WWz3juEUCVG7tdRUPg7ix1TYosbN96CKC3q2MJxe/wJ9gR5'
    'Jvjnaaaoon+mci5vrKzxdKBDmZ/ZbLiHDfVljMkbdOQLAgMBAAECggEAEULaF3JJ'
    'vkD+lmamzIsHxuosKhKv5CgTWHuEyFsjUVu7IbD8zBOoidzyRX1WoHO+i6Rj14oL'
    'rGUGZpqSm61rdhqE01zjBS+GE6SNjN8f5uANIxr5MGrVBDTEBGsXrhNLVXSH2vhJ'
    'II9ZEqTEl5GFhvz7+9Ge5EMZQCfRqSoKjVMdrs+Rueuusr9p0wNg9PH1myA+cXGt'
    'iNZA17Rj2IiWVZLDgYNo4DVQUt4mFb+wTJW4NSspGKaFebpn0hf4z21laoGoJqTC'
    'cNETJw+QwQ0uDaRoYotTLT2/55e8XBFTdcTg5cmbZoKgMyGqZEHfRyD9reVDAZlM'
    'EZwKtrm41kz94QKBgQDmPp5zVtFXQNONmje1NE0IjCaUKcqURXk4ZiILztfT9XLC'
    'OXAUCs3TCq21jirCkZZ6gLfo12Wx0xJYmsKlaUOGNTa8FI5Xa7OyheYKixUvV6FW'
    'J95P/sNuWscTjh7oZHgZk/L3yKrNzNBz7awComwV6qciXW7EP1uACHf5fS/RdQKB'
    'gQDMDa38W9OeegRDrhCeYGsniJK7btOCzhNooruQKPPXxk+O4dyJm7VBbC/3Ch55'
    'a83W66T4k0Q7ysLVRT5Vqd5z3AM0sEM3ZoxUKCinG3NwPxVeXcoLasyEiq1vOFK6'
    'GqZKCMThCj7ZpbkWy0DPJagnYfZGC62lammuj+XQx7mvfwKBgQCTKhka/bXmgD/3'
    '9UeAIcLPIM2TzDZ4mQNHIjjGtVnMV8kXDaFung06xEuNjSYVoPq+qEFkqTCN/axv'
    'R9P76BFJ2f93LehhRizggacsvAM5dFhh+i+lj+AYTBuMiz2EKpt9NcyJxhAuZKgk'
    'QRi9wlU1mPtlArVG6HwylLcil3qV9QKBgQDJHtaU/KEY+2TGnIMuxxP2lEsjyLla'
    'nOlOYc8C6Qpma8UwrHelfj5p7Eteb6/Xt6Tbp8kjZGuFj3T3plcpMdPbWEgkn3Kw'
    '4TeBH0/qXUkrolHagBDLrglEvjbxf48ydV/fasM6l9GYzhofWFhZk+EoaArHwWz2'
    'tGrTrmsynBjt2wKBgErdYe+zZ2Wo+wXQGAoZi4pfcwiw4a97Kdh0dx+WZz7acHms'
    'h+V20VRmEHm5h8WnJ/Wv5uK94t6NY17wzjQ7y2BN5mY5cA2cZAcpeqtv/N06tH4S'
    'cn1UEuRB8VpwkjaPUNZhqtYK40qff2OTdJy8taFtQiN7fz9euWTC78zjph2s';

void main() {
  group('PeerId base36', () {
    test('toBase36 returns multibase-prefixed string', () {
      final pid = PeerId(value: Uint8List.fromList([0, 1, 2, 3, 255]));
      final encoded = pid.toBase36();
      expect(encoded.startsWith('k'), isTrue);
      expect(encoded.length, greaterThan(1));
    });

    test('fromBase36 round-trips', () {
      final original = PeerId(value: Uint8List.fromList([0xAB, 0xCD, 0xEF]));
      final encoded = original.toBase36();
      final decoded = PeerId.fromBase36(encoded);
      expect(decoded.value, orderedEquals(original.value));
    });

    test('fromBase36 accepts bare string without k prefix', () {
      final original = PeerId(value: Uint8List.fromList([0x01, 0x02]));
      final bare = original.toBase36().substring(1);
      final decoded = PeerId.fromBase36(bare);
      expect(decoded.value, orderedEquals(original.value));
    });

    test('fromBase36 rejects invalid characters', () {
      expect(() => PeerId.fromBase36('k!'), throwsArgumentError);
    });

    test('fromPublicKey Ed25519 derives deterministic PeerId', () {
      final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
      final pid1 = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
      final pid2 = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
      expect(pid1, equals(pid2));
      // go-libp2p core/peer's IDFromPublicKey: the protobuf-marshaled
      // PublicKey{Type: Ed25519, Data: <32 bytes>} is 36 bytes, at or
      // under maxInlineKeyLength (42) -- so this is an `identity`
      // multihash (varint code 0x00 + varint length 36 + the 36 bytes),
      // not a bare 32-byte digest.
      expect(pid1.value[0], equals(0x00)); // identity multihash code
      expect(pid1.value[1], equals(36)); // marshaled PublicKey length
      expect(pid1.value.length, equals(38));
    });

    test('fromPublicKey inlines an Ed25519 key as its marshaled protobuf bytes', () {
      final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
      final pid = PeerId.fromPublicKey(publicKey, type: 'Ed25519');
      // varint(0x00) + varint(36) + protobuf PublicKey{Type:1(Ed25519),
      // Data:<32 bytes>}: field tags 0x08 0x01 (Type) and 0x12 0x20 (Data,
      // length 32) framing the raw key.
      final expected = Uint8List.fromList([
        0x00, 36, // multihash: identity, length 36
        0x08, 0x01, // PublicKey.Type = Ed25519 (1)
        0x12, 32, // PublicKey.Data, length 32
        ...publicKey,
      ]);
      expect(pid.value, orderedEquals(expected));
    });

    test('fromPublicKey RSA-sized keys hash instead of inlining', () {
      // A 270-byte "key" (typical marshaled size for a 2048-bit RSA key)
      // is well over maxInlineKeyLength, so this must hash rather than
      // inline -- the multihash code byte must be sha2-256 (0x12), not
      // identity (0x00).
      final bigKey = Uint8List(270);
      final pid = PeerId.fromPublicKey(bigKey, type: 'RSA');
      expect(pid.value[0], equals(0x12)); // sha2-256 multihash code
      expect(pid.value.length, equals(2 + 32)); // code + length + digest
    });

    test('fromPublicKey rejects an unknown key type', () {
      expect(
        () => PeerId.fromPublicKey(Uint8List(32), type: 'bogus'),
        throwsUnsupportedError,
      );
    });

    test('fromPublicKey requires a 32-byte key for Ed25519', () {
      expect(
        () => PeerId.fromPublicKey(Uint8List(31), type: 'Ed25519'),
        throwsArgumentError,
      );
    });
  });

  group('PeerId PoW', () {
    test('verifyPoW should accept PeerId with enough leading zeros', () {
      // Find a PeerId that satisfies a 4-bit difficulty
      PeerId? found;
      for (int i = 0; i < 1000; i++) {
        final pid = PeerId(
          value: Uint8List.fromList([i & 0xFF, (i >> 8) & 0xFF]),
        );
        if (pid.verifyPoW(difficulty: 4)) {
          found = pid;
          break;
        }
      }

      expect(found, isNotNull);
      expect(found!.verifyPoW(difficulty: 4), isTrue);
    });

    test('verifyPoW should reject PeerId with insufficient leading zeros', () {
      // Find a PeerId that DOES NOT satisfy a 16-bit difficulty (statistically likely)
      final pid = PeerId(value: Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
      expect(pid.verifyPoW(difficulty: 16), isFalse);
    });

    test('difficulty 0 should always pass', () {
      final pid = PeerId(value: Uint8List.fromList([0xFF]));
      expect(pid.verifyPoW(difficulty: 0), isTrue);
    });
  });

  group('PeerId.decode / ToCid / FromCid (go-libp2p TestIDEncoding vector)', () {
    test('decodes the base58 form and round-trips through Cid', () {
      final p1 = PeerId.decode(_manPeerIdBase58);
      expect(p1.toBase58(), equals(_manPeerIdBase58));

      final cid = p1.toCid();
      final p2 = PeerId.fromCid(cid);
      expect(p2, equals(p1));

      final p3 = PeerId.decode(cid.toString());
      expect(p3, equals(p1));
    });

    test('refuses to decode a non-peer-ID Cid', () {
      // dag-pb (raw file), not libp2p-key -- go-libp2p's own vector.
      expect(
        () => PeerId.decode(
          'bafkreifoybygix7fh3r3g5rqle3wcnhqldgdg4shzf4k3ulyw3gn7mabt4',
        ),
        throwsA(isA<InvalidPeerIdSourceException>()),
      );
    });

    test('toCid throws for the empty peer ID (no zero-value Cid sentinel)', () {
      expect(() => PeerId(value: Uint8List(0)).toCid(), throwsA(anything));
    });
  });

  group(
    'PeerId.matchesPublicKey / matchesPrivateKey / fromPrivateKey '
    '(go-libp2p TestIDMatchesPublicKey/PrivateKey vector, real RSA key)',
    () {
      test('matches the RSA private/public key it was derived from', () async {
        final skBytes = base64.decode(_manPrivateKeyBase64);
        final sk = await unmarshalPrivateKey(Uint8List.fromList(skBytes));
        final p1 = PeerId.decode(_manPeerIdBase58);

        expect(p1.matchesPrivateKey(sk), isTrue);
        expect(p1.matchesPublicKey(sk.getPublic()), isTrue);

        final p2 = PeerId.fromPrivateKey(sk);
        expect(p2, equals(p1));
        expect(p2.toBase58(), equals(_manPeerIdBase58));
      });

      test('does not match an unrelated key', () async {
        final keyPair = await generateEd25519KeyPair();
        final p1 = PeerId.decode(_manPeerIdBase58);
        expect(p1.matchesPublicKey(keyPair.getPublic()), isFalse);
      });
    },
  );

  group('PeerId.validate', () {
    test('throws for the empty peer ID', () {
      expect(
        () => PeerId(value: Uint8List(0)).validate(),
        throwsA(isA<EmptyPeerIdException>()),
      );
    });

    test('does not throw for a real peer ID', () {
      expect(() => PeerId.decode(_manPeerIdBase58).validate(), returnsNormally);
    });
  });

  group('PeerId.extractPublicKey', () {
    test('extracts the embedded key from an identity-multihash (Ed25519) ID', () async {
      final keyPair = await generateEd25519KeyPair();
      final pubKey = keyPair.getPublic();
      final id = PeerId.fromPubKey(pubKey);

      final extracted = id.extractPublicKey();
      expect(extracted.raw(), orderedEquals(pubKey.raw()));
    });

    test('throws for a hashed (RSA-sized) ID with no embedded key', () async {
      final skBytes = base64.decode(_manPrivateKeyBase64);
      final sk = await unmarshalPrivateKey(Uint8List.fromList(skBytes));
      final id = PeerId.fromPrivateKey(sk);
      expect(() => id.extractPublicKey(), throwsA(isA<NoPublicKeyException>()));
    });
  });

  group('PeerId.shortString', () {
    test('short IDs are returned as-is, wrapped', () {
      final id = PeerId(value: Uint8List.fromList([1, 2, 3]));
      expect(id.shortString(), equals('<peer.ID ${id.toBase58()}>'));
    });

    test('long IDs are truncated to first-2*last-6 chars', () {
      final id = PeerId.decode(_manPeerIdBase58);
      final s = id.toBase58();
      expect(id.shortString(), equals('<peer.ID ${s.substring(0, 2)}*${s.substring(s.length - 6)}>'));
    });
  });

  group('PeerId binary/text serde (round-trip)', () {
    test('marshalBinary / unmarshalBinary round-trips', () {
      final id = PeerId.decode(_manPeerIdBase58);
      final id2 = PeerId.unmarshalBinary(id.marshalBinary());
      expect(id2, equals(id));
    });

    test('marshalText / unmarshalText round-trips', () {
      final id = PeerId.decode(_manPeerIdBase58);
      final id2 = PeerId.unmarshalText(id.marshalText());
      expect(id2, equals(id));
    });

    test('fromBytes validates and rejects malformed multihash bytes', () {
      expect(
        () => PeerId.fromBytes(Uint8List.fromList([0xff, 0xff])),
        throwsA(anything),
      );
    });
  });

  group('PeerId.compareTo (IDSlice sort order)', () {
    test('sorts by raw bytes, matching go-libp2p IDSlice', () {
      final a = PeerId(value: Uint8List.fromList([1, 2, 3]));
      final b = PeerId(value: Uint8List.fromList([1, 2, 4]));
      final c = PeerId(value: Uint8List.fromList([1, 2]));
      final list = [b, a, c]..sort();
      expect(list, equals([c, a, b]));
    });
  });
}
