/// Port of Go's `crypto/tls` `alert.go` (111 lines, ported in full).
///
/// Go symbol -> upstream file:line -> Dart symbol:
///   - `AlertError` (`alert.go:9-17`) and `alert`/`(alert).String`/
///     `(alert).Error` (`alert.go:19,101-111`) -> [AlertException]. Go keeps
///     two names because `alert` is the package-private wire value used
///     internally, while `AlertError` is the exported wrapper QUIC transport
///     errors surface it as; both do nothing but format the same code, so
///     this port merges them into one public exception type.
///   - `alertLevelWarning`/`alertLevelError` (`alert.go:23-25`)
///     -> [alertLevelWarning] / [alertLevelError]
///   - The 33 `alert` constants (`alert.go:28-60`) -> the `alert*` top-level
///     constants below, one per Go name (`alertBadRecordMAC` ->
///     [alertBadRecordMac], `alertUnknownCA` -> [alertUnknownCa],
///     `alertUnknownPSKIdentity` -> [alertUnknownPskIdentity],
///     `alertECHRequired` -> [alertEchRequired]: acronyms treated as common
///     words per AGENTS.md nomenclature rules).
///   - `alertText` (`alert.go:62-95`) -> `_alertText`.
///
/// All of these are unexported in Go (`alert`, its constants, and
/// `alertText` all start lowercase); this port elevates them to public Dart
/// symbols solely because `test/atomic/` files live outside this library and
/// cannot reach private members the way `alert_test.go`-style in-package Go
/// tests could. Elevation is documented here rather than silent, per
/// AGENTS.md's "Princípio do Menor Privilégio".
library;

/// Port of `alertLevelWarning` (`alert.go:24`).
const int alertLevelWarning = 1;

/// Port of `alertLevelError` (`alert.go:25`).
const int alertLevelError = 2;

/// Port of `alertCloseNotify` (`alert.go:29`).
const int alertCloseNotify = 0;

/// Port of `alertUnexpectedMessage` (`alert.go:30`).
const int alertUnexpectedMessage = 10;

/// Port of `alertBadRecordMAC` (`alert.go:31`).
const int alertBadRecordMac = 20;

/// Port of `alertDecryptionFailed` (`alert.go:32`).
const int alertDecryptionFailed = 21;

/// Port of `alertRecordOverflow` (`alert.go:33`).
const int alertRecordOverflow = 22;

/// Port of `alertDecompressionFailure` (`alert.go:34`).
const int alertDecompressionFailure = 30;

/// Port of `alertHandshakeFailure` (`alert.go:35`).
const int alertHandshakeFailure = 40;

/// Port of `alertBadCertificate` (`alert.go:36`).
const int alertBadCertificate = 42;

/// Port of `alertUnsupportedCertificate` (`alert.go:37`).
const int alertUnsupportedCertificate = 43;

/// Port of `alertCertificateRevoked` (`alert.go:38`).
const int alertCertificateRevoked = 44;

/// Port of `alertCertificateExpired` (`alert.go:39`).
const int alertCertificateExpired = 45;

/// Port of `alertCertificateUnknown` (`alert.go:40`).
const int alertCertificateUnknown = 46;

/// Port of `alertIllegalParameter` (`alert.go:41`).
const int alertIllegalParameter = 47;

/// Port of `alertUnknownCA` (`alert.go:42`).
const int alertUnknownCa = 48;

/// Port of `alertAccessDenied` (`alert.go:43`).
const int alertAccessDenied = 49;

/// Port of `alertDecodeError` (`alert.go:44`).
const int alertDecodeError = 50;

/// Port of `alertDecryptError` (`alert.go:45`).
const int alertDecryptError = 51;

/// Port of `alertExportRestriction` (`alert.go:46`).
const int alertExportRestriction = 60;

/// Port of `alertProtocolVersion` (`alert.go:47`).
const int alertProtocolVersion = 70;

/// Port of `alertInsufficientSecurity` (`alert.go:48`).
const int alertInsufficientSecurity = 71;

/// Port of `alertInternalError` (`alert.go:49`).
const int alertInternalError = 80;

/// Port of `alertInappropriateFallback` (`alert.go:50`).
const int alertInappropriateFallback = 86;

/// Port of `alertUserCanceled` (`alert.go:51`).
const int alertUserCanceled = 90;

