// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/key_codec_test.dart
//
// Round-trip test for lib/src/crypto/key_codec.dart's generic dispatch
// across all four key types. The individual key formats are already
// validated against real Go-generated vectors in their own parity
// tests (rsa/secp256k1/ecdsa/ed25519_key_parity_test.dart); this only
// proves the protobuf envelope + type dispatch wiring is correct.
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:test/test.dart';

void main() {
  group('key_codec', () {
    test('RSA public/private key round-trip through the generic codec', () async {
      final priv = generateRsaKeyPair(minRsaKeyBits);
      final marshaledPub = marshalPublicKey(priv.getPublic());
      final marshaledPriv = marshalPrivateKey(priv);

      final decodedPub = unmarshalPublicKey(marshaledPub);
      final decodedPriv = await unmarshalPrivateKey(marshaledPriv);

      expect(decodedPub.type, equals(KeyType.rsa));
      expect(decodedPriv.type, equals(KeyType.rsa));
      expect(decodedPub.raw(), equals(priv.getPublic().raw()));
      expect(decodedPriv.raw(), equals(priv.raw()));
    });

    test('Ed25519 public/private key round-trip through the generic codec', () async {
      final priv = await generateEd25519KeyPair();
      final marshaledPub = marshalPublicKey(priv.getPublic());
      final marshaledPriv = marshalPrivateKey(priv);

      final decodedPub = unmarshalPublicKey(marshaledPub);
      final decodedPriv = await unmarshalPrivateKey(marshaledPriv);

      expect(decodedPub.type, equals(KeyType.ed25519));
      expect(decodedPriv.type, equals(KeyType.ed25519));
      expect(decodedPub.raw(), equals(priv.getPublic().raw()));
      expect(decodedPriv.raw(), equals(priv.raw()));
    });

    test('Secp256k1 public/private key round-trip through the generic codec', () async {
      final priv = generateSecp256k1KeyPair();
      final marshaledPub = marshalPublicKey(priv.getPublic());
      final marshaledPriv = marshalPrivateKey(priv);

      final decodedPub = unmarshalPublicKey(marshaledPub);
      final decodedPriv = await unmarshalPrivateKey(marshaledPriv);

      expect(decodedPub.type, equals(KeyType.secp256k1));
      expect(decodedPriv.type, equals(KeyType.secp256k1));
      expect(decodedPub.raw(), equals(priv.getPublic().raw()));
      expect(decodedPriv.raw(), equals(priv.raw()));
    });

    test('ECDSA public/private key round-trip through the generic codec', () async {
      final priv = generateEcdsaKeyPair();
      final marshaledPub = marshalPublicKey(priv.getPublic());
      final marshaledPriv = marshalPrivateKey(priv);

      final decodedPub = unmarshalPublicKey(marshaledPub);
      final decodedPriv = await unmarshalPrivateKey(marshaledPriv);

      expect(decodedPub.type, equals(KeyType.ecdsa));
      expect(decodedPriv.type, equals(KeyType.ecdsa));
      expect(decodedPub.raw(), equals(priv.getPublic().raw()));
      expect(decodedPriv.raw(), equals(priv.raw()));
    });

    test('a signature made with one type verifies through the generically-decoded key', () async {
      final priv = await generateEd25519KeyPair();
      final decodedPub = unmarshalPublicKey(marshalPublicKey(priv.getPublic()));
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final sig = await priv.sign(data);
      final ok = await decodedPub.verify(data, sig);
      expect(ok, isTrue);
    });
  });
}
