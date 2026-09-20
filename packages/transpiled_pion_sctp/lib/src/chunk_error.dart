// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_error.go` (github.com/pion/sctp): [ChunkError], the SCTP
/// ERROR chunk (type 9, RFC 4960 section-3.3.10), which carries one or more
/// [ErrorCause]s reporting a non-fatal condition.
///
/// `chunkError` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkError] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'error_cause.dart';

/// Port of `ErrChunkTypeNotCtError` (chunk_error.go:33-35).
final class ChunkTypeNotCtErrorException implements Exception {
  const ChunkTypeNotCtErrorException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type ctError, actually is $actual';
}

/// Port of `ErrBuildErrorChunkFailed` (chunk_error.go:36), wrapping the
/// error `buildErrorCause` raised.
final class BuildErrorChunkFailedException implements Exception {
  const BuildErrorChunkFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed build Error Chunk: $cause';
}

/// Port of `chunkError` (chunk_error.go:29-32).
final class ChunkError implements Chunk {
  ChunkError({List<ErrorCause>? errorCauses})
    : errorCauses = errorCauses ?? <ErrorCause>[],
      header = ChunkHeader(typ: ChunkType.error, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkError.errorCauses` (chunk_error.go:31).
  List<ErrorCause> errorCauses;

  /// Port of `chunkError.unmarshal` (chunk_error.go:38-59).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.error) {
      throw ChunkTypeNotCtErrorException(header.typ);
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
        throw BuildErrorChunkFailedException(err);
      }

      offset += e.length();
      causes.add(e);
    }
    errorCauses = causes;
  }

  /// Port of `chunkError.marshal` (chunk_error.go:61-73).
  @override
  Uint8List marshal() {
    header.typ = ChunkType.error;
    header.flags = 0x00;
    final out = BytesBuilder(copy: false);
    for (final ec in errorCauses) {
      out.add(ec.marshal());
    }
    header.raw = out.toBytes();
    return header.marshal();
  }

  /// Port of `chunkError.check` (chunk_error.go:75-77).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkError.String` (chunk_error.go:80-88).
  @override
  String toString() {
    var res = header.toString();
    for (final cause in errorCauses) {
      res += '\n - $cause';
    }
    return res;
  }
}
