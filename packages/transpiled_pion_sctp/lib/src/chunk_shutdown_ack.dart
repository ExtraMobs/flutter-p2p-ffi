// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_shutdown_ack.go` (github.com/pion/sctp):
/// [ChunkShutdownAck], the SCTP SHUTDOWN-ACK chunk (type 8, RFC 4960
/// section-3.3.9), which carries no value beyond its 4-byte header.
///
/// `chunkShutdownAck` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkShutdownAck] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkTypeNotShutdownAck` (chunk_shutdown_ack.go:19-21).
final class ChunkTypeNotShutdownAckException implements Exception {
  const ChunkTypeNotShutdownAckException(this.actual);

  final ChunkType actual;

  @override
  String toString() =>
      'ChunkType is not of type SHUTDOWN-ACK: actually is $actual';
}

/// Port of `chunkShutdownAck` (chunk_shutdown_ack.go:12-14).
final class ChunkShutdownAck implements Chunk {
  ChunkShutdownAck()
    : header = ChunkHeader(
        typ: ChunkType.shutdownAck,
        flags: 0,
        raw: Uint8List(0),
      );

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkShutdownAck.unmarshal` (chunk_shutdown_ack.go:23-31).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.shutdownAck) {
      throw ChunkTypeNotShutdownAckException(header.typ);
    }
  }

  /// Port of `chunkShutdownAck.marshal` (chunk_shutdown_ack.go:33-37).
  @override
  Uint8List marshal() {
    header.typ = ChunkType.shutdownAck;
    return header.marshal();
  }

  /// Port of `chunkShutdownAck.check` (chunk_shutdown_ack.go:39-41).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkShutdownAck.String` (chunk_shutdown_ack.go:44-46).
  @override
  String toString() => header.toString();
}
