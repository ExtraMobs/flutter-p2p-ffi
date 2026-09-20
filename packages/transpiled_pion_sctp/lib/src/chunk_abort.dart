// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_abort.go` (github.com/pion/sctp): [ChunkAbort], the SCTP
/// ABORT chunk (type 6, RFC 4960 section-3.3.7), which carries zero or more
/// [ErrorCause]s explaining why the association is being closed.
///
/// `chunkAbort` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkAbort] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'error_cause.dart';

/// Port of `ErrChunkTypeNotAbort` (chunk_abort.go:33-35).
final class ChunkTypeNotAbortException implements Exception {
  const ChunkTypeNotAbortException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type ABORT: actually is $actual';
}

/// Port of `ErrBuildAbortChunkFailed` (chunk_abort.go:36), wrapping the
/// error `buildErrorCause` raised.
final class BuildAbortChunkFailedException implements Exception {
  const BuildAbortChunkFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed build Abort Chunk: $cause';
}

/// Port of `chunkAbort` (chunk_abort.go:29-32).
final class ChunkAbort implements Chunk {
  ChunkAbort({List<ErrorCause>? errorCauses})
    : errorCauses = errorCauses ?? <ErrorCause>[],
      header = ChunkHeader(typ: ChunkType.abort, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkAbort.errorCauses` (chunk_abort.go:31).
  List<ErrorCause> errorCauses;

  /// Port of `chunkAbort.unmarshal` (chunk_abort.go:38-59).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.abort) {
      throw ChunkTypeNotAbortException(header.typ);
    }

    var offset = chunkHeaderSize;
    final causes = <ErrorCause>[];
    while (true) {
      if (raw.length - offset < 4) {
        break;
      }

      final ErrorCause e;
      try {
        e = buildErrorCause(Uint8List.sublistView(raw, offset));
      } on Object catch (err) {
        throw BuildAbortChunkFailedException(err);
      }

      offset += e.length();
      causes.add(e);
    }
    errorCauses = causes;
  }

  /// Port of `chunkAbort.marshal` (chunk_abort.go:61-73).
  @override
  Uint8List marshal() {
    header.typ = ChunkType.abort;
    header.flags = 0x00;
    final out = BytesBuilder(copy: false);
    for (final ec in errorCauses) {
      out.add(ec.marshal());
    }
    header.raw = out.toBytes();
    return header.marshal();
  }

  /// Port of `chunkAbort.check` (chunk_abort.go:75-77).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkAbort.String` (chunk_abort.go:80-88).
  @override
  String toString() {
    var res = header.toString();
    for (final cause in errorCauses) {
      res += '\n - $cause';
    }
    return res;
  }
}
