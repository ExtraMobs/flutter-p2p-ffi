// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `error_cause.go` (github.com/pion/sctp): [ErrorCauseCode] (the
/// cause code carried by ERROR and ABORT chunks, RFC 4960 section-3.3.10),
/// the [ErrorCause] contract every concrete `error_cause_*.go` type
/// implements, and [buildErrorCause], the dispatch function that decodes
/// the right concrete type from an [ErrorCauseCode].
///
/// `errorCauseCode`, `errorCause` and `buildErrorCause` are unexported in
/// Go; all stay public within `lib/src` (see util.dart's file-level doc
/// comment) but are not exported from `transpiled_pion_sctp.dart`.
library;

import 'dart:typed_data';

import 'error_cause_invalid_mandatory_parameter.dart';
import 'error_cause_protocol_violation.dart';
import 'error_cause_unrecognized_chunk_type.dart';
import 'error_cause_user_initiated_abort.dart';

/// Port of `ErrBuildErrorCaseHandle` (error_cause.go:26).
final class BuildErrorCaseHandleException implements Exception {
  const BuildErrorCaseHandleException(this.code);

  final ErrorCauseCode code;

  @override
  String toString() => 'BuildErrorCause does not handle: $code';
}

/// Port of `errorCauseCode` (error_cause.go:13) and its constants
/// (error_cause.go:57-70).
final class ErrorCauseCode {
  const ErrorCauseCode._(this.value);

  /// The raw wire value (a Go `uint16`).
  final int value;

  static const ErrorCauseCode invalidStreamIdentifier = ErrorCauseCode._(1);
  static const ErrorCauseCode missingMandatoryParameter = ErrorCauseCode._(2);
  static const ErrorCauseCode staleCookieError = ErrorCauseCode._(3);
  static const ErrorCauseCode outOfResource = ErrorCauseCode._(4);
  static const ErrorCauseCode unresolvableAddress = ErrorCauseCode._(5);
  static const ErrorCauseCode unrecognizedChunkType = ErrorCauseCode._(6);
  static const ErrorCauseCode invalidMandatoryParameter = ErrorCauseCode._(7);
  static const ErrorCauseCode unrecognizedParameters = ErrorCauseCode._(8);
  static const ErrorCauseCode noUserData = ErrorCauseCode._(9);
  static const ErrorCauseCode cookieReceivedWhileShuttingDown = ErrorCauseCode._(10);
  static const ErrorCauseCode restartOfAnAssociationWithNewAddresses = ErrorCauseCode._(11);
  static const ErrorCauseCode userInitiatedAbort = ErrorCauseCode._(12);
  static const ErrorCauseCode protocolViolation = ErrorCauseCode._(13);

  factory ErrorCauseCode.fromValue(int value) => ErrorCauseCode._(value);

  @override
  bool operator ==(Object other) => other is ErrorCauseCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `errorCauseCode.String` (error_cause.go:72-99).
  @override
  String toString() {
    switch (value) {
      case 1:
        return 'Invalid Stream Identifier';
      case 2:
        return 'Missing Mandatory Parameter';
      case 3:
        return 'Stale Cookie Error';
      case 4:
        return 'Out Of Resource';
      case 5:
        return 'Unresolvable IP';
      case 6:
        return 'Unrecognized Chunk Type';
      case 7:
        return 'Invalid Mandatory Parameter';
      case 8:
        return 'Unrecognized Parameters';
      case 9:
        return 'No User Data';
      case 10:
        return 'Cookie Received While Shutting Down';
      case 11:
        return 'Restart Of An Association With New Addresses';
      case 12:
        return 'User Initiated Abort';
      case 13:
        return 'Protocol Violation';
      default:
        return 'Unknown CauseCode: $value';
    }
  }
}

/// Port of `errorCause` (error_cause.go:16-22).
abstract interface class ErrorCause {
  /// Port of `errorCause.unmarshal` (error_cause.go:17).
  void unmarshal(Uint8List raw);

  /// Port of `errorCause.marshal` (error_cause.go:18).
  Uint8List marshal();

  /// Port of `errorCause.length` (error_cause.go:19).
  int length();

  /// Port of `errorCause.errorCauseCode` (error_cause.go:21).
  ErrorCauseCode errorCauseCode();
}

/// Port of `buildErrorCause` (error_cause.go:29-49).
ErrorCause buildErrorCause(Uint8List raw) {
  final c = ErrorCauseCode.fromValue(ByteData.sublistView(raw, 0, 2).getUint16(0, Endian.big));

  final ErrorCause errCause;
  if (c == ErrorCauseCode.invalidMandatoryParameter) {
    errCause = ErrorCauseInvalidMandatoryParameter();
  } else if (c == ErrorCauseCode.unrecognizedChunkType) {
    errCause = ErrorCauseUnrecognizedChunkType();
  } else if (c == ErrorCauseCode.protocolViolation) {
    errCause = ErrorCauseProtocolViolation();
  } else if (c == ErrorCauseCode.userInitiatedAbort) {
    errCause = ErrorCauseUserInitiatedAbort();
  } else {
    throw BuildErrorCaseHandleException(c);
  }

  errCause.unmarshal(raw);
  return errCause;
}
