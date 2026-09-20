// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_init.go` (github.com/pion/sctp): [ChunkInit], the SCTP
/// INIT chunk (type 1, RFC 4960 section-3.3.2).
///
/// `chunkInit` is unexported in Go and embeds both `chunkHeader` and
/// `chunkInitCommon`; see chunk_init_common.dart's file-level doc comment
/// for the `header` + `common` composition pattern used here instead of
/// Go's double embedding.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunk_init_common.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'paramheader.dart';

/// Port of `ErrChunkTypeNotTypeInit` (chunk_init.go:30).
final class ChunkTypeNotTypeInitException implements Exception {
  const ChunkTypeNotTypeInitException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type INIT: actually is $actual';
}

/// Port of `ErrChunkValueNotLongEnough` (chunk_init.go:31).
final class ChunkValueNotLongEnoughException implements Exception {
  const ChunkValueNotLongEnoughException(this.expected, this.actual);

  final int expected;
  final int actual;

  @override
  String toString() => "chunk Value isn't long enough for mandatory parameters exp: $expected actual: $actual";
}

/// Port of `ErrChunkTypeInitFlagZero` (chunk_init.go:32).
final class ChunkTypeInitFlagZeroException implements Exception {
  const ChunkTypeInitFlagZeroException();

  @override
  String toString() => 'ChunkType of type INIT flags must be all 0';
}

/// Port of `ErrChunkTypeInitUnmarshalFailed` (chunk_init.go:33), wrapping
/// the error `chunkInitCommon.unmarshal` raised.
final class ChunkTypeInitUnmarshalFailedException implements Exception {
  const ChunkTypeInitUnmarshalFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to unmarshal INIT body: $cause';
}

/// Port of `ErrChunkTypeInitMarshalFailed` (chunk_init.go:34), wrapping the
/// error `chunkInitCommon.marshal` raised.
final class ChunkTypeInitMarshalFailedException implements Exception {
  const ChunkTypeInitMarshalFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed marshaling INIT common data: $cause';
}

/// Port of `ErrChunkTypeInitInitateTagZero` (chunk_init.go:35).
final class ChunkTypeInitInitateTagZeroException implements Exception {
  const ChunkTypeInitInitateTagZeroException();

  @override
  String toString() => 'ChunkType of type INIT ACK InitiateTag must not be 0';
}

/// Port of `ErrInitInboundStreamRequestZero` (chunk_init.go:36).
final class InitInboundStreamRequestZeroException implements Exception {
  const InitInboundStreamRequestZeroException();

  @override
  String toString() => 'INIT ACK inbound stream request must be > 0';
}

/// Port of `ErrInitOutboundStreamRequestZero` (chunk_init.go:37).
final class InitOutboundStreamRequestZeroException implements Exception {
  const InitOutboundStreamRequestZeroException();

  @override
  String toString() => 'INIT ACK outbound stream request must be > 0';
}

/// Port of `ErrInitAdvertisedReceiver1500` (chunk_init.go:38).
final class InitAdvertisedReceiver1500Exception implements Exception {
  const InitAdvertisedReceiver1500Exception();

  @override
  String toString() => 'INIT ACK Advertised Receiver Window Credit (a_rwnd) must be >= 1500';
}

/// Port of `ErrInitUnknownParam` (chunk_init.go:39).
final class InitUnknownParamException implements Exception {
  const InitUnknownParamException();

  @override
  String toString() => 'INIT with unknown param';
}

/// Port of `chunkInit` (chunk_init.go:26-28).
final class ChunkInit implements Chunk {
  ChunkInit({ChunkInitCommon? common})
    : common = common ?? ChunkInitCommon(),
      header = ChunkHeader(typ: ChunkType.init, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Composition standing in for Go's embedded `chunkInitCommon`.
  ChunkInitCommon common;

  /// Port of `chunkInit.unmarshal` (chunk_init.go:44-64).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);

    if (header.typ != ChunkType.init) {
      throw ChunkTypeNotTypeInitException(header.typ);
    } else if (header.raw.length < initChunkMinLength) {
      throw ChunkValueNotLongEnoughException(initChunkMinLength, header.raw.length);
    }

    // The Chunk Flags field in INIT is reserved, and all bits in it should
    // be set to 0 by the sender and ignored by the receiver. The sequence
    // of parameters within an INIT can be processed in any order.
    if (header.flags != 0) {
      throw const ChunkTypeInitFlagZeroException();
    }

    try {
      common.unmarshal(header.raw);
    } on Object catch (e) {
      throw ChunkTypeInitUnmarshalFailedException(e);
    }
  }

  /// Port of `chunkInit.marshal` (chunk_init.go:66-75).
  @override
  Uint8List marshal() {
    final Uint8List initShared;
    try {
      initShared = common.marshal();
    } on Object catch (e) {
      throw ChunkTypeInitMarshalFailedException(e);
    }

    header.typ = ChunkType.init;
    header.raw = initShared;
    return header.marshal();
  }

  /// Port of `chunkInit.check` (chunk_init.go:77-134).
  @override
  bool check() {
    // The receiver of the INIT (the responding end) records the value of
    // the Initiate Tag parameter. This value MUST be placed into the
    // Verification Tag field of every SCTP packet that the receiver of
    // the INIT transmits within this association.
    //
    // The Initiate Tag is allowed to have any value except 0.
    //
    // If the value of the Initiate Tag in a received INIT chunk is found
    // to be 0, the receiver MUST treat it as an error and close the
    // association by transmitting an ABORT.
    if (common.initiateTag == 0) {
      throw const ChunkTypeInitInitateTagZeroException();
    }

    // Defines the maximum number of streams the sender of this INIT
    // chunk allows the peer end to create in this association. The
    // value 0 MUST NOT be used.
    if (common.numInboundStreams == 0) {
      throw const InitInboundStreamRequestZeroException();
    }

    // Defines the number of outbound streams the sender of this INIT
    // chunk wishes to create in this association. The value of 0 MUST
    // NOT be used.
    if (common.numOutboundStreams == 0) {
      throw const InitOutboundStreamRequestZeroException();
    }

    // An SCTP receiver MUST be able to receive a minimum of 1500 bytes in
    // one SCTP packet. This means that an SCTP endpoint MUST NOT indicate
    // less than 1500 bytes in its initial a_rwnd sent in the INIT or INIT
    // ACK.
    if (common.advertisedReceiverWindowCredit < 1500) {
      throw const InitAdvertisedReceiver1500Exception();
    }

    for (final p in common.unrecognizedParams) {
      if (p.unrecognizedAction == ParamHeaderUnrecognizedAction.stop ||
          p.unrecognizedAction == ParamHeaderUnrecognizedAction.stopAndReport) {
        throw const InitUnknownParamException();
      }
    }

    return false;
  }

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkInit.String` (chunk_init.go:137-139).
  @override
  String toString() => '$header\n$common';
}
