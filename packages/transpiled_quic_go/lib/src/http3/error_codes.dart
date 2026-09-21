// ignore_for_file: public_member_api_docs
//
// Ported from `quic-go/http3/error_codes.go` (module `github.com/quic-go/
// quic-go`, upstream commit fixed in `doc/transpilation/UPSTREAM_LOCK.md`).

/// HTTP/3 application error code (RFC 9114 §8.1).
///
/// Mirrors the Go named type `ErrCode`, defined as
/// `type ErrCode quic.ApplicationErrorCode` — itself a `uint64`. Dart
/// represents the underlying value as a plain `int`, consistent with how
/// `varint.dart` already represents QUIC varint-encoded protocol values
/// throughout this package.
///
/// Go models `ErrCode` as an open, arbitrarily-valued integer type (any
/// `uint64` is a legal, if unrecognized, error code), not a closed set, so
/// this is a value class with named constants rather than a Dart `enum`.
final class Http3ErrCode {
  const Http3ErrCode(this.value);

  final int value;

  static const noError = Http3ErrCode(0x100);
  static const generalProtocolError = Http3ErrCode(0x101);
  static const internalError = Http3ErrCode(0x102);
  static const streamCreationError = Http3ErrCode(0x103);
  static const closedCriticalStream = Http3ErrCode(0x104);
  static const frameUnexpected = Http3ErrCode(0x105);
  static const frameError = Http3ErrCode(0x106);
  static const excessiveLoad = Http3ErrCode(0x107);
  static const idError = Http3ErrCode(0x108);
  static const settingsError = Http3ErrCode(0x109);
  static const missingSettings = Http3ErrCode(0x10a);
  static const requestRejected = Http3ErrCode(0x10b);
  static const requestCanceled = Http3ErrCode(0x10c);
  static const requestIncomplete = Http3ErrCode(0x10d);
  static const messageError = Http3ErrCode(0x10e);
  static const connectError = Http3ErrCode(0x10f);
  static const versionFallback = Http3ErrCode(0x110);
  static const datagramError = Http3ErrCode(0x33);
  static const qpackDecompressionFailed = Http3ErrCode(0x200);

  /// Wire-format name for each known code, mirroring Go's unexported
  /// `ErrCode.string()` helper.
  static const _names = <int, String>{
    0x100: 'H3_NO_ERROR',
    0x101: 'H3_GENERAL_PROTOCOL_ERROR',
    0x102: 'H3_INTERNAL_ERROR',
    0x103: 'H3_STREAM_CREATION_ERROR',
    0x104: 'H3_CLOSED_CRITICAL_STREAM',
    0x105: 'H3_FRAME_UNEXPECTED',
    0x106: 'H3_FRAME_ERROR',
    0x107: 'H3_EXCESSIVE_LOAD',
    0x108: 'H3_ID_ERROR',
    0x109: 'H3_SETTINGS_ERROR',
    0x10a: 'H3_MISSING_SETTINGS',
    0x10b: 'H3_REQUEST_REJECTED',
    0x10c: 'H3_REQUEST_CANCELLED',
    0x10d: 'H3_INCOMPLETE_REQUEST',
    0x10e: 'H3_MESSAGE_ERROR',
    0x10f: 'H3_CONNECT_ERROR',
    0x110: 'H3_VERSION_FALLBACK',
    0x33: 'H3_DATAGRAM_ERROR',
    0x200: 'QPACK_DECOMPRESSION_FAILED',
  };

  /// Mirrors Go's exported `ErrCode.String() string` (`error_codes.go`).
  @override
  String toString() {
    final name = _names[value];
    if (name != null) return name;
    return 'unknown error code: 0x${value.toRadixString(16)}';
  }

  @override
  bool operator ==(Object other) =>
      other is Http3ErrCode && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
