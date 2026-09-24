// Port of github.com/pion/dtls/v3 pkg/crypto/ciphersuite/gcm.go
part of 'ciphersuite.dart';

const int _gcmTagLength = 16;
const int _gcmNonceLength = 12;

/// Adapts `package:pointycastle`'s AES-GCM (stdlib mapping for Go's
/// `crypto/aes` + `crypto/cipher.NewGCM`) to the [GoAeadCipher] shape that
/// [Aead] expects.
class _PointycastleGcmAead implements GoAeadCipher {
  _PointycastleGcmAead(this._key);

  final Uint8List _key;

  @override
  Uint8List seal(
    Uint8List dst,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List additionalData,
  ) {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.AEADParameters(
          pc.KeyParameter(_key),
          _gcmTagLength * 8,
          nonce,
          additionalData,
        ),
      );
    final out = Uint8List(cipher.getOutputSize(plaintext.length));
    final len = cipher.processBytes(plaintext, 0, plaintext.length, out, 0);
    final fin = cipher.doFinal(out, len);
    final sealed = out.sublist(0, len + fin);

    final result = Uint8List(dst.length + sealed.length);
    result.setRange(0, dst.length, dst);
    result.setRange(dst.length, result.length, sealed);
    return result;
  }

  @override
  Uint8List open(
    Uint8List dst,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List additionalData,
  ) {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        false,
        pc.AEADParameters(
          pc.KeyParameter(_key),
          _gcmTagLength * 8,
          nonce,
          additionalData,
        ),
      );
    final out = Uint8List(cipher.getOutputSize(ciphertext.length));
    final len = cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
    // doFinal throws pc.InvalidCipherTextException on tag mismatch, which
    // Aead.decrypt's caller wraps as DecryptPacketException -- matching
    // Go's `remoteAEAD.Open` returning an error on authentication failure.
    final fin = cipher.doFinal(out, len);
    final opened = out.sublist(0, len + fin);

    final result = Uint8List(dst.length + opened.length);
    result.setRange(0, dst.length, dst);
    result.setRange(dst.length, result.length, opened);
    return result;
  }
}

/// GCM provides an API to Encrypt/Decrypt DTLS 1.2 Packets.
class Gcm {
  Gcm._(this._aead);

  final Aead _aead;

  /// NewGCM creates a DTLS GCM Cipher.
  factory Gcm(
    Uint8List localKey,
    Uint8List localWriteIv,
    Uint8List remoteKey,
    Uint8List remoteWriteIv,
  ) {
    return Gcm._(
      Aead(
        _PointycastleGcmAead(localKey),
        localWriteIv,
        _PointycastleGcmAead(remoteKey),
        remoteWriteIv,
        _gcmNonceLength,
        _gcmTagLength,
      ),
    );
  }

  /// Encrypt encrypts a DTLS RecordLayer message.
  Uint8List encrypt(RecordLayer pkt, Uint8List raw) => _aead.encrypt(pkt, raw);

  /// Decrypt decrypts a DTLS RecordLayer message.
  Uint8List decrypt(Header header, Uint8List inBytes) =>
      _aead.decrypt(header, inBytes);
}
