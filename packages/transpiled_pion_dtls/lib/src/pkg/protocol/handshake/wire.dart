part of 'handshake.dart';

// Private infra: reproduces the wire BEHAVIOR of
// `golang.org/x/crypto/cryptobyte` (`Builder`/`String`) that
// `message_certificate_13.go` and `message_certificate_request_13.go` build/
// parse with. See `handshake.dart`'s library doc and
// `pkg/protocol/extension/wire.dart` (identical design, duplicated per
// AGENTS.md Regra 25's per-library privacy rather than shared, since these
// are Dart-private symbols with no Go correspondent of their own).

final class _CryptobyteFormatException implements Exception {
  final String message;
  const _CryptobyteFormatException(this.message);

  @override
  String toString() => '_CryptobyteFormatException: $message';
}

final class _CryptobyteBuilder {
  final BytesBuilder _buf = BytesBuilder(copy: false);

  void addUint8(int v) => _buf.addByte(v & 0xff);

  void addUint8LengthPrefixed(void Function(_CryptobyteBuilder b) fn) =>
      _addLengthPrefixed(1, 0xff, fn);

  void addBytes(List<int> v) => _buf.add(v);

  void _addLengthPrefixed(
    int prefixWidth,
    int maxLen,
    void Function(_CryptobyteBuilder b) fn,
  ) {
    final inner = _CryptobyteBuilder();
    fn(inner);
    final body = inner.toBytes();
    if (body.length > maxLen) {
      throw StateError(
        'length-prefixed body of ${body.length} bytes overflows a '
        '$prefixWidth-byte prefix',
      );
    }
    if (prefixWidth == 1) addUint8(body.length);
    addBytes(body);
  }

  Uint8List toBytes() => _buf.toBytes();
}

final class _CryptobyteReader {
  _CryptobyteReader(this._data);

  final Uint8List _data;
  int _pos = 0;

  bool get isEmpty => _pos >= _data.length;

  int get remainingLength => _data.length - _pos;

  /// Independent view sharing the same backing bytes and current position.
  _CryptobyteReader clone() => _CryptobyteReader(_data).._pos = _pos;

  void _require(int n) {
    if (remainingLength < n) {
      throw const _CryptobyteFormatException(
        'unexpected end of handshake message data',
      );
    }
  }

  void skip(int n) {
    _require(n);
    _pos += n;
  }

  int readUint8() {
    _require(1);
    return _data[_pos++];
  }

  int readUint24() {
    _require(3);
    final v = (_data[_pos] << 16) | (_data[_pos + 1] << 8) | _data[_pos + 2];
    _pos += 3;
    return v;
  }

  Uint8List readBytes(int n) {
    _require(n);
    final out = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return out;
  }

  Uint8List readUint8LengthPrefixed() => readBytes(readUint8());

  Uint8List readUint24LengthPrefixed() => readBytes(readUint24());
}
