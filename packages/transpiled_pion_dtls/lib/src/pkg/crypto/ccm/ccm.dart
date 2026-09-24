// Port of github.com/pion/dtls/v3 pkg/crypto/ccm/ccm.go
//
// Implements CCM, Counter with CBC-MAC, as per RFC 3610.
// See https://tools.ietf.org/html/rfc3610

import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

/// ccmBlockSize is the fixed block size CCM requires from its underlying
/// block cipher (128 bits / 16 bytes), matching Go's `ccmBlockSize`.
const int ccmBlockSize = 16;

/// CcmException mirrors the sentinel errors declared in ccm.go
/// (errInvalidBlockSize, errInvalidTagSize, errInvalidNonceSize,
/// errPlaintextTooLong, errOpen, errCiphertextTooShort, errCiphertextTooLong).
class CcmException implements Exception {
  const CcmException(this.message);

  final String message;

  @override
  String toString() => 'CcmException: $message';
}

/// maxlen mirrors the Go free function `maxlen(l uint8, tagsize int) int`.
///
/// Dart `int` is already a signed 64-bit integer (or arbitrary precision on
/// the VM), so the Go distinction between 32-bit and 64-bit platforms is
/// adapted to Dart's native int width instead of reproducing `math.MaxInt32`.
int _maxlen(int l, int tagsize) {
  final mLen = (1 << (8 * l)) - 1;
  // On Dart's 64-bit int there is no analogous 32-bit truncation branch;
  // the only cap that still applies is avoiding overflow past a 63-bit int.
  final m64 = 0x7FFFFFFFFFFFFFFF - tagsize;
  if (l > 8 || mLen > m64) {
    return m64;
  }
  return mLen;
}

/// ccm represents a Counter with CBC-MAC with a specific key.
///
/// Port of the unexported Go type `ccm` (which also satisfies the exported
/// `CCM` interface, itself just `cipher.AEAD` plus `MaxLength() int`). Since
/// Dart does not have Go's implicit interface satisfaction and this package
/// has no other CCM implementation, the two are merged into one public
/// class named after the exported `CCM` interface.
class Ccm {
  Ccm._(this._b, this.m, this.l);

  /// NewCCM returns the given 128-bit block cipher wrapped in CCM.
  ///
  /// [tagsize] must be an even integer between 4 and 16 inclusive and is
  /// used as CCM's `M` parameter. [noncesize] must be an integer between 7
  /// and 13 inclusive; `15-noncesize` is used as CCM's `L` parameter.
  factory Ccm(pc.BlockCipher b, int tagsize, int noncesize) {
    if (b.blockSize != ccmBlockSize) {
      throw const CcmException('ccm: NewCCM requires 128-bit block cipher');
    }
    if (tagsize < 4 || tagsize > 16 || tagsize.isOdd) {
      throw const CcmException(
        'ccm: tagsize must be 4, 6, 8, 10, 12, 14, or 16',
      );
    }
    final lensize = 15 - noncesize;
    if (lensize < 2 || lensize > 8) {
      throw const CcmException('ccm: invalid nonce size');
    }
    return Ccm._(b, tagsize, lensize);
  }

  final pc.BlockCipher _b;

  /// M: tag size in bytes (`Overhead()`).
  final int m;

  /// L: length-field size in bytes.
  final int l;

  int nonceSize() => 15 - l;

  int overhead() => m;

  int maxLength() => _maxlen(l, overhead());

  /// MaxNonceLength returns the maximum nonce length for a given plaintext
  /// length. A return value <= 0 indicates that plaintext length is too
  /// large for any nonce length.
  static int maxNonceLength(int pdatalen) {
    const tagsize = 16;
    for (var L = 2; L <= 8; L++) {
      if (_maxlen(L, tagsize) >= pdatalen) {
        return 15 - L;
      }
    }
    return 0;
  }

  void _blockEncrypt(Uint8List dst, Uint8List src) {
    _b.processBlock(src, 0, dst, 0);
  }

  void _cbcRound(Uint8List mac, Uint8List data) {
    for (var i = 0; i < ccmBlockSize; i++) {
      mac[i] ^= data[i];
    }
    _blockEncrypt(mac, mac);
  }

  void _cbcData(Uint8List mac, Uint8List data) {
    var offset = 0;
    while (data.length - offset >= ccmBlockSize) {
      _cbcRound(
        mac,
        Uint8List.sublistView(data, offset, offset + ccmBlockSize),
      );
      offset += ccmBlockSize;
    }
    if (offset < data.length) {
      final block = Uint8List(ccmBlockSize);
      block.setRange(0, data.length - offset, data.sublist(offset));
      _cbcRound(mac, block);
    }
  }

