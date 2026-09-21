// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_selective_ack.go` (github.com/pion/sctp):
/// [ChunkSelectiveAck], the SCTP SACK chunk (type 3, RFC 4960
/// section-3.3.4), and [GapAckBlock], one of its gap-ack ranges.
///
/// `chunkSelectiveAck` and `gapAckBlock` are unexported in Go; see
/// chunk.dart's file-level doc comment for why [ChunkSelectiveAck] is still
/// public within `lib/src`, and chunkheader.dart's for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkTypeNotSack` (chunk_selective_ack.go:41).
final class ChunkTypeNotSackException implements Exception {
  const ChunkTypeNotSackException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type SACK: actually is $actual';
}

/// Port of `ErrSackSizeNotLargeEnoughInfo` (chunk_selective_ack.go:42).
final class SackSizeNotLargeEnoughInfoException implements Exception {
  const SackSizeNotLargeEnoughInfoException(this.remaining, this.needed);

  final int remaining;
  final int needed;

  @override
  String toString() =>
      'SACK Chunk size is not large enough to contain header: $remaining remaining, needs $needed bytes';
}

/// Port of `ErrSackSizeNotMatchPredicted` (chunk_selective_ack.go:43).
final class SackSizeNotMatchPredictedException implements Exception {
  const SackSizeNotMatchPredictedException();

  @override
  String toString() =>
      'SACK Chunk size does not match predicted amount from header values';
}

/// Port of `selectiveAckHeaderSize` (chunk_selective_ack.go:60-62).
const int selectiveAckHeaderSize = 12;

/// Port of `gapAckBlock` (chunk_selective_ack.go:38-40).
final class GapAckBlock {
  GapAckBlock({this.start = 0, this.end = 0});

  /// Port of `gapAckBlock.start` (chunk_selective_ack.go:39).
  int start;

  /// Port of `gapAckBlock.end` (chunk_selective_ack.go:40).
  int end;

  /// Port of `gapAckBlock.String` (chunk_selective_ack.go:47-49).
  @override
  String toString() => '$start - $end';
}

/// Port of `chunkSelectiveAck` (chunk_selective_ack.go:52-58).
final class ChunkSelectiveAck implements Chunk {
  ChunkSelectiveAck({
    this.cumulativeTsnAck = 0,
    this.advertisedReceiverWindowCredit = 0,
    List<GapAckBlock>? gapAckBlocks,
    List<int>? duplicateTsn,
  }) : gapAckBlocks = gapAckBlocks ?? <GapAckBlock>[],
       duplicateTsn = duplicateTsn ?? <int>[],
       header = ChunkHeader(typ: ChunkType.sack, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkSelectiveAck.cumulativeTSNAck` (chunk_selective_ack.go:54).
  int cumulativeTsnAck;

  /// Port of `chunkSelectiveAck.advertisedReceiverWindowCredit`
  /// (chunk_selective_ack.go:55).
  int advertisedReceiverWindowCredit;

  /// Port of `chunkSelectiveAck.gapAckBlocks` (chunk_selective_ack.go:56).
  List<GapAckBlock> gapAckBlocks;

  /// Port of `chunkSelectiveAck.duplicateTSN` (chunk_selective_ack.go:57), a
  /// Go `[]uint32`.
  List<int> duplicateTsn;

  /// Port of `chunkSelectiveAck.unmarshal` (chunk_selective_ack.go:64-96).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);

    if (header.typ != ChunkType.sack) {
      throw ChunkTypeNotSackException(header.typ);
    }

    if (header.raw.length < selectiveAckHeaderSize) {
      throw SackSizeNotLargeEnoughInfoException(
        header.raw.length,
        selectiveAckHeaderSize,
      );
    }

    final view = ByteData.sublistView(header.raw);
    cumulativeTsnAck = view.getUint32(0, Endian.big);
    advertisedReceiverWindowCredit = view.getUint32(4, Endian.big);
    final numGapAckBlocks = view.getUint16(8, Endian.big);
    final numDuplicateTsn = view.getUint16(10, Endian.big);

    if (header.raw.length !=
        selectiveAckHeaderSize +
            (4 * numGapAckBlocks + (4 * numDuplicateTsn))) {
      throw const SackSizeNotMatchPredictedException();
    }

    var offset = selectiveAckHeaderSize;
    final blocks = <GapAckBlock>[];
    for (var i = 0; i < numGapAckBlocks; i++) {
      blocks.add(
        GapAckBlock(
          start: view.getUint16(offset, Endian.big),
          end: view.getUint16(offset + 2, Endian.big),
        ),
      );
      offset += 4;
    }
    gapAckBlocks = blocks;

    final duplicates = <int>[];
    for (var i = 0; i < numDuplicateTsn; i++) {
      duplicates.add(view.getUint32(offset, Endian.big));
      offset += 4;
    }
    duplicateTsn = duplicates;
  }

  /// Port of `chunkSelectiveAck.marshal` (chunk_selective_ack.go:98-116).
  @override
  Uint8List marshal() {
    final sackRaw = Uint8List(
      selectiveAckHeaderSize +
          (4 * gapAckBlocks.length + (4 * duplicateTsn.length)),
    );
    final view = ByteData.sublistView(sackRaw);
    view.setUint32(0, cumulativeTsnAck, Endian.big);
    view.setUint32(4, advertisedReceiverWindowCredit, Endian.big);
    view.setUint16(8, gapAckBlocks.length & 0xFFFF, Endian.big);
    view.setUint16(10, duplicateTsn.length & 0xFFFF, Endian.big);

    var offset = selectiveAckHeaderSize;
    for (final g in gapAckBlocks) {
      view.setUint16(offset, g.start & 0xFFFF, Endian.big);
      view.setUint16(offset + 2, g.end & 0xFFFF, Endian.big);
      offset += 4;
    }
    for (final t in duplicateTsn) {
      view.setUint32(offset, t, Endian.big);
      offset += 4;
    }

    header.typ = ChunkType.sack;
    header.raw = sackRaw;
    return header.marshal();
  }

  /// Port of `chunkSelectiveAck.check` (chunk_selective_ack.go:118-120).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkSelectiveAck.String` (chunk_selective_ack.go:123-133).
  @override
  String toString() {
    var res =
        'SACK cumTsnAck=$cumulativeTsnAck arwnd=$advertisedReceiverWindowCredit dupTsn=$duplicateTsn';
    for (final gap in gapAckBlocks) {
      res = '$res\n gap ack: $gap';
    }
    return res;
  }
}
