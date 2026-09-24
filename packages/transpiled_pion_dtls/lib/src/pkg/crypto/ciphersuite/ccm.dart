// Port of github.com/pion/dtls/v3 pkg/crypto/ciphersuite/ccm.go
part of 'ciphersuite.dart';

/// CCMTagLen is the length of Authentication Tag.
class CcmTagLen {
  const CcmTagLen(this.value);

  final int value;

  static const CcmTagLen length8 = CcmTagLen(8);
  static const CcmTagLen length = CcmTagLen(16);

  @override
  bool operator ==(Object other) => other is CcmTagLen && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

const int _ccmNonceLength = 12;

/// Adapts the `pkg/crypto/ccm` port ([ccm.Ccm]) to the [GoAeadCipher] shape
/// [Aead] expects. Kept as a thin delegating wrapper rather than having
/// `ccm.Ccm` itself `implement GoAeadCipher`, since `pkg/crypto/ccm` is a
/// separate Go module boundary (`packages/transpiled_pion_dtls`'s own
/// `pkg/crypto/ccm` directory) that must not depend on this
/// `pkg/crypto/ciphersuite` package.
class _CcmAeadAdapter implements GoAeadCipher {
  _CcmAeadAdapter(this._ccm);

  final ccm.Ccm _ccm;

  @override
  Uint8List seal(
    Uint8List dst,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List additionalData,
  ) => _ccm.seal(dst, nonce, plaintext, additionalData);

  @override
  Uint8List open(
    Uint8List dst,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List additionalData,
  ) => _ccm.open(dst, nonce, ciphertext, additionalData);
}

pc.AESEngine _ccmAesBlock(Uint8List key) {
  return pc.AESEngine()..init(true, pc.KeyParameter(key));
}

/// CCM provides an API to Encrypt/Decrypt DTLS 1.2 Packets.
class Ccm {
  Ccm._(this._aead);

  final Aead _aead;

  /// NewCCM creates a DTLS CCM Cipher.
  factory Ccm(
    CcmTagLen tagLen,
    Uint8List localKey,
    Uint8List localWriteIv,
    Uint8List remoteKey,
    Uint8List remoteWriteIv,
  ) {
    final localCcm = ccm.Ccm(
      _ccmAesBlock(localKey),
      tagLen.value,
      _ccmNonceLength,
    );
    final remoteCcm = ccm.Ccm(
      _ccmAesBlock(remoteKey),
      tagLen.value,
      _ccmNonceLength,
    );

    return Ccm._(
      Aead(
        _CcmAeadAdapter(localCcm),
        localWriteIv,
        _CcmAeadAdapter(remoteCcm),
        remoteWriteIv,
        _ccmNonceLength,
        tagLen.value,
      ),
    );
  }

  /// Encrypt encrypts a DTLS RecordLayer message.
  Uint8List encrypt(RecordLayer pkt, Uint8List raw) => _aead.encrypt(pkt, raw);

  /// Decrypt decrypts a DTLS RecordLayer message.
  Uint8List decrypt(Header header, Uint8List inBytes) =>
      _aead.decrypt(header, inBytes);
}
