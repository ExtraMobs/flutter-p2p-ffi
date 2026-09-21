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
// The wire format is `pb.NoiseHandshakePayload` (identity_key,
// identity_sig, and the optional field 4 `extensions` submessage,
// `pb.NoiseExtensions`). Field 4 is only emitted when a caller passes
// [NoiseExtensions] to [generateNoiseHandshakePayload]; a `null` extensions
// argument reproduces the payload's previous 2-field-only wire format
// byte-for-byte.
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
  NoiseRemoteIdentity({
    required this.publicKey,
    required this.peerId,
    this.extensions,
  });

  /// The remote peer's libp2p identity public key.
  final PubKey publicKey;

  /// The [PeerId] derived from [publicKey], per `core/peer`'s
  /// `IDFromPublicKey`.
  final PeerId peerId;

  /// The remote's early-data extensions (`pb.NoiseHandshakePayload`'s
  /// field 4), or `null` if the payload carried none.
  final NoiseExtensions? extensions;
}

/// Early-data extensions carried in a Noise handshake payload, per
/// go-libp2p's `pb.NoiseExtensions` (field 4 of `NoiseHandshakePayload`).
/// Used by transports that need to smuggle data through the handshake
/// before the connection is authenticated -- e.g. WebTransport certificate
/// hashes.
class NoiseExtensions {
  /// Creates a [NoiseExtensions]. Both fields default to empty lists,
  /// matching an absent repeated field on the wire.
  NoiseExtensions({
    List<Uint8List>? webtransportCerthashes,
    List<String>? streamMuxers,
  }) : webtransportCerthashes = webtransportCerthashes ?? const [],
       streamMuxers = streamMuxers ?? const [];

  /// Certificate hashes for the local WebTransport certificates (field 1,
  /// `repeated bytes`).
  final List<Uint8List> webtransportCerthashes;

  /// Stream multiplexer protocol IDs this side supports (field 2,
  /// `repeated string`).
  final List<String> streamMuxers;

  Uint8List _encode() {
    final out = BytesBuilder();
    for (final certhash in webtransportCerthashes) {
      _writeLengthDelimitedField(out, 1, certhash);
    }
    for (final muxer in streamMuxers) {
      _writeLengthDelimitedField(
        out,
        2,
        Uint8List.fromList(utf8.encode(muxer)),
      );
    }
    return out.toBytes();
  }

  static NoiseExtensions _decode(Uint8List bytes) {
    final certhashes = <Uint8List>[];
    final muxers = <String>[];
    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLen) = _readVarint(bytes, offset);
      offset += tagLen;
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x7;
      final (nextOffset, value) = _readProtoField(bytes, offset, wireType);
      offset = nextOffset;
      if (value == null) continue;
      if (fieldNumber == 1) certhashes.add(value);
      if (fieldNumber == 2) muxers.add(utf8.decode(value));
    }
    return NoiseExtensions(
      webtransportCerthashes: certhashes,
      streamMuxers: muxers,
    );
  }
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
///
/// [extensions], when given, are embedded as field 4 (`pb.NoiseExtensions`).
/// Leaving it `null` keeps the wire format byte-for-byte identical to a
/// payload with no extensions field at all -- this is required for
/// non-regression against Kubo, which already interoperates with this
/// transport over plain TCP without any extensions.
Future<Uint8List> generateNoiseHandshakePayload({
  required PrivKey localIdentityKey,
  required Uint8List localNoiseStaticPublicKey,
  NoiseExtensions? extensions,
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
    extensions: extensions,
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
  final (identityKeyBytes, identitySig, extensions) =
      _decodeNoiseHandshakePayload(payload);
  final remotePubKey = unmarshalPublicKey(identityKeyBytes);

  final peerId = PeerId.fromPublicKey(
    remotePubKey.raw(),
    type: remotePubKey.type.name,
  );
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

  return NoiseRemoteIdentity(
    publicKey: remotePubKey,
    peerId: peerId,
    extensions: extensions,
  );
}

Uint8List _encodeNoiseHandshakePayload({
  required Uint8List identityKey,
  required Uint8List identitySig,
  NoiseExtensions? extensions,
}) {
  final out = BytesBuilder();
  _writeLengthDelimitedField(out, 1, identityKey);
  _writeLengthDelimitedField(out, 2, identitySig);
  if (extensions != null) {
    _writeLengthDelimitedField(out, 4, extensions._encode());
  }
  return out.toBytes();
}

(Uint8List identityKey, Uint8List identitySig, NoiseExtensions? extensions)
_decodeNoiseHandshakePayload(Uint8List bytes) {
  Uint8List? identityKey;
  Uint8List? identitySig;
  NoiseExtensions? extensions;
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = _readVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    final (nextOffset, value) = _readProtoField(bytes, offset, wireType);
    offset = nextOffset;
    if (value == null) continue; // varint / 32-/64-bit field, skipped
    if (fieldNumber == 1) identityKey = value;
    if (fieldNumber == 2) identitySig = value;
    if (fieldNumber == 4) extensions = NoiseExtensions._decode(value);
  }
  if (identityKey == null || identitySig == null) {
    throw const FormatException(
      'Noise handshake payload missing identity_key or identity_sig',
    );
  }
  return (identityKey, identitySig, extensions);
}

/// Reads one protobuf field's value at [offset], given its already-parsed
/// [wireType]. Length-delimited fields (wire type 2) return their raw
/// bytes; varint (0), 64-bit (1) and 32-bit (5) fields are consumed and
/// skipped, returning a `null` value, matching how a real protobuf parser
/// tolerates unknown fields of those wire types. Wire types 3, 4, 6 and 7
/// (group start/end and two reserved values) have no valid meaning here and
/// throw.
(int offset, Uint8List? value) _readProtoField(
  Uint8List bytes,
  int offset,
  int wireType,
) {
  switch (wireType) {
    case 0: // varint
      final (_, len) = _readVarint(bytes, offset);
      return (offset + len, null);
    case 1: // 64-bit fixed
      return (_skipFixedWidth(bytes, offset, 8), null);
    case 2: // length-delimited
      final (length, lenLen) = _readVarint(bytes, offset);
      final start = offset + lenLen;
      if (start + length > bytes.length) {
        throw const FormatException(
          'Noise handshake payload field runs past end of message',
        );
      }
      return (start + length, bytes.sublist(start, start + length));
    case 5: // 32-bit fixed
      return (_skipFixedWidth(bytes, offset, 4), null);
    default:
      throw FormatException(
        'unsupported protobuf wire type in Noise handshake payload: $wireType',
      );
  }
}

int _skipFixedWidth(Uint8List bytes, int offset, int width) {
  if (offset + width > bytes.length) {
    throw const FormatException(
      'protobuf fixed-width field runs past end of Noise handshake payload',
    );
  }
  return offset + width;
}

void _writeLengthDelimitedField(
  BytesBuilder out,
  int fieldNumber,
  Uint8List value,
) {
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
      throw const FormatException(
        'protobuf varint runs past end of Noise handshake payload',
      );
    }
    final byte = bytes[index];
    value |= (byte & 0x7f) << shift;
    index++;
    if ((byte & 0x80) == 0) return (value, index - offset);
    shift += 7;
    if (shift > 63) throw const FormatException('protobuf varint too long');
  }
}
