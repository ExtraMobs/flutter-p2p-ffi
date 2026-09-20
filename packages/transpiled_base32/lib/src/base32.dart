// Copyright 2011 The Go Authors. All rights reserved.
// Use of this source code is governed by the BSD license in LICENSE.
import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// RFC 4648 padding rune.
const stdPadding = 61;

/// Disables padding.
const noPadding = -1;

/// Standard alphabet, with case-insensitive decoding.
final stdEncoding = Encoding.caseInsensitive(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
);

/// Extended hexadecimal alphabet, with case-insensitive decoding.
final hexEncoding = Encoding.caseInsensitive(
  '0123456789ABCDEFGHIJKLMNOPQRSTUV',
);

/// Standard alphabet without padding.
final rawStdEncoding = stdEncoding.withPadding(noPadding);

/// Extended hexadecimal alphabet without padding.
final rawHexEncoding = hexEncoding.withPadding(noPadding);

/// Reports the byte offset of invalid encoded input.
final class CorruptInputException implements Exception {
  /// Converts Go's CorruptInputError offset to a typed Dart exception.
  const CorruptInputException(this._offset);
  final int _offset;

  @override
  String toString() => 'illegal base32 data at input byte $_offset';
}

/// A radix-32 encoding with the supplied byte alphabet.
class Encoding {
  /// Go NewEncoding: a case-sensitive decoding map.
  Encoding(String encoder) : this._create(encoder, false);

  /// Go NewEncodingCI: both ASCII cases decode to the same value.
  Encoding.caseInsensitive(String encoder) : this._create(encoder, true);

  Encoding._create(String encoder, bool insensitive)
    : _alphabet = Uint8List.fromList(convert.utf8.encode(encoder)),
      _decodeMap = Uint8List(256)..fillRange(0, 256, 255),
      _padding = stdPadding {
    for (var i = 0; i < _alphabet.length; i++) {
      final c = _alphabet[i];
      final value = Golang.Uint8(i).toBigInt().toInt();
      if (insensitive) {
        _decodeMap[_asciiToLower(c)] = value;
        _decodeMap[_asciiToUpper(c)] = value;
      } else {
        _decodeMap[c] = value;
      }
    }
  }

  Encoding._copy(this._alphabet, this._decodeMap, this._padding);
  final Uint8List _alphabet;
  final Uint8List _decodeMap;
  final int _padding;

  /// Returns the alphabet used for encoding.
  String alphabet() => convert.utf8.decode(_alphabet);

  /// Returns an independent encoding configuration with the given rune.
  Encoding withPadding(int padding) => Encoding._copy(
    _alphabet,
    _decodeMap,
    Golang.Int32(padding).toBigInt().toInt(),
  );

  /// Number of bytes needed to encode an input of length [n].
  int encodedLen(int n) =>
      (_padding == noPadding
              ? (Golang.Int(n) * Golang.Int(8) + Golang.Int(4)) ~/ Golang.Int(5)
              : ((Golang.Int(n) + Golang.Int(4)) ~/ Golang.Int(5)) *
                    Golang.Int(8))
          .toIntExact();

  /// Maximum decoded byte count, matching upstream's raw-length rounding.
  int decodedLen(int n) =>
      (_padding == noPadding
              ? (Golang.Int(n) * Golang.Int(5) + Golang.Int(7)) ~/ Golang.Int(8)
              : (Golang.Int(n) ~/ Golang.Int(8)) * Golang.Int(5))
          .toIntExact();

  /// Encodes into caller-owned [dst], preserving the Go byte operations.
  void encode(Uint8List dst, Uint8List src) {
    if (src.isEmpty) return;
    final mask = Golang.Uint8(31);
    var si = 0;
    var di = 0;
    while (src.length - si > 4) {
      final s = List.generate(5, (i) => Golang.Uint8(src[si + i]));
      final values = [
        s[0] >> 3,
        ((s[1] >> 6) | (s[0] << 2)) & mask,
        (s[1] >> 1) & mask,
        ((s[2] >> 4) | (s[1] << 4)) & mask,
        (s[3] >> 7) | ((s[2] << 1) & mask),
        (s[3] >> 2) & mask,
        (s[4] >> 5) | ((s[3] << 3) & mask),
        s[4] & mask,
      ];
      // Upstream assigns the last byte first, including on short buffers.
      for (var i = 7; i >= 0; i--) {
        dst[di + i] = _alphabet[values[i].toBigInt().toInt()];
      }
      si += 5;
      di += 8;
    }
    final remaining = src.length - si;
    if (remaining == 0) return;
    var carry = Golang.Uint8();
    if (remaining == 4) {
      final b = Golang.Uint8(src[si + 3]);
      dst[di + 6] = _alphabet[((b << 3) & mask).toBigInt().toInt()];
      dst[di + 5] = _alphabet[((b >> 2) & mask).toBigInt().toInt()];
      carry = b >> 7;
    }
    if (remaining >= 3) {
      final b = Golang.Uint8(src[si + 2]);
      dst[di + 4] = _alphabet[(carry | ((b << 1) & mask)).toBigInt().toInt()];
      carry = (b >> 4) & mask;
    }
    if (remaining >= 2) {
      final b = Golang.Uint8(src[si + 1]);
      dst[di + 3] = _alphabet[(carry | ((b << 4) & mask)).toBigInt().toInt()];
      dst[di + 2] = _alphabet[((b >> 1) & mask).toBigInt().toInt()];
      carry = (b >> 6) & mask;
    }
    final b = Golang.Uint8(src[si]);
    dst[di + 1] = _alphabet[(carry | ((b << 2) & mask)).toBigInt().toInt()];
    dst[di] = _alphabet[(b >> 3).toBigInt().toInt()];
    if (_padding != noPadding) {
      final padding = Golang.Uint8(_padding).toBigInt().toInt();
      for (var i = 7; i >= (remaining * 8 + 4) ~/ 5; i--) {
        dst[di + i] = padding;
      }
    }
  }

