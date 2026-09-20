// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_shutdown_complete.go` (github.com/pion/sctp):
/// [ChunkShutdownComplete], the SCTP SHUTDOWN-COMPLETE chunk (type 14,
/// RFC 4960 section-3.3.10), which carries no value beyond its 4-byte
/// header.
///
/// `chunkShutdownComplete` is unexported in Go; see chunk.dart's file-level
/// doc comment for why [ChunkShutdownComplete] is still public within
/// `lib/src`, and chunkheader.dart's for the `header`-field composition
/// pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkTypeNotShutdownComplete` (chunk_shutdown_complete.go:19-21).
final class ChunkTypeNotShutdownCompleteException implements Exception {
  const ChunkTypeNotShutdownCompleteException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type SHUTDOWN-COMPLETE: actually is $actual';
}

/// Port of `chunkShutdownComplete` (chunk_shutdown_complete.go:12-14).
final class ChunkShutdownComplete implements Chunk {
  ChunkShutdownComplete() : header = ChunkHeader(typ: ChunkType.shutdownComplete, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkShutdownComplete.unmarshal` (chunk_shutdown_complete.go:23-31).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.shutdownComplete) {
      throw ChunkTypeNotShutdownCompleteException(header.typ);
    }
  }

  /// Port of `chunkShutdownComplete.marshal` (chunk_shutdown_complete.go:33-37).
  @override
  Uint8List marshal() {
    header.typ = ChunkType.shutdownComplete;
    return header.marshal();
  }

  /// Port of `chunkShutdownComplete.check` (chunk_shutdown_complete.go:39-41).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkShutdownComplete.String` (chunk_shutdown_complete.go:44-46).
  @override
  String toString() => header.toString();
}
