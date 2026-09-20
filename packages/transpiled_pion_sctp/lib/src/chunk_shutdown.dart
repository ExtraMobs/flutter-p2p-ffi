// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_shutdown.go` (github.com/pion/sctp): [ChunkShutdown], the
/// SCTP SHUTDOWN chunk (type 7, RFC 4960 section-3.3.8), which carries the
/// cumulative TSN ack.
///
/// `chunkShutdown` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkShutdown] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrInvalidChunkSize` (chunk_shutdown.go:29-31).
final class InvalidChunkSizeException implements Exception {
  const InvalidChunkSizeException();

  @override
  String toString() => 'invalid chunk size';
}

/// Port of `ErrChunkTypeNotShutdown` (chunk_shutdown.go:32).
final class ChunkTypeNotShutdownException implements Exception {
  const ChunkTypeNotShutdownException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type SHUTDOWN: actually is $actual';
}

/// Port of `cumulativeTSNAckLength` (chunk_shutdown.go:25-27).
const int cumulativeTsnAckLength = 4;

/// Port of `chunkShutdown` (chunk_shutdown.go:20-23).
final class ChunkShutdown implements Chunk {
  ChunkShutdown({this.cumulativeTsnAck = 0}) : header = ChunkHeader(typ: ChunkType.shutdown, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkShutdown.cumulativeTSNAck` (chunk_shutdown.go:22).
  int cumulativeTsnAck;

  /// Port of `chunkShutdown.unmarshal` (chunk_shutdown.go:34-48).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.shutdown) {
      throw ChunkTypeNotShutdownException(header.typ);
    }
    if (header.raw.length != cumulativeTsnAckLength) {
      throw const InvalidChunkSizeException();
    }
    cumulativeTsnAck = ByteData.sublistView(header.raw).getUint32(0, Endian.big);
  }

  /// Port of `chunkShutdown.marshal` (chunk_shutdown.go:50-58).
  @override
  Uint8List marshal() {
    final out = Uint8List(cumulativeTsnAckLength);
    ByteData.sublistView(out).setUint32(0, cumulativeTsnAck, Endian.big);
    header.typ = ChunkType.shutdown;
    header.raw = out;
    return header.marshal();
  }

  /// Port of `chunkShutdown.check` (chunk_shutdown.go:60-62).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkShutdown.String` (chunk_shutdown.go:65-67).
  @override
  String toString() => header.toString();
}
