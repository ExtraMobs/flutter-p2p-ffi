// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/record/envelope.dart
//
// Port of go-libp2p's core/record/envelope.go: a signed wrapper around an
// arbitrary Record payload, so it can be exchanged between peers and
// verified statelessly (the public key travels with the envelope).
//
// Wire format (core/record/pb/envelope.proto): `Envelope{public_key = 1,
// payload_type = 2, payload = 3, signature = 5}` (field 4 is not used,
// preserved for wire compatibility). `public_key` is itself a nested
// crypto.pb.PublicKey message -- the same shape `marshalPublicKey`/
// `unmarshalPublicKey` (key_codec.dart) already produce/consume, so this
// reuses those directly for that field.
import 'dart:convert';
import 'dart:typed_data';

import '../crypto/key_codec.dart';
import '../crypto/key_types.dart';
import '../crypto/proto_varint.dart';
import 'record.dart';

/// Thrown by [Envelope.seal] when the [Record]'s domain is empty.
/// Equivalent to go-libp2p's `ErrEmptyDomain`.
class EmptyDomainException implements Exception {
  /// Creates the exception.
  const EmptyDomainException();
  @override
  String toString() => 'envelope domain must not be empty';
}

/// Thrown by [Envelope.seal] when the [Record]'s codec is empty. Equivalent
/// to go-libp2p's `ErrEmptyPayloadType`.
class EmptyPayloadTypeException implements Exception {
  /// Creates the exception.
  const EmptyPayloadTypeException();
  @override
  String toString() => 'payloadType must not be empty';
}

/// Thrown when an [Envelope]'s signature doesn't validate against the
/// domain it's being opened with. Equivalent to go-libp2p's
/// `ErrInvalidSignature`.
class InvalidSignatureException implements Exception {
  /// Creates the exception.
  const InvalidSignatureException();
  @override
  String toString() => 'invalid signature or incorrect domain';
}

/// An arbitrary payload, signed by a libp2p peer, that can be exchanged
/// with and verified by other peers. Equivalent to go-libp2p core/record's
/// `Envelope`.
///
/// Envelopes are signed in the context of a particular "domain" (a string
/// known to both the sealer and the verifier) -- see [Envelope.seal] and
/// [Envelope.consumeEnvelope].
class Envelope {
  Envelope._({
    required this.publicKey,
    required this.payloadType,
    required this.rawPayload,
    required Uint8List signature,
  }) : _signature = signature;

  /// Unmarshals a serialized Envelope protobuf message, without validating
  /// its signature. Most callers should use [consumeEnvelope] or
  /// [consumeTypedEnvelope] instead.
  factory Envelope.unmarshal(Uint8List data) {
    final decoded = _decodeEnvelopeProto(data);
    return Envelope._(
      publicKey: decoded.publicKey,
      payloadType: decoded.payloadType,
      rawPayload: decoded.payload,
      signature: decoded.signature,
    );
  }

  /// Marshals [rec], wraps it in an Envelope, and signs it with
  /// [privateKey]. Equivalent to go-libp2p's `Seal`.
  static Future<Envelope> seal(Record rec, PrivKey privateKey) async {
    final payload = rec.marshalRecord();
    final domain = rec.domain();
    final payloadType = rec.codec();
    if (domain.isEmpty) throw const EmptyDomainException();
    if (payloadType.isEmpty) throw const EmptyPayloadTypeException();

    final unsigned = _makeUnsigned(domain, payloadType, payload);
    final signature = await privateKey.sign(unsigned);

    return Envelope._(
      publicKey: privateKey.getPublic(),
      payloadType: payloadType,
      rawPayload: payload,
      signature: signature,
    );
  }

  /// Unmarshals a serialized Envelope and validates its signature against
  /// [domain]. On success, returns the Envelope and its payload unmarshaled
  /// into the [Record] type registered for the Envelope's payload type
  /// (see [registerType]). Equivalent to go-libp2p's `ConsumeEnvelope`.
  static Future<(Envelope, Record)> consumeEnvelope(
    Uint8List data,
    String domain,
  ) async {
    final envelope = Envelope.unmarshal(data);
    await envelope._validate(domain);
    return (envelope, envelope.record());
  }

  /// Like [consumeEnvelope], but unmarshals the payload into [destRecord]
  /// rather than looking up a registered [Record] type. Equivalent to
  /// go-libp2p's `ConsumeTypedEnvelope`.
  static Future<Envelope> consumeTypedEnvelope(
    Uint8List data,
    Record destRecord,
  ) async {
    final envelope = Envelope.unmarshal(data);
    await envelope._validate(destRecord.domain());
    destRecord.unmarshalRecord(envelope.rawPayload);
    envelope._cached = destRecord;
    return envelope;
  }