/// Port of `alertNoRenegotiation` (`alert.go:52`).
const int alertNoRenegotiation = 100;

/// Port of `alertMissingExtension` (`alert.go:53`).
const int alertMissingExtension = 109;

/// Port of `alertUnsupportedExtension` (`alert.go:54`).
const int alertUnsupportedExtension = 110;

/// Port of `alertCertificateUnobtainable` (`alert.go:55`).
const int alertCertificateUnobtainable = 111;

/// Port of `alertUnrecognizedName` (`alert.go:56`).
const int alertUnrecognizedName = 112;

/// Port of `alertBadCertificateStatusResponse` (`alert.go:57`).
const int alertBadCertificateStatusResponse = 113;

/// Port of `alertBadCertificateHashValue` (`alert.go:58`).
const int alertBadCertificateHashValue = 114;

/// Port of `alertUnknownPSKIdentity` (`alert.go:59`).
const int alertUnknownPskIdentity = 115;

/// Port of `alertCertificateRequired` (`alert.go:60`).
const int alertCertificateRequired = 116;

/// Port of `alertNoApplicationProtocol` (`alert.go:61`).
const int alertNoApplicationProtocol = 120;

/// Port of `alertECHRequired` (`alert.go:62`).
const int alertEchRequired = 121;

/// Port of `alertText` (`alert.go:64-96`).
const Map<int, String> _alertText = {
  alertCloseNotify: 'close notify',
  alertUnexpectedMessage: 'unexpected message',
  alertBadRecordMac: 'bad record MAC',
  alertDecryptionFailed: 'decryption failed',
  alertRecordOverflow: 'record overflow',
  alertDecompressionFailure: 'decompression failure',
  alertHandshakeFailure: 'handshake failure',
  alertBadCertificate: 'bad certificate',
  alertUnsupportedCertificate: 'unsupported certificate',
  alertCertificateRevoked: 'revoked certificate',
  alertCertificateExpired: 'expired certificate',
  alertCertificateUnknown: 'unknown certificate',
  alertIllegalParameter: 'illegal parameter',
  alertUnknownCa: 'unknown certificate authority',
  alertAccessDenied: 'access denied',
  alertDecodeError: 'error decoding message',
  alertDecryptError: 'error decrypting message',
  alertExportRestriction: 'export restriction',
  alertProtocolVersion: 'protocol version not supported',
  alertInsufficientSecurity: 'insufficient security level',
  alertInternalError: 'internal error',
  alertInappropriateFallback: 'inappropriate fallback',
  alertUserCanceled: 'user canceled',
  alertNoRenegotiation: 'no renegotiation',
  alertMissingExtension: 'missing extension',
  alertUnsupportedExtension: 'unsupported extension',
  alertCertificateUnobtainable: 'certificate unobtainable',
  alertUnrecognizedName: 'unrecognized name',
  alertBadCertificateStatusResponse: 'bad certificate status response',
  alertBadCertificateHashValue: 'bad certificate hash value',
  alertUnknownPskIdentity: 'unknown PSK identity',
  alertCertificateRequired: 'certificate required',
  alertNoApplicationProtocol: 'no application protocol',
  alertEchRequired: 'encrypted client hello required',
};

/// Port of `alert` (`alert.go:19`) merged with `AlertError` (`alert.go:9-17`)
/// -- see file header for why the two Go names collapse into one Dart type.
/// Structurally `implements Exception`, so per AGENTS.md Rule 13 it carries
/// the `Exception` suffix even though its closest Go name (`AlertError`)
/// used `Error`.
final class AlertException implements Exception {
  /// Wraps a raw TLS alert description byte, one of the `alert*` constants
  /// in this file (or an unrecognized value, per `(alert).String`'s
  /// fallback -- see [description]).
  const AlertException(this.code);

  /// The raw TLS alert description byte (RFC 8446 Section 6).
  final int code;

  /// Port of `alertText[e]` lookup plus `(alert).String`'s fallback branch
  /// (`alert.go:102-105`) for an unrecognized code.
  String get description => _alertText[code] ?? 'alert($code)';

  /// Port of `(alert).String` (`alert.go:101-107`) and `(alert).Error`
  /// (`alert.go:109-111`), which are identical in Go.
  @override
  String toString() => 'tls: $description';
}
