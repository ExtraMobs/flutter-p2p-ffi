part of 'extension.dart';

// Private infra: no direct Go-exported correspondent (AGENTS.md), so
// private. Reproduces the wire BEHAVIOR of `golang.org/x/crypto/cryptobyte`
// (`Builder`/`String`) that several files in this package build/parse with
// -- see `extension.dart`'s library doc for why cryptobyte itself is out of
// scope to port, and
// `packages/transpiled_crypto_tls/lib/src/handshake_messages.dart` for the
// established precedent this mirrors (`_Builder`/`_Reader` there).
//
// [_CryptobyteBuilder] builds each length-prefixed sub-region into a fresh
// nested builder, reads its finished byte length, then writes the prefix
// followed by those bytes into the parent -- two-pass instead of
// cryptobyte's single-pass placeholder-then-backpatch, behaviorally
// identical output, and simpler to write correctly in Dart.
// [_CryptobyteReader] throws [_CryptobyteFormatException] on truncation
// instead of cryptobyte's `bool` "read ok?" return (AGENTS.md Regra 8).

/// Thrown by [_CryptobyteReader] on truncated/malformed input.
final class _CryptobyteFormatException implements Exception {
  final String message;
  const _CryptobyteFormatException(this.message);

  @override
  String toString() => '_CryptobyteFormatException: $message';
}

final class _CryptobyteBuilder {
  final BytesBuilder _buf = BytesBuilder(copy: false);

  void addUint8(int v) => _buf.addByte(v & 0xff);

  void addUint16(int v) => _buf.add([(v >> 8) & 0xff, v & 0xff]);

  void addUint32(int v) =>
      _buf.add([(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]);

  void addBytes(List<int> v) => _buf.add(v);

  void addUint8LengthPrefixed(void Function(_CryptobyteBuilder b) fn) =>
      _addLengthPrefixed(1, 0xff, fn);

  void addUint16LengthPrefixed(void Function(_CryptobyteBuilder b) fn) =>
      _addLengthPrefixed(2, 0xffff, fn);

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
    switch (prefixWidth) {
      case 1:
        addUint8(body.length);
      case 2:
        addUint16(body.length);
    }
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

  /// Independent view sharing the same backing bytes and current position,
  /// mirroring Go's `peek := extData` slice-header copy (cryptobyte.String
  /// is itself a `[]byte`).
  _CryptobyteReader clone() => _CryptobyteReader(_data).._pos = _pos;

  void _require(int n) {
    if (remainingLength < n) {
      throw const _CryptobyteFormatException(
        'unexpected end of extension data',
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

  int readUint16() {
    _require(2);
    final v = (_data[_pos] << 8) | _data[_pos + 1];
    _pos += 2;
    return v;
  }

  int readUint32() {
    _require(4);
    final v =
        (_data[_pos] << 24) |
        (_data[_pos + 1] << 16) |
        (_data[_pos + 2] << 8) |
        _data[_pos + 3];
    _pos += 4;
    return v;
  }

  Uint8List readBytes(int n) {
    _require(n);
    final out = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return out;
  }

  Uint8List readUint8LengthPrefixed() => readBytes(readUint8());

  Uint8List readUint16LengthPrefixed() => readBytes(readUint16());

  _CryptobyteReader readUint8LengthPrefixedReader() =>
      _CryptobyteReader(readUint8LengthPrefixed());

  _CryptobyteReader readUint16LengthPrefixedReader() =>
      _CryptobyteReader(readUint16LengthPrefixed());
}
