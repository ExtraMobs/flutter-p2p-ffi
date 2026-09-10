// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/peer/peer_record.dart
//
// Port of go-libp2p's core/peer/record.go: PeerRecord shares a peer's
// public listen addresses (and, in the future, more) with other peers,
// designed to travel inside a signed record.Envelope.
//
// Wire format (core/peer/pb/peer_record.proto): `PeerRecord{peer_id = 1,
// seq = 2, addresses = 3}`, where each `addresses` entry is an
// `AddressInfo{multiaddr = 1}` submessage.
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../crypto/proto_varint.dart';
import '../record/record.dart';
import 'addr_info.dart';
import 'peer_id.dart';

/// The domain string used when signing/verifying PeerRecords inside an
/// [Envelope]. Equivalent to go-libp2p's `PeerRecordEnvelopeDomain`.
const String peerRecordEnvelopeDomain = 'libp2p-peer-record';

/// The type hint identifying a PeerRecord's payload inside an [Envelope]
/// (the multicodec `libp2p-peer-record`, table code `0x0301`). Equivalent
/// to go-libp2p's `PeerRecordEnvelopePayloadType`.
final Uint8List peerRecordEnvelopePayloadType = Uint8List.fromList([0x03, 0x01]);

/// Shares a peer's public listen addresses, ordered in time by [seq].
/// Equivalent to go-libp2p core/peer's `PeerRecord`.
///
/// PeerRecords are meant to be shared inside a signed
/// `record.Envelope` (`envelope.dart`): build one, call
/// `Envelope.seal(record, privateKey)`, and share the resulting envelope's
/// [Envelope.marshal] bytes. A remote peer recovers it via
/// `Envelope.consumeEnvelope(bytes, peerRecordEnvelopeDomain)`, which
/// automatically unmarshals the payload back into a `PeerRecord` (this
/// file registers that dispatch on load -- see `_registerPeerRecordType`
/// at the bottom).
class PeerRecord implements Record {
  /// Builds a PeerRecord with a timestamp-based [seq] by default. [peerId]
  /// and [addrs] should be populated by the caller if not passed here.
  PeerRecord({PeerId? peerId, this.addrs = const [], int? seq})
    : peerId = peerId ?? PeerId(value: Uint8List(0)),
      seq = seq ?? timestampSeq() {
    _ensurePeerRecordTypeRegistered();
  }

  /// Builds a PeerRecord from [info], with a timestamp-based sequence
  /// number. Equivalent to go-libp2p's `PeerRecordFromAddrInfo`.
  factory PeerRecord.fromAddrInfo(AddrInfo info) =>
      PeerRecord(peerId: info.id, addrs: info.addrs);

  /// Decodes a PeerRecord from its protobuf wire representation. Equivalent
  /// to go-libp2p's `PeerRecordFromProtobuf`.
  factory PeerRecord.fromProtobuf(Uint8List bytes) {
    final decoded = _decodePeerRecordProto(bytes);
    return PeerRecord(
      peerId: PeerId.fromBytes(decoded.peerId),
      addrs: decoded.addrs,
      seq: decoded.seq,
    );
  }

  /// The peer this record pertains to.
  PeerId peerId;

  /// The peer's public listen addresses.
  List<Multiaddr> addrs;

  /// Monotonically-increasing sequence number ordering PeerRecords in time
  /// for a given peer. Newer records must have a strictly greater [seq]
  /// than older ones.
  int seq;

  @override
  String domain() => peerRecordEnvelopeDomain;

  @override
  Uint8List codec() => peerRecordEnvelopePayloadType;

  @override
  Uint8List marshalRecord() => toProtobuf();

  @override
  void unmarshalRecord(Uint8List data) {
    final decoded = _decodePeerRecordProto(data);
    peerId = PeerId.fromBytes(decoded.peerId);
    addrs = decoded.addrs;
    seq = decoded.seq;
  }

  /// Encodes this record to its protobuf wire representation. Equivalent
  /// to go-libp2p's `PeerRecord.ToProtobuf`.
  Uint8List toProtobuf() =>
      _encodePeerRecordProto(peerId: peerId, addrs: addrs, seq: seq);

  /// Whether [other] is identical to this record. Equivalent to
  /// go-libp2p's `PeerRecord.Equal`.
  bool equals(PeerRecord other) {
    if (peerId != other.peerId) return false;
    if (seq != other.seq) return false;
    if (addrs.length != other.addrs.length) return false;
    for (var i = 0; i < addrs.length; i++) {
      if (addrs[i] != other.addrs[i]) return false;
    }
    return true;
  }
}

int _lastTimestamp = 0;

