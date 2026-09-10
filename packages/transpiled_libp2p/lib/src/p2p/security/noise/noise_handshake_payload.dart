// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/transport/noise/noise_handshake_payload.dart
//
// Port of go-libp2p's p2p/security/noise handshake payload
// (handshake.go's generateHandshakePayload/handleRemoteHandshakePayload +
// p2p/security/noise/pb/payload.proto's NoiseHandshakePayload): the
// payload each side sends inside the Noise XX handshake, proving they
// hold the libp2p identity private key by signing their Noise static
// public key with it. This is what lets a peer authenticate as a
// specific PeerId over the Noise channel built by noise_state.dart --
// and, since it dispatches through transpiled_libp2p's generic key codec
// (unmarshalPublicKey/marshalPublicKey), it works for any of the four
// crypto.pb key types (RSA/Ed25519/Secp256k1/ECDSA), not just Ed25519.
//
// The wire format is a minimal 2-field protobuf (identity_key,
// identity_sig -- field 4 `extensions` is never emitted and ignored on
// decode, matching how go-libp2p treats it as optional).
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/key_codec.dart';
import '../../../core/crypto/key_types.dart';
import '../../../core/peer/peer_id.dart';

/// Prepended to the Noise static public key before signing with the
/// libp2p identity key, per go-libp2p's `payloadSigPrefix`.
const String noisePayloadSigPrefix = 'noise-libp2p-static-key:';

/// The libp2p identity of the remote peer, recovered and authenticated
/// from a Noise handshake payload.
class NoiseRemoteIdentity {
  /// Creates a [NoiseRemoteIdentity] from a verified public key and its
  /// derived [PeerId].
  NoiseRemoteIdentity({required this.publicKey, required this.peerId});

  /// The remote peer's libp2p identity public key.
  final PubKey publicKey;

  /// The [PeerId] derived from [publicKey], per `core/peer`'s
  /// `IDFromPublicKey`.
  final PeerId peerId;
}

/// Thrown when a Noise handshake payload's signature doesn't verify
/// against the claimed identity key, or the peer ID it derives to
/// doesn't match the expected one.
class NoiseHandshakeAuthException implements Exception {
  /// Creates a [NoiseHandshakeAuthException] with a [message].
  NoiseHandshakeAuthException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'NoiseHandshakeAuthException: $message';
}

/// Builds the libp2p handshake payload (`pb.NoiseHandshakePayload`) sent
/// inside the Noise XX handshake: our identity public key plus a
/// signature -- made with our identity private key -- over our Noise
/// static public key, per go-libp2p's `generateHandshakePayload`.
Future<Uint8List> generateNoiseHandshakePayload({
  required PrivKey localIdentityKey,
  required Uint8List localNoiseStaticPublicKey,
}) async {
  final toSign = Uint8List.fromList([
    ...utf8.encode(noisePayloadSigPrefix),
    ...localNoiseStaticPublicKey,
  ]);
  final signature = await localIdentityKey.sign(toSign);
  final identityKeyBytes = marshalPublicKey(localIdentityKey.getPublic());
  return _encodeNoiseHandshakePayload(
    identityKey: identityKeyBytes,
    identitySig: signature,
  );
}

/// Parses and authenticates a remote peer's handshake payload, per
/// go-libp2p's `handleRemoteHandshakePayload`: unmarshals the claimed
/// identity key, verifies its signature over the peer's Noise static
/// public key, and derives the resulting [PeerId].
///
/// Throws [NoiseHandshakeAuthException] if the signature is invalid, or
/// if [expectedRemoteId] is given and doesn't match the derived
/// [PeerId] (mirroring go-libp2p's optional `checkPeerID`).
Future<NoiseRemoteIdentity> verifyNoiseHandshakePayload(
  Uint8List payload,
  Uint8List remoteNoiseStaticPublicKey, {
  PeerId? expectedRemoteId,
}) async {
  final (identityKeyBytes, identitySig) = _decodeNoiseHandshakePayload(payload);
  final remotePubKey = unmarshalPublicKey(identityKeyBytes);

  final peerId = PeerId.fromPublicKey(remotePubKey.raw(), type: remotePubKey.type.name);
  if (expectedRemoteId != null && expectedRemoteId != peerId) {
    throw NoiseHandshakeAuthException(
      'peer ID mismatch: expected $expectedRemoteId, got $peerId',
    );
  }

  final toVerify = Uint8List.fromList([
    ...utf8.encode(noisePayloadSigPrefix),
    ...remoteNoiseStaticPublicKey,
  ]);
  final ok = await remotePubKey.verify(toVerify, identitySig);
  if (!ok) {
    throw NoiseHandshakeAuthException('handshake payload signature invalid');
  }

  return NoiseRemoteIdentity(publicKey: remotePubKey, peerId: peerId);
}

Uint8List _encodeNoiseHandshakePayload({
  required Uint8List identityKey,
  required Uint8List identitySig,
}) {
  final out = BytesBuilder();
  _writeLengthDelimitedField(out, 1, identityKey);
  _writeLengthDelimitedField(out, 2, identitySig);
  return out.toBytes();
}

(Uint8List identityKey, Uint8List identitySig) _decodeNoiseHandshakePayload(Uint8List bytes) {
  Uint8List? identityKey;
  Uint8List? identitySig;
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = _readVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    switch (wireType) {
      case 0: // varint
        final (_, len) = _readVarint(bytes, offset);
        offset += len;
      case 2: // length-delimited
        final (length, lenLen) = _readVarint(bytes, offset);
        offset += lenLen;
        if (offset + length > bytes.length) {
          throw const FormatException('Noise handshake payload field runs past end of message');
        }
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;
        if (fieldNumber == 1) identityKey = fieldBytes;
        if (fieldNumber == 2) identitySig = fieldBytes;
      default:
        throw FormatException('unsupported protobuf wire type in Noise handshake payload: $wireType');
    }
  }
  if (identityKey == null || identitySig == null) {
    throw const FormatException('Noise handshake payload missing identity_key or identity_sig');
  }
  return (identityKey, identitySig);
}

void _writeLengthDelimitedField(BytesBuilder out, int fieldNumber, Uint8List value) {
  out.add(_encodeVarint((fieldNumber << 3) | 2));
  out.add(_encodeVarint(value.length));
  out.add(value);
}

Uint8List _encodeVarint(int value) {
  final bytes = <int>[];
  var v = value;
  while (v >= 0x80) {
    bytes.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  bytes.add(v);
  return Uint8List.fromList(bytes);
}

(int value, int length) _readVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  var index = offset;
  while (true) {
    if (index >= bytes.length) {
      throw const FormatException('protobuf varint runs past end of Noise handshake payload');
    }
    final byte = bytes[index];
    value |= (byte & 0x7f) << shift;
    index++;
    if ((byte & 0x80) == 0) return (value, index - offset);
    shift += 7;
    if (shift > 63) throw const FormatException('protobuf varint too long');
  }
}