  /// The public key that can verify this envelope's signature and derive
  /// the peer ID of the signer.
  final PubKey publicKey;

  /// A binary identifier for the kind of data in [rawPayload].
  final Uint8List payloadType;

  /// The envelope's payload.
  final Uint8List rawPayload;

  final Uint8List _signature;
  Record? _cached;

  /// Serializes this Envelope to its protobuf wire representation.
  /// Equivalent to go-libp2p's `Envelope.Marshal`.
  Uint8List marshal() => _encodeEnvelopeProto(
    publicKey: publicKey,
    payloadType: payloadType,
    payload: rawPayload,
    signature: _signature,
  );

  /// Whether [other] has the same public key, payload, payload type, and
  /// signature as this Envelope. Equivalent to go-libp2p's `Envelope.Equal`.
  bool equals(Envelope other) =>
      publicKey.keyEquals(other.publicKey) &&
      _bytesEqual(payloadType, other.payloadType) &&
      _bytesEqual(_signature, other._signature) &&
      _bytesEqual(rawPayload, other.rawPayload);

  /// This envelope's payload, unmarshaled into the [Record] type registered
  /// for [payloadType] (see [registerType]). Cached after the first call.
  /// Equivalent to go-libp2p's `Envelope.Record`.
  Record record() {
    return _cached ??= unmarshalRecordPayload(payloadType, rawPayload);
  }

  /// Unmarshals [rawPayload] into [dest], ignoring any cached record.
  /// Equivalent to go-libp2p's `Envelope.TypedRecord`.
  void typedRecord(Record dest) => dest.unmarshalRecord(rawPayload);

  Future<void> _validate(String domain) async {
    final unsigned = _makeUnsigned(domain, payloadType, rawPayload);
    final valid = await publicKey.verify(unsigned, _signature);
    if (!valid) throw const InvalidSignatureException();
  }
}

/// Prepares the domain-separated buffer that gets signed/verified: each of
/// [domain], [payloadType], and [payload] is prefixed with its length as
/// an unsigned varint, then concatenated. Equivalent to go-libp2p's
/// `makeUnsigned` (Go pools this buffer for performance; Dart leaves that
/// to the garbage collector, not a behavioral gap).
Uint8List _makeUnsigned(String domain, Uint8List payloadType, Uint8List payload) {
  final fields = [Uint8List.fromList(utf8.encode(domain)), payloadType, payload];
  final out = BytesBuilder();
  for (final field in fields) {
    out.add(encodeProtoVarint(field.length));
    out.add(field);
  }
  return out.toBytes();
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Uint8List _encodeEnvelopeProto({
  required PubKey publicKey,
  required Uint8List payloadType,
  required Uint8List payload,
  required Uint8List signature,
}) {
  final out = BytesBuilder();
  void writeField(int fieldNumber, Uint8List bytes) {
    out.add(encodeProtoVarint((fieldNumber << 3) | 2));
    out.add(encodeProtoVarint(bytes.length));
    out.add(bytes);
  }

  writeField(1, marshalPublicKey(publicKey));
  writeField(2, payloadType);
  writeField(3, payload);
  writeField(5, signature);
  return out.toBytes();
}

({PubKey publicKey, Uint8List payloadType, Uint8List payload, Uint8List signature})
_decodeEnvelopeProto(Uint8List bytes) {
  Uint8List? publicKeyBytes;
  Uint8List? payloadType;
  Uint8List? payload;
  Uint8List? signature;
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    if (wireType != 2) {
      throw FormatException('unsupported wire type in Envelope: $wireType');
    }
    final (length, lenLen) = readProtoVarint(bytes, offset);
    offset += lenLen;
    if (offset + length > bytes.length) {
      throw const FormatException('protobuf field runs past end of message');
    }
    final fieldBytes = bytes.sublist(offset, offset + length);
    offset += length;
    switch (fieldNumber) {
      case 1:
        publicKeyBytes = fieldBytes;
      case 2:
        payloadType = fieldBytes;
      case 3:
        payload = fieldBytes;
      case 5:
        signature = fieldBytes;
    }
  }
  if (publicKeyBytes == null ||
      payloadType == null ||
      payload == null ||
      signature == null) {
    throw const FormatException('Envelope message missing a required field');
  }
  return (
    publicKey: unmarshalPublicKey(publicKeyBytes),
    payloadType: payloadType,
    payload: payload,
    signature: signature,
  );
}
