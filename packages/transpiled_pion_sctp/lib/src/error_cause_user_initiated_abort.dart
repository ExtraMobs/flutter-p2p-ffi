// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `error_cause_user_initiated_abort.go` (github.com/pion/sctp):
/// [ErrorCauseUserInitiatedAbort], the User Initiated Abort error cause
/// (RFC 4960 section-3.3.10.12), which carries an upper-layer-supplied
/// abort reason.
///
/// `errorCauseUserInitiatedAbort` is unexported in Go; see
/// error_cause_header.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'error_cause.dart';
import 'error_cause_header.dart';

/// Port of `errorCauseUserInitiatedAbort`
/// (error_cause_user_initiated_abort.go:19-22).
final class ErrorCauseUserInitiatedAbort implements ErrorCause {
  ErrorCauseUserInitiatedAbort({Uint8List? upperLayerAbortReason})
    : upperLayerAbortReason = upperLayerAbortReason ?? Uint8List(0),
      header = ErrorCauseHeader(code: ErrorCauseCode.userInitiatedAbort);

  /// Composition standing in for Go's embedded `errorCauseHeader`.
  ErrorCauseHeader header;

  /// Port of `errorCauseUserInitiatedAbort.upperLayerAbortReason`
  /// (error_cause_user_initiated_abort.go:21).
  Uint8List upperLayerAbortReason;

  /// Port of `errorCauseUserInitiatedAbort.marshal`
  /// (error_cause_user_initiated_abort.go:24-29).
  @override
  Uint8List marshal() {
    header.code = ErrorCauseCode.userInitiatedAbort;
    header.raw = upperLayerAbortReason;
    return header.marshal();
  }

  /// Port of `errorCauseUserInitiatedAbort.unmarshal`
  /// (error_cause_user_initiated_abort.go:31-39).
  @override
  void unmarshal(Uint8List raw) {
    header.unmarshal(raw);
    upperLayerAbortReason = header.raw;
  }

  @override
  int length() => header.length();

  @override
  ErrorCauseCode errorCauseCode() => header.errorCauseCode();

  /// Port of `errorCauseUserInitiatedAbort.String`
  /// (error_cause_user_initiated_abort.go:42-44).
  @override
  String toString() => '$header: $upperLayerAbortReason';
}