  /// Encodes bytes to a Go byte string, represented as a Dart string.
  String encodeToString(Uint8List src) {
    final dst = Uint8List(encodedLen(src.length));
    encode(dst, src);
    return String.fromCharCodes(dst);
  }

  /// Decodes bytes, ignoring CR/LF, and returns the number written to [dst].
  int decode(Uint8List dst, Uint8List src) {
    final stripped = Uint8List.fromList(
      src.where((b) => b != 13 && b != 10).toList(),
    );
    return _decode(dst, stripped);
  }

  int _decode(Uint8List dst, Uint8List src) {
    var si = 0;
    var di = 0;
    var written = 0;
    var end = false;
    final padByte = Golang.Uint8(_padding).toBigInt().toInt();
    while (si < src.length && !end) {
      final dbuf = List.generate(8, (_) => Golang.Uint8());
      var dlen = 8;
      for (var j = 0; j < 8;) {
        if (si == src.length) {
          if (_padding != noPadding) throw CorruptInputException(si - j);
          dlen = j;
          break;
        }
        final input = src[si++];
        if (input == padByte && j >= 2 && src.length - si < 8) {
          if (_padding == noPadding || src.length - si + j < 7) {
            throw CorruptInputException(src.length);
          }
          for (var k = 0; k < 7 - j; k++) {
            if (src.length - si > k && src[si + k] != padByte) {
              throw CorruptInputException(si + k - 1);
            }
          }
          dlen = j;
          end = true;
          if (dlen == 1 || dlen == 3 || dlen == 6) {
            throw CorruptInputException(si - 1);
          }
          break;
        }
        dbuf[j] = Golang.Uint8(_decodeMap[input]);
        if (_decodeMap[input] == 255) throw CorruptInputException(si - 1);
        j++;
      }
      // Raw incomplete quanta of length 1, 3 or 6 write nothing in v0.1.0.
      if (const [2, 4, 5, 7, 8].contains(dlen)) {
        if (dlen == 8)
          dst[di + 4] = ((dbuf[6] << 5) | dbuf[7]).toBigInt().toInt();
        if (dlen >= 7)
          dst[di + 3] = ((dbuf[4] << 7) | (dbuf[5] << 2) | (dbuf[6] >> 3))
              .toBigInt()
              .toInt();
        if (dlen >= 5)
          dst[di + 2] = ((dbuf[3] << 4) | (dbuf[4] >> 1)).toBigInt().toInt();
        if (dlen >= 4)
          dst[di + 1] = ((dbuf[1] << 6) | (dbuf[2] << 1) | (dbuf[3] >> 4))
              .toBigInt()
              .toInt();
        dst[di] = ((dbuf[0] << 3) | (dbuf[1] >> 2)).toBigInt().toInt();
        written += dlen * 5 ~/ 8;
      }
      if (dst.length - di > 5) di += 5;
    }
    return written;
  }

  int _decodeInPlace(Uint8List bytes) {
    var offset = 0;
    for (final b in bytes) {
      if (b == 10 || b == 13) continue;
      bytes[offset++] = b;
    }
    return _decode(bytes, Uint8List.sublistView(bytes, 0, offset));
  }

  /// Decodes a string; invalid input throws [CorruptInputException].
  Uint8List decodeString(String input) {
    final bytes = Uint8List.fromList(convert.utf8.encode(input));
    final n = _decodeInPlace(bytes);
    return Uint8List.sublistView(bytes, 0, n);
  }
}

int _asciiToLower(int c) => c >= 65 && c <= 90 ? c + 32 : c;
int _asciiToUpper(int c) => c >= 97 && c <= 122 ? c - 32 : c;
