// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `error_cause_header.go` (github.com/pion/sctp):
/// [ErrorCauseHeader], the common 4-byte TLV header shared by every
/// `error_cause_*.go` type.
///
/// `errorCauseHeader` is unexported in Go; every concrete `error_cause_*.go`
/// type embeds it. Dart has no struct embedding, so each concrete
/// `ErrorCause*` type in this package instead holds a `header` field of
/// type [ErrorCauseHeader] and delegates to it explicitly, mirroring
/// paramheader.dart's `header`-field composition pattern for [ParamHeader].
library;

import 'dart:typed_data';

import 'error_cause.dart';

/// Port of `ErrInvalidSCTPChunk` (error_cause_header.go:20-21).
final class InvalidSctpChunkException implements Exception {
  const InvalidSctpChunkException();

  @override
  String toString() => 'invalid SCTP chunk';
}

/// Port of `errorCauseHeaderLength` (error_cause_header.go:17-19).
const int errorCauseHeaderLength = 4;

/// Port of `errorCauseHeader` (error_cause_header.go:12-16).
final class ErrorCauseHeader {
  ErrorCauseHeader({required this.code, this.len = 0, Uint8List? raw})
    : raw = raw ?? Uint8List(0);

  /// Port of `errorCauseHeader.code` (error_cause_header.go:13).
  ErrorCauseCode code;

  /// Port of `errorCauseHeader.len` (error_cause_header.go:14).
  int len;

  /// Port of `errorCauseHeader.raw` (error_cause_header.go:15).
  Uint8List raw;

  /// Port of `errorCauseHeader.marshal` (error_cause_header.go:25-33).
  Uint8List marshal() {
    len = raw.length + errorCauseHeaderLength;
    final out = Uint8List(len);
    final view = ByteData.sublistView(out);
    view.setUint16(0, code.value & 0xFFFF, Endian.big);
    view.setUint16(2, len & 0xFFFF, Endian.big);
    out.setRange(errorCauseHeaderLength, len, raw);
    return out;
  }

  /// Port of `errorCauseHeader.unmarshal` (error_cause_header.go:35-45).
  void unmarshal(Uint8List raw) {
    final view = ByteData.sublistView(raw, 0, 4);
    code = ErrorCauseCode.fromValue(view.getUint16(0, Endian.big));
    len = view.getUint16(2, Endian.big);
    if (len < errorCauseHeaderLength || len > raw.length) {
      throw const InvalidSctpChunkException();
    }
    final valueLength = len - errorCauseHeaderLength;
    this.raw = Uint8List.sublistView(
      raw,
      errorCauseHeaderLength,
      errorCauseHeaderLength + valueLength,
    );
  }

  /// Port of `errorCauseHeader.length` (error_cause_header.go:47-49).
  int length() => len;

  /// Port of `errorCauseHeader.errorCauseCode` (error_cause_header.go:51-53).
  ErrorCauseCode errorCauseCode() => code;

  /// Port of `errorCauseHeader.String` (error_cause_header.go:56-58).
  @override
  String toString() => code.toString();
}
