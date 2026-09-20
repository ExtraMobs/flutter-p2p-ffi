// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `error_cause_protocol_violation.go` (github.com/pion/sctp):
/// [ErrorCauseProtocolViolation], the Protocol Violation error cause
/// (RFC 4960 section-3.3.10.13), included in ABORT chunks sent for
/// violations not covered by the other error causes.
///
/// `errorCauseProtocolViolation` is unexported in Go; see
/// error_cause_header.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'error_cause.dart';
import 'error_cause_header.dart';

/// Port of `ErrProtocolViolationUnmarshal`
/// (error_cause_protocol_violation.go:31-33), wrapping the
/// [InvalidSctpChunkException] `errorCauseHeader.unmarshal` can raise.
final class ProtocolViolationUnmarshalException implements Exception {
  const ProtocolViolationUnmarshalException(this.cause);

  final Object cause;

  @override
  String toString() => 'unable to unmarshal Protocol Violation error: $cause';
}

/// Port of `errorCauseProtocolViolation` (error_cause_protocol_violation.go:27-30).
final class ErrorCauseProtocolViolation implements ErrorCause {
  ErrorCauseProtocolViolation({Uint8List? additionalInformation})
    : additionalInformation = additionalInformation ?? Uint8List(0),
      header = ErrorCauseHeader(code: ErrorCauseCode.protocolViolation);

  /// Composition standing in for Go's embedded `errorCauseHeader`.
  ErrorCauseHeader header;

  /// Port of `errorCauseProtocolViolation.additionalInformation`
  /// (error_cause_protocol_violation.go:29).
  Uint8List additionalInformation;

  /// Port of `errorCauseProtocolViolation.marshal`
  /// (error_cause_protocol_violation.go:35-39).
  @override
  Uint8List marshal() {
    header.raw = additionalInformation;
    return header.marshal();
  }

  /// Port of `errorCauseProtocolViolation.unmarshal`
  /// (error_cause_protocol_violation.go:41-49).
  @override
  void unmarshal(Uint8List raw) {
    try {
      header.unmarshal(raw);
    } on Object catch (e) {
      throw ProtocolViolationUnmarshalException(e);
    }
    additionalInformation = header.raw;
  }

  @override
  int length() => header.length();

  @override
  ErrorCauseCode errorCauseCode() => header.errorCauseCode();

  /// Port of `errorCauseProtocolViolation.String`
  /// (error_cause_protocol_violation.go:52-54).
  @override
  String toString() => '$header: $additionalInformation';
}
