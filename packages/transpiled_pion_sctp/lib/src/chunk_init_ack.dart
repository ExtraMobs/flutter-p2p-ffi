// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_init_ack.go` (github.com/pion/sctp): [ChunkInitAck], the
/// SCTP INIT-ACK chunk (type 2, RFC 4960 section-3.3.3).
///
/// `chunkInitAck` is unexported in Go and embeds both `chunkHeader` and
/// `chunkInitCommon`; see chunk_init_common.dart's file-level doc comment
/// for the `header` + `common` composition pattern used here instead of
/// Go's double embedding.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunk_init_common.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkTypeNotInitAck` (chunk_init_ack.go:31).
final class ChunkTypeNotInitAckException implements Exception {
  const ChunkTypeNotInitAckException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type INIT ACK: actually is $actual';
}

/// Port of `ErrChunkNotLongEnoughForParams` (chunk_init_ack.go:32).
final class ChunkNotLongEnoughForParamsException implements Exception {
  const ChunkNotLongEnoughForParamsException(this.expected, this.actual);

  final int expected;
  final int actual;

  @override
  String toString() =>
      "chunk Value isn't long enough for mandatory parameters exp: $expected actual: $actual";
}

/// Port of `ErrChunkTypeInitAckFlagZero` (chunk_init_ack.go:33).
final class ChunkTypeInitAckFlagZeroException implements Exception {
  const ChunkTypeInitAckFlagZeroException();

  @override
  String toString() => 'ChunkType of type INIT ACK flags must be all 0';
}

/// Port of `ErrInitAckUnmarshalFailed` (chunk_init_ack.go:34), wrapping the
/// error `chunkInitCommon.unmarshal` raised.
final class InitAckUnmarshalFailedException implements Exception {
  const InitAckUnmarshalFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to unmarshal INIT body: $cause';
}

/// Port of `ErrInitCommonDataMarshalFailed` (chunk_init_ack.go:35),
/// wrapping the error `chunkInitCommon.marshal` raised.
final class InitCommonDataMarshalFailedException implements Exception {
  const InitCommonDataMarshalFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed marshaling INIT common data: $cause';
}

/// Port of `ErrChunkTypeInitAckInitateTagZero` (chunk_init_ack.go:36).
final class ChunkTypeInitAckInitateTagZeroException implements Exception {
  const ChunkTypeInitAckInitateTagZeroException();

  @override
  String toString() => 'ChunkType of type INIT ACK InitiateTag must not be 0';
}

/// Port of `ErrInitAckInboundStreamRequestZero` (chunk_init_ack.go:37).
final class InitAckInboundStreamRequestZeroException implements Exception {
  const InitAckInboundStreamRequestZeroException();

  @override
  String toString() => 'INIT ACK inbound stream request must be > 0';
}

/// Port of `ErrInitAckOutboundStreamRequestZero` (chunk_init_ack.go:38).
final class InitAckOutboundStreamRequestZeroException implements Exception {
  const InitAckOutboundStreamRequestZeroException();

  @override
  String toString() => 'INIT ACK outbound stream request must be > 0';
}

/// Port of `ErrInitAckAdvertisedReceiver1500` (chunk_init_ack.go:39).
final class InitAckAdvertisedReceiver1500Exception implements Exception {
  const InitAckAdvertisedReceiver1500Exception();

  @override
  String toString() =>
      'INIT ACK Advertised Receiver Window Credit (a_rwnd) must be >= 1500';
}

/// Port of `chunkInitAck` (chunk_init_ack.go:27-29).
final class ChunkInitAck implements Chunk {
  ChunkInitAck({ChunkInitCommon? common})
    : common = common ?? ChunkInitCommon(),
      header = ChunkHeader(typ: ChunkType.initAck, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Composition standing in for Go's embedded `chunkInitCommon`.
  ChunkInitCommon common;

  /// Port of `chunkInitAck.unmarshal` (chunk_init_ack.go:44-64).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);

    if (header.typ != ChunkType.initAck) {
      throw ChunkTypeNotInitAckException(header.typ);
    } else if (header.raw.length < initChunkMinLength) {
      throw ChunkNotLongEnoughForParamsException(
        initChunkMinLength,
        header.raw.length,
      );
    }

    // The Chunk Flags field in INIT is reserved, and all bits in it should
    // be set to 0 by the sender and ignored by the receiver. The sequence
    // of parameters within an INIT can be processed in any order.
    if (header.flags != 0) {
      throw const ChunkTypeInitAckFlagZeroException();
    }

    try {
      common.unmarshal(header.raw);
    } on Object catch (e) {
      throw InitAckUnmarshalFailedException(e);
    }
  }

  /// Port of `chunkInitAck.marshal` (chunk_init_ack.go:66-75).
  @override
  Uint8List marshal() {
    final Uint8List initShared;
    try {
      initShared = common.marshal();
    } on Object catch (e) {
      throw InitCommonDataMarshalFailedException(e);
    }

    header.typ = ChunkType.initAck;
    header.raw = initShared;
    return header.marshal();
  }

  /// Port of `chunkInitAck.check` (chunk_init_ack.go:77-133).
  @override
  bool check() {
    // The receiver of the INIT ACK records the value of the Initiate Tag
    // parameter. This value MUST be placed into the Verification Tag
    // field of every SCTP packet that the INIT ACK receiver transmits
    // within this association.
    if (common.initiateTag == 0) {
      throw const ChunkTypeInitAckInitateTagZeroException();
    }

    // Defines the maximum number of streams the sender of this INIT ACK
    // chunk allows the peer end to create in this association. The
    // value 0 MUST NOT be used.
    if (common.numInboundStreams == 0) {
      throw const InitAckInboundStreamRequestZeroException();
    }

    // Defines the number of outbound streams the sender of this INIT ACK
    // chunk wishes to create in this association. The value of 0 MUST
    // NOT be used, and the value MUST NOT be greater than the MIS value
    // sent in the INIT chunk.
    if (common.numOutboundStreams == 0) {
      throw const InitAckOutboundStreamRequestZeroException();
    }

    // An SCTP receiver MUST be able to receive a minimum of 1500 bytes in
    // one SCTP packet. This means that an SCTP endpoint MUST NOT indicate
    // less than 1500 bytes in its initial a_rwnd sent in the INIT or INIT
    // ACK.
    if (common.advertisedReceiverWindowCredit < 1500) {
      throw const InitAckAdvertisedReceiver1500Exception();
    }

    return false;
  }

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkInitAck.String` (chunk_init_ack.go:136-138).
  @override
  String toString() => '$header\n$common';
}