  Uint8List _tag(Uint8List nonce, Uint8List plaintext, Uint8List adata) {
    final mac = Uint8List(ccmBlockSize);

    if (adata.isNotEmpty) {
      mac[0] |= 1 << 6;
    }
    mac[0] |= (m - 2) << 2;
    mac[0] |= l - 1;
    if (nonce.length != nonceSize()) {
      throw const CcmException('ccm: invalid nonce size');
    }
    if (plaintext.length > maxLength()) {
      throw const CcmException('ccm: plaintext too large');
    }

    // PutUint64(mac[ccmBlockSize-8:], len(plaintext)) followed by
    // copy(mac[1:ccmBlockSize-l], nonce): the nonce copy overwrites the
    // high-order bytes of the 8-byte length field, leaving only its
    // low-order `l` bytes intact -- exactly CCM's l-byte length encoding.
    final macView = ByteData.sublistView(mac);
    macView.setUint64(ccmBlockSize - 8, plaintext.length);
    mac.setRange(1, ccmBlockSize - l, nonce);

    _blockEncrypt(mac, mac);

    if (adata.isNotEmpty) {
      final block = Uint8List(ccmBlockSize);
      final adataLength = adata.length;
      var i = 2;
      final blockView = ByteData.sublistView(block);
      if (adataLength <= 0xfeff) {
        blockView.setUint16(0, adataLength);
      } else {
        blockView.setUint16(0, 0xfeff);
        if (adataLength < (1 << 32)) {
          i = 2 + 4;
          blockView.setUint32(2, adataLength);
        } else {
          i = 2 + 8;
          blockView.setUint64(2, adataLength);
        }
      }
      final firstChunkLen = (adata.length < (ccmBlockSize - i))
          ? adata.length
          : (ccmBlockSize - i);
      block.setRange(i, i + firstChunkLen, adata);
      _cbcRound(mac, block);
      _cbcData(mac, adata.sublist(firstChunkLen));
    }

    if (plaintext.isNotEmpty) {
      _cbcData(mac, plaintext);
    }

    return mac.sublist(0, m);
  }

  Uint8List _ctrXor(Uint8List iv, Uint8List data) {
    final out = Uint8List(data.length);
    final counter = Uint8List.fromList(iv);
    final keystream = Uint8List(ccmBlockSize);
    var offset = 0;
    while (offset < data.length) {
      _blockEncrypt(keystream, counter);
      final n = (data.length - offset < ccmBlockSize)
          ? data.length - offset
          : ccmBlockSize;
      for (var i = 0; i < n; i++) {
        out[offset + i] = data[offset + i] ^ keystream[i];
      }
      offset += n;
      // Increment the 16-byte big-endian counter (crypto/cipher's NewCTR
      // treats the whole IV as the counter and wraps across it).
      for (var i = ccmBlockSize - 1; i >= 0; i--) {
        counter[i] = (counter[i] + 1) & 0xFF;
        if (counter[i] != 0) break;
      }
    }
    return out;
  }

  static int _constantTimeCompare(Uint8List a, Uint8List b) {
    if (a.length != b.length) return 0;
    var v = 0;
    for (var i = 0; i < a.length; i++) {
      v |= a[i] ^ b[i];
    }
    return v == 0 ? 1 : 0;
  }

  /// Seal encrypts and authenticates plaintext, authenticates the
  /// additional data and appends the result to dst, returning the updated
  /// bytes. The nonce must be [nonceSize] bytes long and unique for all
  /// time, for a given key. The plaintext must be no longer than
  /// [maxLength] bytes long.
  Uint8List seal(
    Uint8List dst,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List adata,
  ) {
    final tag = _tag(nonce, plaintext, adata);

    final iv = Uint8List(ccmBlockSize);
    final s0 = Uint8List(ccmBlockSize);
    iv[0] = l - 1;
    iv.setRange(1, ccmBlockSize - l, nonce);
    _blockEncrypt(s0, iv);
    for (var i = 0; i < m; i++) {
      tag[i] ^= s0[i];
    }
    iv[iv.length - 1] |= 1;

    final ciphertext = _ctrXor(iv, plaintext);

    final out = Uint8List(dst.length + plaintext.length + m);
    out.setRange(0, dst.length, dst);
    out.setRange(dst.length, dst.length + plaintext.length, ciphertext);
    out.setRange(dst.length + plaintext.length, out.length, tag);
    return out;
  }

  /// Open decrypts and authenticates ciphertext, authenticates the
  /// additional data and, if successful, appends the resulting plaintext
  /// to dst, returning the updated bytes. Throws [CcmException] if
  /// authentication fails.
  Uint8List open(
    Uint8List dst,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List adata,
  ) {
    if (ciphertext.length < m) {
      throw const CcmException('ccm: ciphertext too short');
    }
    if (ciphertext.length > maxLength() + overhead()) {
      throw const CcmException('ccm: ciphertext too long');
    }

    final tag = Uint8List.fromList(ciphertext.sublist(ciphertext.length - m));
    final ciphertextWithoutTag = ciphertext.sublist(0, ciphertext.length - m);

    final iv = Uint8List(ccmBlockSize);
    final s0 = Uint8List(ccmBlockSize);
    iv[0] = l - 1;
    iv.setRange(1, ccmBlockSize - l, nonce);
    _blockEncrypt(s0, iv);
    for (var i = 0; i < m; i++) {
      tag[i] ^= s0[i];
    }
    iv[iv.length - 1] |= 1;

    final plaintext = _ctrXor(iv, ciphertextWithoutTag);
    final expectedTag = _tag(nonce, plaintext, adata);

    if (_constantTimeCompare(tag, expectedTag) != 1) {
      throw const CcmException('ccm: message authentication failed');
    }

    final out = Uint8List(dst.length + plaintext.length);
    out.setRange(0, dst.length, dst);
    out.setRange(dst.length, out.length, plaintext);
    return out;
  }
}
