// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `error_cause_invalid_mandatory_parameter.go`
/// (github.com/pion/sctp): [ErrorCauseInvalidMandatoryParameter], the
/// Invalid Mandatory Parameter error cause (RFC 4960 section-3.3.10.8),
/// which carries no value beyond its header.
///
/// `errorCauseInvalidMandatoryParameter` is unexported in Go; see
/// error_cause_header.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'error_cause.dart';
import 'error_cause_header.dart';

/// Port of `errorCauseInvalidMandatoryParameter`
/// (error_cause_invalid_mandatory_parameter.go:7-9).
final class ErrorCauseInvalidMandatoryParameter implements ErrorCause {
  ErrorCauseInvalidMandatoryParameter()
    : header = ErrorCauseHeader(code: ErrorCauseCode.invalidMandatoryParameter);

  /// Composition standing in for Go's embedded `errorCauseHeader`.
  ErrorCauseHeader header;

  /// Port of `errorCauseInvalidMandatoryParameter.marshal`
  /// (error_cause_invalid_mandatory_parameter.go:11-13).
  @override
  Uint8List marshal() => header.marshal();

  /// Port of `errorCauseInvalidMandatoryParameter.unmarshal`
  /// (error_cause_invalid_mandatory_parameter.go:15-17).
  @override
  void unmarshal(Uint8List raw) => header.unmarshal(raw);

  @override
  int length() => header.length();

  @override
  ErrorCauseCode errorCauseCode() => header.errorCauseCode();

  /// Port of `errorCauseInvalidMandatoryParameter.String`
  /// (error_cause_invalid_mandatory_parameter.go:20-22).
  @override
  String toString() => header.toString();
}
