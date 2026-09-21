/// Port of `errorcode.go` (pion/stun v3.1.1).
library;

import 'dart:typed_data';

import 'attributes.dart';
import 'checks.dart';
import 'errors.dart';
import 'helpers.dart';
import 'message.dart';

const int _errorCodeReasonStart = 4;
const int _errorCodeClassByte = 2;
const int _errorCodeNumberByte = 3;
const int _errorCodeReasonMaxB = 763;
const int _errorCodeModulo = 100;

/// Port of `ErrorCodeAttribute` (errorcode.go:13-17): the ERROR-CODE
/// attribute (RFC 5389 Section 15.6).
final class ErrorCodeAttribute implements Setter, Getter {
  ErrorCodeAttribute({required this.code, required this.reason});

  ErrorCode code;
  Uint8List reason;

  /// Port of `ErrorCodeAttribute.String` (errorcode.go:20-22).
  @override
  String toString() => '${code.value}: ${String.fromCharCodes(reason)}';

  /// Port of `ErrorCodeAttribute.AddTo` (errorcode.go:33-49).
  @override
  void addTo(Message msg) {
    checkOverflow(
      AttrType.errorCode,
      reason.length + _errorCodeReasonStart,
      _errorCodeReasonMaxB + _errorCodeReasonStart,
    );
    final value = Uint8List(_errorCodeReasonStart + reason.length);
    final number = code.value % _errorCodeModulo;
    final errorClass = code.value ~/ _errorCodeModulo;
    value[_errorCodeClassByte] = errorClass;
    value[_errorCodeNumberByte] = number;
    value.setRange(_errorCodeReasonStart, value.length, reason);
    msg.add(AttrType.errorCode, value);
  }

  /// Port of `ErrorCodeAttribute.GetFrom` (errorcode.go:52-68). `reason` is
  /// valid only until `m.raw` is mutated.
  @override
  void getFrom(Message m) {
    final value = m.get(AttrType.errorCode);
    if (value.length < _errorCodeReasonStart) {
      throw const UnexpectedEofException();
    }
    final errorClass = value[_errorCodeClassByte];
    final number = value[_errorCodeNumberByte];
    code = ErrorCode(errorClass * _errorCodeModulo + number);
    reason = Uint8List.sublistView(value, _errorCodeReasonStart);
  }
}

/// Port of `ErrorCode` (errorcode.go:72): the code for an ERROR-CODE
/// attribute.
final class ErrorCode implements Setter {
  const ErrorCode(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is ErrorCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `ErrorCode.AddTo` (errorcode.go:79-88). Throws
  /// [NoDefaultReasonException] if there is no default reason.
  @override
  void addTo(Message m) {
    final reason = _errorReasons[this];
    if (reason == null) throw const NoDefaultReasonException();
    ErrorCodeAttribute(code: this, reason: reason).addTo(m);
  }

  // Possible error codes.
  static const ErrorCode codeTryAlternate = ErrorCode(300);
  static const ErrorCode codeBadRequest = ErrorCode(400);
  static const ErrorCode codeUnauthorized = ErrorCode(401);
  static const ErrorCode codeUnknownAttribute = ErrorCode(420);
  static const ErrorCode codeStaleNonce = ErrorCode(438);
  static const ErrorCode codeRoleConflict = ErrorCode(487);
  static const ErrorCode codeServerError = ErrorCode(500);

  /// Deprecated, use [codeUnauthorized]. Port of `CodeUnauthorised`
  /// (errorcode.go:98-101). No `// Deprecated:` comment on the upstream Go
  /// symbol despite the name, so this is not annotated `@Deprecated`
  /// either (AGENTS.md, "RULE_NO_UNAUTHORIZED_DEPRECATED").
  static const ErrorCode codeUnauthorised = codeUnauthorized;

  // Error codes from RFC 5766.
  static const ErrorCode codeForbidden = ErrorCode(403);
  static const ErrorCode codeAllocMismatch = ErrorCode(437);
  static const ErrorCode codeWrongCredentials = ErrorCode(441);
  static const ErrorCode codeUnsupportedTransProto = ErrorCode(442);
  static const ErrorCode codeAllocQuotaReached = ErrorCode(486);
  static const ErrorCode codeInsufficientCapacity = ErrorCode(508);

  // Error codes from RFC 6062.
  static const ErrorCode codeConnAlreadyExists = ErrorCode(446);
  static const ErrorCode codeConnTimeoutOrFailure = ErrorCode(447);

  // Error codes from RFC 6156.
  static const ErrorCode codeAddrFamilyNotSupported = ErrorCode(440);
  static const ErrorCode codePeerAddrFamilyMismatch = ErrorCode(443);
}

/// Port of `ErrNoDefaultReason` (errorcode.go:76).
final class NoDefaultReasonException implements Exception {
  const NoDefaultReasonException();

  @override
  String toString() => 'no default reason for ErrorCode';
}

/// Port of `errorReasons` (errorcode.go:130-153).
final Map<ErrorCode, Uint8List> _errorReasons = {
  ErrorCode.codeTryAlternate: Uint8List.fromList('Try Alternate'.codeUnits),
  ErrorCode.codeBadRequest: Uint8List.fromList('Bad Request'.codeUnits),
  ErrorCode.codeUnauthorized: Uint8List.fromList('Unauthorized'.codeUnits),
  ErrorCode.codeUnknownAttribute: Uint8List.fromList(
    'Unknown Attribute'.codeUnits,
  ),
  ErrorCode.codeStaleNonce: Uint8List.fromList('Stale Nonce'.codeUnits),
  ErrorCode.codeServerError: Uint8List.fromList('Server Error'.codeUnits),
  ErrorCode.codeRoleConflict: Uint8List.fromList('Role Conflict'.codeUnits),
  ErrorCode.codeForbidden: Uint8List.fromList('Forbidden'.codeUnits),
  ErrorCode.codeAllocMismatch: Uint8List.fromList(
    'Allocation Mismatch'.codeUnits,
  ),
  ErrorCode.codeWrongCredentials: Uint8List.fromList(
    'Wrong Credentials'.codeUnits,
  ),
  ErrorCode.codeUnsupportedTransProto: Uint8List.fromList(
    'Unsupported Transport Protocol'.codeUnits,
  ),
  ErrorCode.codeAllocQuotaReached: Uint8List.fromList(
    'Allocation Quota Reached'.codeUnits,
  ),
  ErrorCode.codeInsufficientCapacity: Uint8List.fromList(
    'Insufficient Capacity'.codeUnits,
  ),
  ErrorCode.codeConnAlreadyExists: Uint8List.fromList(
    'Connection Already Exists'.codeUnits,
  ),
  ErrorCode.codeConnTimeoutOrFailure: Uint8List.fromList(
    'Connection Timeout or Failure'.codeUnits,
  ),
  ErrorCode.codeAddrFamilyNotSupported: Uint8List.fromList(
    'Address Family not Supported'.codeUnits,
  ),
  ErrorCode.codePeerAddrFamilyMismatch: Uint8List.fromList(
    'Peer Address Family Mismatch'.codeUnits,
  ),
};

/// Port of `TurnException` (errorcode.go:156-159): an error from a TURN
/// response.
final class TurnException implements Exception {
  const TurnException({
    required this.stunMessageType,
    required this.errorCodeAttr,
  });

  final MessageType stunMessageType;
  final ErrorCodeAttribute errorCodeAttr;

  /// Port of `TurnException.Error`/`TurnException.String` (errorcode.go:162-169).
  @override
  String toString() => '$stunMessageType (error $errorCodeAttr)';
}
