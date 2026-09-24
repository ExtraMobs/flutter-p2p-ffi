// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_payload_data.go` (github.com/pion/sctp): [ChunkPayloadData]
/// (the SCTP DATA chunk, type 0, RFC 4960 section-3.3.1) and
/// [PayloadProtocolIdentifier], its Payload Protocol Identifier field.
///
/// `chunkPayloadData` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkPayloadData] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
/// `PayloadProtocolIdentifier` (chunk_payload_data.go:88), by contrast, *is*
/// exported upstream, so unlike every other symbol in this package it is
/// re-exported from `transpiled_pion_sctp.dart` -- see that file's doc
/// comment.
///
/// **Runtime bookkeeping (chunk_payload_data.go:60-77,184-215)**: the
/// retransmission/partial-reliability fields (`acked`, `missIndicator`,
/// `since`, `nSent`, the private `_abandoned`/`_allInflight`, `retransmit`,
/// `head`) and the `abandoned`/`setAbandoned`/`setAllInflight`/`isFragmented`
/// methods built on them are ported here too, now that the
/// `association`/`stream`/queue runtime that is their only reachable caller
/// is itself ported (see `association.dart`, `stream.dart`,
/// `payload_queue.dart`). None of it is reachable from
/// `packet.unmarshal`/`marshal` (the pure codec ported earlier in this
/// file); `since` uses Dart's `DateTime` in place of Go's `time.Time`
/// (`null` standing in for the Go zero value, since nothing reads `since`
/// before `movePendingDataChunkToInflightQueue` sets it, mirroring
/// upstream's `since` only ever being read after that same assignment).
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkPayloadSmall` (chunk_payload_data.go:99-101).
final class ChunkPayloadSmallException implements Exception {
  const ChunkPayloadSmallException();

  @override
  String toString() => 'packet is smaller than the header size';
}

/// Port of `payloadDataEndingFragmentBitmask` (chunk_payload_data.go:80).
const int payloadDataEndingFragmentBitmask = 1;

/// Port of `payloadDataBeginingFragmentBitmask` (chunk_payload_data.go:81).
const int payloadDataBeginingFragmentBitmask = 2;

/// Port of `payloadDataUnorderedBitmask` (chunk_payload_data.go:82).
const int payloadDataUnorderedBitmask = 4;

/// Port of `payloadDataImmediateSACK` (chunk_payload_data.go:83).
const int payloadDataImmediateSack = 8;

/// Port of `payloadDataHeaderSize` (chunk_payload_data.go:85).
const int payloadDataHeaderSize = 12;

/// Port of `PayloadProtocolIdentifier` (chunk_payload_data.go:88) and its
/// constants (chunk_payload_data.go:92-99). Exported in Go (see this file's
/// doc comment).
final class PayloadProtocolIdentifier {
  const PayloadProtocolIdentifier._(this.value);

  /// The raw wire value (a Go `uint32`).
  final int value;

  static const PayloadProtocolIdentifier unknown = PayloadProtocolIdentifier._(
    0,
  );
  static const PayloadProtocolIdentifier webRtcDcep =
      PayloadProtocolIdentifier._(50);
  static const PayloadProtocolIdentifier webRtcString =
      PayloadProtocolIdentifier._(51);
  static const PayloadProtocolIdentifier webRtcBinary =
      PayloadProtocolIdentifier._(53);
  static const PayloadProtocolIdentifier webRtcStringEmpty =
      PayloadProtocolIdentifier._(56);
  static const PayloadProtocolIdentifier webRtcBinaryEmpty =
      PayloadProtocolIdentifier._(57);

  factory PayloadProtocolIdentifier.fromValue(int value) =>
      PayloadProtocolIdentifier._(value);

  @override
  bool operator ==(Object other) =>
      other is PayloadProtocolIdentifier && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `PayloadProtocolIdentifier.String` (chunk_payload_data.go:108-121).
  @override
  String toString() {
    switch (value) {
      case 50:
        return 'WebRTC DCEP';
      case 51:
        return 'WebRTC String';
      case 53:
        return 'WebRTC Binary';
      case 56:
        return 'WebRTC String (Empty)';
      case 57:
        return 'WebRTC Binary (Empty)';
      default:
        return 'Unknown Payload Protocol Identifier: $value';
    }
  }
}

/// Port of `chunkPayloadData` (chunk_payload_data.go:44-58), restricted to
/// the wire-format fields -- see this file's doc comment for the declared
/// gap.
final class ChunkPayloadData implements Chunk {
  ChunkPayloadData({
    this.unordered = false,
    this.beginningFragment = false,
    this.endingFragment = false,
    this.immediateSack = false,
    this.tsn = 0,
    this.streamIdentifier = 0,
    this.streamSequenceNumber = 0,
    this.payloadType = PayloadProtocolIdentifier.unknown,
    Uint8List? userData,
    this.head,
  }) : userData = userData ?? Uint8List(0),
       header = ChunkHeader(
         typ: ChunkType.payloadData,
         flags: 0,
         raw: Uint8List(0),
       );

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkPayloadData.unordered` (chunk_payload_data.go:47).
  bool unordered;

  /// Port of `chunkPayloadData.beginningFragment` (chunk_payload_data.go:48).
  bool beginningFragment;

  /// Port of `chunkPayloadData.endingFragment` (chunk_payload_data.go:49).
  bool endingFragment;

  /// Port of `chunkPayloadData.immediateSack` (chunk_payload_data.go:50).
  bool immediateSack;

  /// Port of `chunkPayloadData.tsn` (chunk_payload_data.go:52).
  int tsn;

  /// Port of `chunkPayloadData.streamIdentifier` (chunk_payload_data.go:53).
  int streamIdentifier;

  /// Port of `chunkPayloadData.streamSequenceNumber` (chunk_payload_data.go:54).
  int streamSequenceNumber;

  /// Port of `chunkPayloadData.payloadType` (chunk_payload_data.go:55).
  PayloadProtocolIdentifier payloadType;

  /// Port of `chunkPayloadData.userData` (chunk_payload_data.go:56).
  Uint8List userData;

  /// Port of `chunkPayloadData.acked` (chunk_payload_data.go:64): whether
  /// this data chunk was acknowledged (received by peer).
  bool acked = false;

  /// Port of `chunkPayloadData.missIndicator` (chunk_payload_data.go:65).
  int missIndicator = 0;

  /// Port of `chunkPayloadData.since` (chunk_payload_data.go:68): set the
  /// first time this chunk is sent, used to calculate RTT and partial
  /// reliability's `ReliabilityTypeTimed`. `null` is this port's stand-in
  /// for Go's `time.Time{}` zero value -- see this file's doc comment.
  DateTime? since;

  /// Port of `chunkPayloadData.nSent` (chunk_payload_data.go:69): number of
  /// transmissions made for this chunk.
  int nSent = 0;

  /// Port of `chunkPayloadData._abandoned` (chunk_payload_data.go:70).
  bool _abandonedFlag = false;

  /// Port of `chunkPayloadData._allInflight` (chunk_payload_data.go:71):
  /// valid only with the first fragment.
  bool _allInflightFlag = false;

  /// Port of `chunkPayloadData.retransmit` (chunk_payload_data.go:75): set
  /// when the T1-RTX timeout occurred and this chunk is still in the
  /// inflight queue.
  bool retransmit = false;

  /// Port of `chunkPayloadData.head` (chunk_payload_data.go:77): link to
  /// the head of the fragment.
  ChunkPayloadData? head;

  /// Port of `chunkPayloadData.abandoned` (chunk_payload_data.go:186-192).
  bool abandoned() {
    final h = head;
    if (h != null) {
      return h._abandonedFlag && h._allInflightFlag;
    }
    return _abandonedFlag && _allInflightFlag;
  }

  /// Port of `chunkPayloadData.setAbandoned` (chunk_payload_data.go:194-201).
  void setAbandoned(bool abandonedValue) {
    final h = head;
    if (h != null) {
      h._abandonedFlag = abandonedValue;
      return;
    }
    _abandonedFlag = abandonedValue;
  }

  /// Port of `chunkPayloadData.setAllInflight` (chunk_payload_data.go:203-211).
  void setAllInflight() {
    if (endingFragment) {
      final h = head;
      if (h != null) {
        h._allInflightFlag = true;
      } else {
        _allInflightFlag = true;
      }
    }
  }

  /// Port of `chunkPayloadData.isFragmented` (chunk_payload_data.go:213-215).
  bool isFragmented() => !(head == null && beginningFragment && endingFragment);

  /// Port of `chunkPayloadData.unmarshal` (chunk_payload_data.go:123-141).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);

    immediateSack = header.flags & payloadDataImmediateSack != 0;
    unordered = header.flags & payloadDataUnorderedBitmask != 0;
    beginningFragment = header.flags & payloadDataBeginingFragmentBitmask != 0;
    endingFragment = header.flags & payloadDataEndingFragmentBitmask != 0;

    if (header.raw.length < payloadDataHeaderSize) {
      throw const ChunkPayloadSmallException();
    }
    final view = ByteData.sublistView(header.raw);
    tsn = view.getUint32(0, Endian.big);
    streamIdentifier = view.getUint16(4, Endian.big);
    streamSequenceNumber = view.getUint16(6, Endian.big);
    payloadType = PayloadProtocolIdentifier.fromValue(
      view.getUint32(8, Endian.big),
    );
    userData = Uint8List.sublistView(header.raw, payloadDataHeaderSize);
  }

  /// Port of `chunkPayloadData.marshal` (chunk_payload_data.go:143-170).
  @override
  Uint8List marshal() {
    final payRaw = Uint8List(payloadDataHeaderSize + userData.length);
    final view = ByteData.sublistView(payRaw);
    view.setUint32(0, tsn, Endian.big);
    view.setUint16(4, streamIdentifier & 0xFFFF, Endian.big);
    view.setUint16(6, streamSequenceNumber & 0xFFFF, Endian.big);
    view.setUint32(8, payloadType.value, Endian.big);
    payRaw.setRange(payloadDataHeaderSize, payRaw.length, userData);

    var flags = 0;
    if (endingFragment) {
      flags = 1;
    }
    if (beginningFragment) {
      flags |= 1 << 1;
    }
    if (unordered) {
      flags |= 1 << 2;
    }
    if (immediateSack) {
      flags |= 1 << 3;
    }

    header.flags = flags;
    header.typ = ChunkType.payloadData;
    header.raw = payRaw;
    return header.marshal();
  }

  /// Port of `chunkPayloadData.check` (chunk_payload_data.go:172-174).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkPayloadData.String` (chunk_payload_data.go:177-179).
  @override
  String toString() => '$header\n$tsn';
}
