// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/crypto/ed25519_key.dart
//
// Wraps the existing Ed25519Signer (already used for IPNS record
// signing) in the Key/PrivKey/PubKey abstraction, matching go-libp2p's
// core/crypto Ed25519PrivateKey/Ed25519PublicKey (core/crypto/ed25519.go):
// raw private key is the 64-byte `seed || publicKey` concatenation
// (Go's `ed25519.PrivateKey` format), raw public key is the 32-byte
// point. This is what lets Ed25519 identity keys participate uniformly
// alongside RSA/Secp256k1/ECDSA wherever a `PrivKey`/`PubKey` is
// expected (e.g. the Noise handshake payload's identity-key dispatch).
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_utils.dart';
import 'ed25519_signer.dart';
import 'key_types.dart';

final Ed25519Signer _signer = Ed25519Signer();

/// An Ed25519 private key, per go-libp2p's `core/crypto`
/// `Ed25519PrivateKey`.
class Ed25519PrivKey extends PrivKey {
  Ed25519PrivKey._(this._keyPair, this._rawBytes, this._public);

  final SimpleKeyPair _keyPair;
  final Uint8List _rawBytes;
  final Ed25519PubKey _public;

  @override
  KeyType get type => KeyType.ed25519;

  @override
  PubKey getPublic() => _public;

  @override
  Uint8List raw() => _rawBytes;

  @override
  Future<Uint8List> sign(Uint8List data) => _signer.sign(data, _keyPair);
}

/// An Ed25519 public key, per go-libp2p's `core/crypto`
/// `Ed25519PublicKey`.
class Ed25519PubKey extends PubKey {
  Ed25519PubKey._(this._rawBytes);

  final Uint8List _rawBytes;

  @override
  KeyType get type => KeyType.ed25519;

  @override
  Uint8List raw() => _rawBytes;

  @override
  Future<bool> verify(Uint8List data, Uint8List signature) {
    return _signer.verify(data, signature, _signer.publicKeyFromBytes(_rawBytes));
  }
}

/// Generates a fresh Ed25519 key pair, per go-libp2p's
/// `GenerateEd25519Key`.
Future<Ed25519PrivKey> generateEd25519KeyPair() async {
  return _wrapKeyPair(await _signer.generateKeyPair());
}

/// Deterministically derives an Ed25519 key pair from a 32-byte seed,
/// per go-libp2p's `ed25519.NewKeyFromSeed` convention -- useful when a
/// caller already has (or wants to persist) just the seed rather than
/// the full 64-byte `seed || publicKey` private key.
Future<Ed25519PrivKey> ed25519KeyPairFromSeed(Uint8List seed) async {
  if (seed.length != 32) {
    throw ArgumentError('Ed25519 seed must be exactly 32 bytes, got ${seed.length}');
  }
  return _wrapKeyPair(await _signer.keyPairFromSeed(seed));
}

/// Parses a raw Ed25519 private key, per go-libp2p's
/// `UnmarshalEd25519PrivateKey`: either the standard 64-byte
/// `seed || publicKey` form, or a legacy 96-byte form with one redundant
/// trailing copy of the public key (which must match the embedded one).
Future<Ed25519PrivKey> unmarshalEd25519PrivateKey(Uint8List data) async {
  final Uint8List keyBytes;
  if (data.length == 96) {
    final embeddedPk = data.sublist(32, 64);
    final redundantPk = data.sublist(64, 96);
    if (!CryptoUtils.constantTimeEquals(embeddedPk, redundantPk)) {
      throw const FormatException('expected redundant ed25519 public key to be redundant');
    }
    keyBytes = data.sublist(0, 64);
  } else if (data.length == 64) {
    keyBytes = data;
  } else {
    throw FormatException('expected ed25519 data size to be 64 or 96, got ${data.length}');
  }

  final seed = keyBytes.sublist(0, 32);
  final publicKeyBytes = keyBytes.sublist(32, 64);
  final keyPair = await _signer.keyPairFromSeed(seed);
  return Ed25519PrivKey._(keyPair, keyBytes, Ed25519PubKey._(publicKeyBytes));
}

/// Parses a 32-byte Ed25519 public key, per go-libp2p's
/// `UnmarshalEd25519PublicKey`.
Ed25519PubKey unmarshalEd25519PublicKey(Uint8List data) {
  if (data.length != 32) {
    throw FormatException('expected ed25519 public key data size to be 32, got ${data.length}');
  }
  return Ed25519PubKey._(data);
}

Future<Ed25519PrivKey> _wrapKeyPair(SimpleKeyPair keyPair) async {
  final seed = await keyPair.extractPrivateKeyBytes();
  final publicKeyBytes = await _signer.extractPublicKeyBytes(keyPair);
  final rawBytes = Uint8List.fromList([...seed, ...publicKeyBytes]);
  return Ed25519PrivKey._(keyPair, rawBytes, Ed25519PubKey._(publicKeyBytes));
}
