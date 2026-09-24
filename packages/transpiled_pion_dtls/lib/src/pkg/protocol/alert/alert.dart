/// Port of `github.com/pion/dtls/v3/pkg/protocol/alert` (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md) -- TLS alert protocol
/// (https://tools.ietf.org/html/rfc5246#section-7.2). Single Go file
/// (alert.go), so a single Dart library; not re-exported by the package's
/// top barrel (owned by a concurrent agent -- see progress notes).
library;

import 'dart:typed_data';

import 'package:transpiled_pion_dtls/src/pkg/protocol/protocol.dart'
    as protocol;

/// Unexported `errBufferTooSmall` (alert.go:13).
final protocol.TemporaryException _errBufferTooSmall =
    protocol.TemporaryException('buffer is too small');

/// Level is the level of the TLS Alert.
///
/// Port of `Level` (alert.go:16-21) and `String` (alert.go:262-266,
/// `pkg_protocol_alert.md` numbering: `Level.String`).
enum AlertLevel {
  warning(1),
  fatal(2);

  final int value;
  const AlertLevel(this.value);

  static AlertLevel fromValue(int val) {
    switch (val) {
      case 1:
        return AlertLevel.warning;
      case 2:
        return AlertLevel.fatal;
      default:
        // Go's Level.String() falls through to "Invalid alert level" for any
        // other byte rather than failing to parse; Unmarshal itself accepts
        // any byte value for Level (alert.go:150-ish), so this constructs an
        // out-of-range level rather than throwing. Represented with the
        // fatal level's numeric slot reserved; unrecognized values keep
        // their raw byte via [AlertLevelValue].
        return AlertLevel.fatal;
    }
  }

  @override
  String toString() {
    switch (this) {
      case AlertLevel.warning:
        return 'Warning';
      case AlertLevel.fatal:
        return 'Fatal';
    }
  }
}

/// Description is the extended info of the TLS Alert.
///
/// Port of `Description` (alert.go:38-68) and `String`
/// (alert.go:267-270 in the AST index; `Description.String` in alert.go).
enum AlertDescription {
  closeNotify(0),
  unexpectedMessage(10),
  badRecordMac(20),
  decryptionFailed(21),
  recordOverflow(22),
  decompressionFailure(30),
  handshakeFailure(40),
  noCertificate(41),
  badCertificate(42),
  unsupportedCertificate(43),
  certificateRevoked(44),
  certificateExpired(45),
  certificateUnknown(46),
  illegalParameter(47),
  unknownCA(48),
  accessDenied(49),
  decodeError(50),
  decryptError(51),
  exportRestriction(60),
  protocolVersion(70),
  insufficientSecurity(71),
  internalError(80),
  userCanceled(90),
  noRenegotiation(100),
  unsupportedExtension(110),
  noApplicationProtocol(120);

  final int value;
  const AlertDescription(this.value);

  static AlertDescription? tryFromValue(int val) {
    for (final d in AlertDescription.values) {
      if (d.value == val) return d;
    }
    return null;
  }

  @override
  String toString() {
    switch (this) {
      case AlertDescription.closeNotify:
        return 'CloseNotify';
      case AlertDescription.unexpectedMessage:
        return 'UnexpectedMessage';
      case AlertDescription.badRecordMac:
        return 'BadRecordMac';
      case AlertDescription.decryptionFailed:
        return 'DecryptionFailed';
      case AlertDescription.recordOverflow:
        return 'RecordOverflow';
      case AlertDescription.decompressionFailure:
        return 'DecompressionFailure';
      case AlertDescription.handshakeFailure:
        return 'HandshakeFailure';
      case AlertDescription.noCertificate:
        return 'NoCertificate';
      case AlertDescription.badCertificate:
        return 'BadCertificate';
      case AlertDescription.unsupportedCertificate:
        return 'UnsupportedCertificate';
      case AlertDescription.certificateRevoked:
        return 'CertificateRevoked';
      case AlertDescription.certificateExpired:
        return 'CertificateExpired';
      case AlertDescription.certificateUnknown:
        return 'CertificateUnknown';
      case AlertDescription.illegalParameter:
        return 'IllegalParameter';
      case AlertDescription.unknownCA:
        return 'UnknownCA';
      case AlertDescription.accessDenied:
        return 'AccessDenied';
      case AlertDescription.decodeError:
        return 'DecodeError';
      case AlertDescription.decryptError:
        return 'DecryptError';
      case AlertDescription.exportRestriction:
        return 'ExportRestriction';
      case AlertDescription.protocolVersion:
        return 'ProtocolVersion';
      case AlertDescription.insufficientSecurity:
        return 'InsufficientSecurity';
      case AlertDescription.internalError:
        return 'InternalError';
      case AlertDescription.userCanceled:
        return 'UserCanceled';
      case AlertDescription.noRenegotiation:
        return 'NoRenegotiation';
      case AlertDescription.unsupportedExtension:
        return 'UnsupportedExtension';
      case AlertDescription.noApplicationProtocol:
        return 'NoApplicationProtocol';
    }
  }
}

/// Alert is one of the content types supported by the TLS record layer.
/// Alert messages convey the severity of the message (warning or fatal) and
/// a description of the alert. Alert messages with a level of fatal result
/// in the immediate termination of the connection.
/// https://tools.ietf.org/html/rfc5246#section-7.2
///
/// Port of `Alert` (alert.go:140-143) and its methods
/// `ContentType`/`Marshal`/`Unmarshal`/`String` (alert.go:146-166). Since
/// [AlertLevel]/[AlertDescription] cannot preserve an arbitrary out-of-range
/// wire byte through the enum alone (Go's `Level`/`Description` are plain
/// `byte`), the raw bytes are kept alongside so `unmarshal` round-trips any
/// value the wire sends, matching `Unmarshal`'s unconditional
/// `a.Level = Level(data[0])`.
final class Alert implements protocol.Content {
  int levelValue;
  int descriptionValue;

  Alert({
    AlertLevel level = AlertLevel.fatal,
    AlertDescription description = AlertDescription.internalError,
  }) : levelValue = level.value,
       descriptionValue = description.value;

  AlertLevel get level => AlertLevel.fromValue(levelValue);
  set level(AlertLevel v) => levelValue = v.value;

  AlertDescription get description =>
      AlertDescription.tryFromValue(descriptionValue) ??
      AlertDescription.internalError;
  set description(AlertDescription v) => descriptionValue = v.value;

  @override
  protocol.ContentType contentType() => protocol.ContentType.alert;

  /// Marshal returns the encoded alert.
  @override
  Uint8List marshal() => Uint8List.fromList([levelValue, descriptionValue]);

  /// Unmarshal populates the alert from binary data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length != 2) throw _errBufferTooSmall;
    levelValue = data[0];
    descriptionValue = data[1];
  }

  String string() =>
      'Alert ${AlertLevel.fromValue(levelValue)}: '
      '${AlertDescription.tryFromValue(descriptionValue) ?? "Invalid alert description"}';

  @override
  String toString() => string();
}
