part of 'protocol.dart';

// Port of pkg/protocol/errors.go.
//
// Go's FatalError/InternalError/TemporaryError/TimeoutError/HandshakeError
// (errors.go:18-41) each wrap an inner `error` and additionally implement
// `net.Error` (Timeout()/Temporary()). Renamed per AGENTS.md Regra 13
// (`XError` -> `XException` when the Dart type implements Exception):
// FatalError -> FatalException, InternalError -> InternalException,
// TemporaryError -> TemporaryException, TimeoutError -> TimeoutException
// (kept local/private-library-scoped, so it does not collide with
// `dart:async`'s `TimeoutException` -- this library never imports
// `dart:async`), HandshakeError -> HandshakeException.
//
// `Err error` (an untyped Go `error`) becomes `Object err` in Dart: any
// object may be wrapped, matching Go's interface flexibility.

/// Private mirror of Go's `net.Error` (`Timeout()`/`Temporary()`), so
/// [HandshakeException] can dispatch to a wrapped error's own timeout/
/// temporary status the way `errors.As(e.Err, &netErr)` does
/// (errors.go:88-104). Has no direct Go-exported correspondent, hence
/// private (AGENTS.md).
abstract class _NetError {
  bool timeout();
  bool temporary();
}

/// FatalError indicates that the DTLS connection is no longer available.
/// It is mainly caused by wrong configuration of server or client.
///
/// Port of `FatalError` (errors.go:18-21) and its methods
/// `Timeout`/`Temporary`/`Unwrap`/`Error` (errors.go:44-54).
final class FatalException implements Exception, _NetError {
  final Object err;
  const FatalException(this.err);

  @override
  bool timeout() => false;

  @override
  bool temporary() => false;

  Object unwrap() => err;

  @override
  String toString() => 'dtls fatal: $err';
}

/// InternalError indicates and internal error caused by the implementation,
/// and the DTLS connection is no longer available. It is mainly caused by
/// bugs or tried to use unimplemented features.
///
/// Port of `InternalError` (errors.go:23-26) and its methods
/// `Timeout`/`Temporary`/`Unwrap`/`Error` (errors.go:57-67).
final class InternalException implements Exception, _NetError {
  final Object err;
  const InternalException(this.err);

  @override
  bool timeout() => false;

  @override
  bool temporary() => false;

  Object unwrap() => err;

  @override
  String toString() => 'dtls internal: $err';
}

/// TemporaryError indicates that the DTLS connection is still available,
/// but the request was failed temporary.
///
/// Port of `TemporaryError` (errors.go:29-31) and its methods
/// `Timeout`/`Temporary`/`Unwrap`/`Error` (errors.go:70-80).
final class TemporaryException implements Exception, _NetError {
  final Object err;
  const TemporaryException(this.err);

  @override
  bool timeout() => false;

  @override
  bool temporary() => true;

  Object unwrap() => err;

  @override
  String toString() => 'dtls temporary: $err';
}

/// TimeoutError indicates that the request was timed out.
///
/// Port of `TimeoutError` (errors.go:34-36) and its methods
/// `Timeout`/`Temporary`/`Unwrap`/`Error` (errors.go:83-93).
final class TimeoutException implements Exception, _NetError {
  final Object err;
  const TimeoutException(this.err);

  @override
  bool timeout() => true;

  @override
  bool temporary() => true;

  Object unwrap() => err;

  @override
  String toString() => 'dtls timeout: $err';
}

/// HandshakeError indicates that the handshake failed.
///
/// Port of `HandshakeError` (errors.go:39-41) and its methods
/// `Timeout`/`Temporary`/`Unwrap`/`Error` (errors.go:96-116). `Timeout`/
/// `Temporary` delegate to the wrapped error when it is itself a
/// `net.Error` (`errors.As`), ported here as an `is _NetError` check.
final class HandshakeException implements Exception, _NetError {
  final Object err;
  const HandshakeException(this.err);

  @override
  bool timeout() {
    final e = err;
    if (e is _NetError) return e.timeout();
    return false;
  }

  @override
  bool temporary() {
    final e = err;
    if (e is _NetError) return e.temporary();
    return false;
  }

  Object unwrap() => err;

  @override
  String toString() => 'handshake error: $err';
}

// Unexported package-level sentinel errors (errors.go:13-16). Go-unexported
// (lowercase), so private per AGENTS.md.
final TemporaryException _errBufferTooSmall = TemporaryException(
  'buffer is too small',
);
final FatalException _errInvalidCipherSpec = FatalException(
  'cipher spec invalid',
);