/// Generates a timestamp-based sequence number for a PeerRecord, guaranteed
/// strictly greater than the previous value this function returned (even
/// if the system clock doesn't strictly increase between calls).
/// Equivalent to go-libp2p's `TimestampSeq`.
///
/// Go uses nanosecond-resolution `time.Now().UnixNano()`; Dart's `DateTime`
/// only exposes microsecond resolution, scaled up by 1000 here to keep the
/// same units -- a platform limitation, not a behavioral gap (the
/// monotonicity guarantee this function exists for still holds).
int timestampSeq() {
  var now = DateTime.now().microsecondsSinceEpoch * 1000;
  if (now <= _lastTimestamp) now = _lastTimestamp + 1;
  _lastTimestamp = now;
  return now;
}

// Go registers PeerRecord for automatic Envelope dispatch in this file's
// package `init()`, which the Go runtime guarantees to run once, eagerly,
// whenever the package is imported. Dart has no equivalent -- a top-level
// variable initializer looks similar but is *lazy* (only runs if
// something actually reads that variable), so it doesn't fire just from
// importing this library. Registering idempotently from the constructor
// instead guarantees it happens before any PeerRecord this process
// creates could plausibly need dispatch (e.g. via Envelope.consumeEnvelope
// after sealing one), without depending on lazy-init timing.
bool _peerRecordTypeRegistered = false;

void _ensurePeerRecordTypeRegistered() {
  if (_peerRecordTypeRegistered) return;
  // Set before calling registerType, which invokes this factory once to
  // read its codec() -- avoids re-entering this same guard recursively.
  _peerRecordTypeRegistered = true;
  registerType(PeerRecord.new);
}

({Uint8List peerId, int seq, List<Multiaddr> addrs}) _decodePeerRecordProto(
  Uint8List bytes,
) {
  Uint8List? peerId;
  var seq = 0;
  final addrs = <Multiaddr>[];
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    switch (wireType) {
      case 0:
        final (value, len) = readProtoVarint(bytes, offset);
        offset += len;
        if (fieldNumber == 2) seq = value;
      case 2:
        final (length, lenLen) = readProtoVarint(bytes, offset);
        offset += lenLen;
        if (offset + length > bytes.length) {
          throw const FormatException('protobuf field runs past end of message');
        }
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;
        if (fieldNumber == 1) {
          peerId = fieldBytes;
        } else if (fieldNumber == 3) {
          final multiaddrBytes = _decodeAddressInfoProto(fieldBytes);
          if (multiaddrBytes != null && multiaddrBytes.isNotEmpty) {
            try {
              addrs.add(Multiaddr.fromBytes(multiaddrBytes));
            } on FormatException {
              // Drop unparseable addresses, matching go-libp2p's
              // addrsFromProtobuf (skips on error or empty bytes).
            }
          }
        }
      default:
        throw FormatException('unsupported wire type in PeerRecord: $wireType');
    }
  }
  if (peerId == null) {
    throw const FormatException('PeerRecord message missing peer_id field');
  }
  return (peerId: peerId, seq: seq, addrs: addrs);
}

Uint8List? _decodeAddressInfoProto(Uint8List bytes) {
  var offset = 0;
  Uint8List? multiaddr;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    if (wireType != 2) {
      throw FormatException('unsupported wire type in AddressInfo: $wireType');
    }
    final (length, lenLen) = readProtoVarint(bytes, offset);
    offset += lenLen;
    if (offset + length > bytes.length) {
      throw const FormatException('protobuf field runs past end of message');
    }
    final fieldBytes = bytes.sublist(offset, offset + length);
    offset += length;
    if (fieldNumber == 1) multiaddr = fieldBytes;
  }
  return multiaddr;
}

Uint8List _encodePeerRecordProto({
  required PeerId peerId,
  required List<Multiaddr> addrs,
  required int seq,
}) {
  final out = BytesBuilder();
  void writeLengthDelimited(int fieldNumber, Uint8List bytes) {
    out.add(encodeProtoVarint((fieldNumber << 3) | 2));
    out.add(encodeProtoVarint(bytes.length));
    out.add(bytes);
  }

  writeLengthDelimited(1, peerId.value);
  if (seq != 0) {
    out.add(encodeProtoVarint((2 << 3) | 0));
    out.add(encodeProtoVarint(seq));
  }
  for (final addr in addrs) {
    final addrBytes = addr.toBytes();
    // Drop empty multiaddrs -- matches go-libp2p's addrsToProtobuf guard
    // against a zero-value Multiaddr encoding to zero bytes on the wire.
    if (addrBytes.isEmpty) continue;
    writeLengthDelimited(3, _encodeAddressInfoProto(addrBytes));
  }
  return out.toBytes();
}

Uint8List _encodeAddressInfoProto(Uint8List multiaddrBytes) {
  final out = BytesBuilder();
  out.add(encodeProtoVarint((1 << 3) | 2));
  out.add(encodeProtoVarint(multiaddrBytes.length));
  out.add(multiaddrBytes);
  return out.toBytes();
}
