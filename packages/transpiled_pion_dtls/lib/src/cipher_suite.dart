import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

import 'pkg/crypto/prf/prf.dart';
import 'internal/util/util.dart';
import 'pkg/protocol/protocol.dart';
import 'pkg/protocol/recordlayer/recordlayer.dart';

// CipherSuite ID constants
const int TLS_ECDHE_ECDSA_WITH_AES_128_CCM = 0xC0AC;
const int TLS_ECDHE_ECDSA_WITH_AES_128_CCM_8 = 0xC0AE;
const int TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 = 0xC02B;
const int TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 = 0xC02F;
const int TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 = 0xC02C;
const int TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 = 0xC030;
const int TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA = 0xC00A;
const int TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA = 0xC014;
const int TLS_PSK_WITH_AES_128_CCM = 0xC0A4;
const int TLS_PSK_WITH_AES_128_CCM_8 = 0xC0A8;
const int TLS_PSK_WITH_AES_256_CCM_8 = 0xC0A9;
const int TLS_PSK_WITH_AES_128_GCM_SHA256 = 0x00A8;
const int TLS_PSK_WITH_AES_128_CBC_SHA256 = 0x00AE;
const int TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256 = 0xC035;

// Authentication types
const int cipherSuiteAuthenticationTypeCertificate = 0;
const int cipherSuiteAuthenticationTypePreSharedKey = 1;
const int cipherSuiteAuthenticationTypeAnonymous = 2;

// Key exchange algorithms
const int cipherSuiteKeyExchangeAlgorithmNone = 0;
const int cipherSuiteKeyExchangeAlgorithmPsk = 1;
const int cipherSuiteKeyExchangeAlgorithmEcdhe = 2;

// Certificate types
const int clientCertificateTypeEcdsaSign = 64;
const int clientCertificateTypeRsaSign = 1;

/// String representation of CipherSuiteID.
String cipherSuiteName(int id) {
  switch (id) {
    case TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:
      return 'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256';
    case TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:
      return 'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384';
    case TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA:
      return 'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA';
    case TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:
      return 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256';
    case TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:
      return 'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384';
    case TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA:
      return 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA';
    case TLS_PSK_WITH_AES_128_GCM_SHA256:
      return 'TLS_PSK_WITH_AES_128_GCM_SHA256';
    case TLS_PSK_WITH_AES_128_CBC_SHA256:
      return 'TLS_PSK_WITH_AES_128_CBC_SHA256';
    case TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256:
      return 'TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256';
    default:
      return '0x${id.toRadixString(16)}';
  }
}

/// Returns default supported cipher suites.
List<int> cipherSuites() => [
  TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
  TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
  TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
];

/// Returns insecure cipher suites.
List<int> insecureCipherSuites() => [];

/// CipherSuite interface for DTLS cipher suites.
abstract class CipherSuite {
  String string();
  int id();
  int certificateType();
  HashFunc hashFunc();
  int authenticationType();
  int keyExchangeAlgorithm();
  bool ecc();
  void init(
    Uint8List masterSecret,
    Uint8List clientRandom,
    Uint8List serverRandom,
    bool isClient,
  );
  bool isInitialized();
  Uint8List encrypt(RecordLayer pkt, Uint8List raw);
  Uint8List decrypt(RecordLayer pkt, Uint8List inData);
}

/// Helper to generate the 13-byte additional data for AEAD records.
Uint8List generateAeadAdditionalData(Header h, int payloadLen) {
  final additionalData = Uint8List(13);
  additionalData[0] = (h.epoch >> 8) & 0xFF;
  additionalData[1] = h.epoch & 0xFF;
  final seq = h.sequenceNumber;
  additionalData[2] = (seq >> 40) & 0xFF;
  additionalData[3] = (seq >> 32) & 0xFF;
  additionalData[4] = (seq >> 24) & 0xFF;
  additionalData[5] = (seq >> 16) & 0xFF;
  additionalData[6] = (seq >> 8) & 0xFF;
  additionalData[7] = seq & 0xFF;
  additionalData[8] = h.contentType.value;
  additionalData[9] = h.version.major;
  additionalData[10] = h.version.minor;
  additionalData[11] = (payloadLen >> 8) & 0xFF;
  additionalData[12] = payloadLen & 0xFF;
  return additionalData;
}

