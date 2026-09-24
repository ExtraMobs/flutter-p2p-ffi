import 'pkg/protocol/alert/alert.dart';

/// InvalidCipherSuiteException indicates an attempt at using an unsupported cipher suite.
class InvalidCipherSuiteException implements Exception {
  final int id;

  const InvalidCipherSuiteException(this.id);

  String error() =>
      'CipherSuite with id(0x${id.toRadixString(16)}) is not valid';

  bool isMatch(Object other) {
    if (other is InvalidCipherSuiteException) {
      return id == other.id;
    }
    return false;
  }

  @override
  String toString() => error();
}

/// AlertException wraps DTLS alert notification as an error.
class AlertException implements Exception {
  final Alert alert;

  const AlertException(this.alert);

  String error() => 'alert: ${alert.string()}';

  bool isFatalOrCloseNotify() {
    return alert.level == AlertLevel.fatal ||
        alert.description == AlertDescription.closeNotify;
  }

  bool isMatch(Object other) {
    if (other is AlertException) {
      return alert.level == other.alert.level &&
          alert.description == other.alert.description;
    }
    return false;
  }

  @override
  String toString() => error();
}

final Exception errConnClosed = Exception('conn is closed');
final Exception errDeadlineExceeded = Exception('read/write timeout');
final Exception errInvalidContentType = Exception('invalid content type');
final Exception errBufferTooSmall = Exception('buffer is too small');
final Exception errContextUnsupported = Exception(
  'context is not supported for ExportKeyingMaterial',
);
final Exception errHandshakeInProgress = Exception('handshake is in progress');
final Exception errReservedExportKeyingMaterial = Exception(
  'ExportKeyingMaterial can not be used with a reserved label',
);
final Exception errCipherSuiteNotSet = Exception('cipher suite not set');
