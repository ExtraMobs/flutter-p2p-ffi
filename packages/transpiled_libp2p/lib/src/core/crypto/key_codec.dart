// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/crypto/key_codec.dart
//
// Generic marshal/unmarshal across all four supported key types, per
// go-libp2p's core/crypto/key.go (`MarshalPublicKey`/`UnmarshalPublicKey`
// and their Private- equivalents): wraps/unwraps the crypto.pb
// `PublicKey`/`PrivateKey{Type, Data}` envelope and dispatches to the
// concrete key implementation by `KeyType`. This is what lets code
// receiving an arbitrary peer's identity key (e.g. a Noise handshake
// payload) handle any of RSA/Ed25519/Secp256k1/ECDSA without a manual
// switch at every call site.
import 'dart:typed_data';

import 'ecdsa_key.dart';
import 'ed25519_key.dart';
import 'key_types.dart';
import 'rsa_key.dart';
import 'secp256k1_key.dart';

/// Decodes a protobuf-wrapped public key (`crypto.pb.PublicKey`),
/// dispatching to the right key type, per go-libp2p's
/// `UnmarshalPublicKey`.
PubKey unmarshalPublicKey(Uint8List data) {
  final (type, raw) = unmarshalKeyProto(data);
  return switch (type) {
    KeyType.rsa => unmarshalRsaPublicKey(raw),
    KeyType.ed25519 => unmarshalEd25519PublicKey(raw),
    KeyType.secp256k1 => unmarshalSecp256k1PublicKey(raw),
    KeyType.ecdsa => unmarshalEcdsaPublicKey(raw),
  };
}

/// Encodes a public key as a protobuf-wrapped `crypto.pb.PublicKey`, per
/// go-libp2p's `MarshalPublicKey`.
Uint8List marshalPublicKey(PubKey key) => marshalKeyProto(key.type, key.raw());

/// Decodes a protobuf-wrapped private key (`crypto.pb.PrivateKey`),
/// dispatching to the right key type, per go-libp2p's
/// `UnmarshalPrivateKey`.
Future<PrivKey> unmarshalPrivateKey(Uint8List data) async {
  final (type, raw) = unmarshalKeyProto(data);
  return switch (type) {
    KeyType.rsa => unmarshalRsaPrivateKey(raw),
    KeyType.ed25519 => await unmarshalEd25519PrivateKey(raw),
    KeyType.secp256k1 => unmarshalSecp256k1PrivateKey(raw),
    KeyType.ecdsa => unmarshalEcdsaPrivateKey(raw),
  };
}

/// Encodes a private key as a protobuf-wrapped `crypto.pb.PrivateKey`,
/// per go-libp2p's `MarshalPrivateKey`.
Uint8List marshalPrivateKey(PrivKey key) => marshalKeyProto(key.type, key.raw());