/// GcmCipher implements DTLS 1.2 AES-GCM encryption/decryption.
class GcmCipher {
  final Uint8List localKey;
  final Uint8List localWriteIv;
  final Uint8List remoteKey;
  final Uint8List remoteWriteIv;

  GcmCipher({
    required this.localKey,
    required this.localWriteIv,
    required this.remoteKey,
    required this.remoteWriteIv,
  });

  Uint8List encrypt(RecordLayer pkt, Uint8List raw) {
    final headerSize = pkt.header.size();
    final payload = raw.sublist(headerSize);

    // 12-byte nonce: 4 bytes salt + 8 bytes explicit nonce (epoch + seqNum)
    final nonce = Uint8List(12);
    nonce.setRange(0, 4, localWriteIv.sublist(0, 4));
    nonce[4] = (pkt.header.epoch >> 8) & 0xFF;
    nonce[5] = pkt.header.epoch & 0xFF;
    final seq = pkt.header.sequenceNumber;
    nonce[6] = (seq >> 40) & 0xFF;
    nonce[7] = (seq >> 32) & 0xFF;
    nonce[8] = (seq >> 24) & 0xFF;
    nonce[9] = (seq >> 16) & 0xFF;
    nonce[10] = (seq >> 8) & 0xFF;
    nonce[11] = seq & 0xFF;

    final ad = generateAeadAdditionalData(pkt.header, payload.length);

    final cipher = pc.GCMBlockCipher(pc.AESEngine());
    cipher.init(
      true,
      pc.AEADParameters(pc.KeyParameter(localKey), 128, nonce, ad),
    );

    final out = Uint8List(cipher.getOutputSize(payload.length));
    final len = cipher.processBytes(payload, 0, payload.length, out, 0);
    final fin = cipher.doFinal(out, len);
    final ciphertext = out.sublist(0, len + fin);

    // Output: raw header + 8 bytes explicit nonce + ciphertext + 16 bytes tag
    final explicitNonce = nonce.sublist(4, 12);
    final headerRaw = raw.sublist(0, headerSize);

    final totalLen = headerSize + explicitNonce.length + ciphertext.length;
    final r = Uint8List(totalLen);
    r.setRange(0, headerSize, headerRaw);
    r.setRange(headerSize, headerSize + 8, explicitNonce);
    r.setRange(headerSize + 8, totalLen, ciphertext);

    // Update length in record header
    final contentLen = explicitNonce.length + ciphertext.length;
    r[headerSize - 2] = (contentLen >> 8) & 0xFF;
    r[headerSize - 1] = contentLen & 0xFF;

    return r;
  }

  Uint8List decrypt(RecordLayer pkt, Uint8List inData) {
    final headerSize = pkt.header.size();
    if (inData.length <= headerSize + 8 + 16) {
      throw const FormatException('Ciphertext too short for GCM');
    }

    final recordLength = (inData[headerSize - 2] << 8) | inData[headerSize - 1];
    final recordData = inData.length >= headerSize + recordLength
        ? inData.sublist(0, headerSize + recordLength)
        : inData;

    final explicitNonce = recordData.sublist(headerSize, headerSize + 8);
    final ciphertextAndTag = recordData.sublist(headerSize + 8);

    final nonce = Uint8List(12);
    nonce.setRange(0, 4, remoteWriteIv.sublist(0, 4));
    nonce.setRange(4, 12, explicitNonce);

    final payloadLen = ciphertextAndTag.length - 16;
    final ad = generateAeadAdditionalData(pkt.header, payloadLen);

    final cipher = pc.GCMBlockCipher(pc.AESEngine());
    cipher.init(
      false,
      pc.AEADParameters(pc.KeyParameter(remoteKey), 128, nonce, ad),
    );

    final out = Uint8List(cipher.getOutputSize(ciphertextAndTag.length));
    final len = cipher.processBytes(
      ciphertextAndTag,
      0,
      ciphertextAndTag.length,
      out,
      0,
    );
    final finalLen = cipher.doFinal(out, len);
    final decrypted = out.sublist(0, len + finalLen);

    final r = Uint8List(headerSize + decrypted.length);
    r.setRange(0, headerSize, inData.sublist(0, headerSize));
    r.setRange(headerSize, r.length, decrypted);
    return r;
  }
}
