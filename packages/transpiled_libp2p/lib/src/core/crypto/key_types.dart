// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/crypto/key_types.dart
//
// Port of go-libp2p's core/crypto key abstractions (core/crypto/key.go's
// `Key`/`PubKey`/`PrivKey` interfaces) and the crypto.pb wire format
// (core/crypto/pb/crypto.proto): a `PublicKey`/`PrivateKey` message is
// just `{required KeyType Type = 1; required bytes Data = 2;}`, so this
// hand-rolls that 2-field protobuf codec rather than pulling in full
// protobuf codegen for two fields.
import 'dart:typed_data';

import 'proto_varint.dart';

/// go-libp2p core/crypto/pb's `KeyType` enum (crypto.proto).
enum KeyType {
  /// KeyType.RSA = 0.
  rsa(0),

  /// KeyType.Ed25519 = 1.
  ed25519(1),

  /// KeyType.Secp256k1 = 2.
  secp256k1(2),

  /// KeyType.ECDSA = 3.
  ecdsa(3);

  const KeyType(this.protoValue);

  /// The enum's wire value in the `crypto.pb.KeyType` protobuf enum.
  final int protoValue;

  /// Looks up a [KeyType] by its protobuf wire value.
  static KeyType? fromProtoValue(int value) {
    for (final t in KeyType.values) {
      if (t.protoValue == value) return t;
    }
    return null;
  }
}

/// A cryptographic key that can be compared to another key. Equivalent to
/// go-libp2p core/crypto's `Key` interface.
abstract class Key {
  /// The protobuf key type (crypto.pb.KeyType).
  KeyType get type;

  /// The raw bytes of the key, not wrapped in the protobuf `PublicKey`/
  /// `PrivateKey` message -- e.g. an X.509-encoded RSA key, or a bare
  /// 32-byte Ed25519 key.
  Uint8List raw();

  /// Whether this key has the same byte representation as [other].
  bool keyEquals(Key other) => _bytesEqual(raw(), other.raw());
}

/// A private key that can sign data and derive its public key. Equivalent
/// to go-libp2p core/crypto's `PrivKey` interface.
abstract class PrivKey extends Key {
  /// Signs [data], returning the signature bytes.
  Future<Uint8List> sign(Uint8List data);

  /// Returns the public key paired with this private key.
  PubKey getPublic();
}

/// A public key that can verify signatures made by the paired private key.
/// Equivalent to go-libp2p core/crypto's `PubKey` interface.
abstract class PubKey extends Key {
  /// Verifies that [signature] is a valid signature of [data] by the
  /// private key paired with this public key.
  Future<bool> verify(Uint8List data, Uint8List signature);
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Encodes `{required KeyType Type = 1; required bytes Data = 2;}`
/// (crypto.proto's `PublicKey`/`PrivateKey` message shape -- used for
/// both) on the wire.
Uint8List marshalKeyProto(KeyType type, Uint8List data) {
  final out = BytesBuilder();
  out.addByte(0x08); // field 1, varint wire type
  out.add(encodeProtoVarint(type.protoValue));
  out.addByte(0x12); // field 2, length-delimited wire type
  out.add(encodeProtoVarint(data.length));
  out.add(data);
  return out.toBytes();
}

/// Decodes a `{Type, Data}` message produced by [marshalKeyProto].
(KeyType type, Uint8List data) unmarshalKeyProto(Uint8List bytes) {
  KeyType? type;
  Uint8List? data;
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    switch (wireType) {
      case 0: // varint
        final (value, len) = readProtoVarint(bytes, offset);
        offset += len;
        if (fieldNumber == 1) {
          type = KeyType.fromProtoValue(value);
          if (type == null) {
            throw FormatException('unknown KeyType wire value: $value');
          }
        }
      case 2: // length-delimited
        final (length, lenLen) = readProtoVarint(bytes, offset);
        offset += lenLen;
        if (offset + length > bytes.length) {
          throw const FormatException('protobuf field runs past end of message');
        }
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;
        if (fieldNumber == 2) data = fieldBytes;
      default:
        throw FormatException('unsupported protobuf wire type: $wireType');
    }
  }
  if (type == null || data == null) {
    throw const FormatException('key message missing Type or Data field');
  }
  return (type, data);
}
