// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `error_cause_unrecognized_chunk_type.go` (github.com/pion/sctp):
/// [ErrorCauseUnrecognizedChunkType], the Unrecognized Chunk Type error
/// cause (RFC 4960 section-3.3.10.6), which echoes back the raw bytes of a
/// chunk the receiver didn't recognize.
///
/// `errorCauseUnrecognizedChunkType` is unexported in Go; see
/// error_cause_header.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'error_cause.dart';
import 'error_cause_header.dart';

/// Port of `errorCauseUnrecognizedChunkType`
/// (error_cause_unrecognized_chunk_type.go:7-10).
final class ErrorCauseUnrecognizedChunkType implements ErrorCause {
  ErrorCauseUnrecognizedChunkType({Uint8List? unrecognizedChunk})
    : unrecognizedChunk = unrecognizedChunk ?? Uint8List(0),
      header = ErrorCauseHeader(code: ErrorCauseCode.unrecognizedChunkType);

  /// Composition standing in for Go's embedded `errorCauseHeader`.
  ErrorCauseHeader header;

  /// Port of `errorCauseUnrecognizedChunkType.unrecognizedChunk`
  /// (error_cause_unrecognized_chunk_type.go:9).
  Uint8List unrecognizedChunk;

  /// Port of `errorCauseUnrecognizedChunkType.marshal`
  /// (error_cause_unrecognized_chunk_type.go:12-17).
  @override
  Uint8List marshal() {
    header.code = ErrorCauseCode.unrecognizedChunkType;
    header.raw = unrecognizedChunk;
    return header.marshal();
  }

  /// Port of `errorCauseUnrecognizedChunkType.unmarshal`
  /// (error_cause_unrecognized_chunk_type.go:19-27).
  @override
  void unmarshal(Uint8List raw) {
    header.unmarshal(raw);
    unrecognizedChunk = header.raw;
  }

  @override
  int length() => header.length();

  @override
  ErrorCauseCode errorCauseCode() => header.errorCauseCode();

  /// Port of `errorCauseUnrecognizedChunkType.String`
  /// (error_cause_unrecognized_chunk_type.go:30-32).
  @override
  String toString() => header.toString();
}
