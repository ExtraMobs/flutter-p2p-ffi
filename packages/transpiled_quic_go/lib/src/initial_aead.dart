// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

import 'header.dart';
import 'varint.dart';

/// Fixed Salt for QUIC Version 1 Initial keys (RFC 9001, Section 5.2).
const List<int> quicSaltV1 = [
  0x38,
  0x76,
  0x2c,
  0xf7,
  0xf5,
  0x59,
  0x34,
  0xb3,
  0x4d,
  0x17,
  0x9a,
  0xe6,
  0xa4,
  0xc8,
  0x0c,
  0xad,
  0xcc,
  0xbb,
  0x7f,
  0x0a,
];

/// HKDF-Extract using HMAC-SHA256.
Uint8List hkdfExtract(List<int> salt, List<int> ikm) {
  final hmac = crypto.Hmac(crypto.sha256, salt.isEmpty ? Uint8List(32) : salt);
  return Uint8List.fromList(hmac.convert(ikm).bytes);
}

/// HKDF-Expand using HMAC-SHA256.
Uint8List hkdfExpand(List<int> prk, List<int> info, int length) {
  final hmac = crypto.Hmac(crypto.sha256, prk);
  final out = BytesBuilder(copy: false);
  var t = <int>[];
  var counter = 1;
  while (out.length < length) {
    final input = <int>[...t, ...info, counter];
    t = hmac.convert(input).bytes;
    out.add(t);
    counter++;
  }
  return Uint8List.sublistView(out.toBytes(), 0, length);
}

/// HKDF-Expand-Label according to RFC 8446 Section 7.1 and RFC 9001 Section 5.1.
Uint8List hkdfExpandLabel(
  List<int> secret,
  String label,
  List<int> context,
  int length,
) {
  final labelBytes = utf8.encode('tls13 $label');
  final info = BytesBuilder(copy: false);
  info.addByte((length >> 8) & 0xff);
  info.addByte(length & 0xff);
  info.addByte(labelBytes.length);
  info.add(labelBytes);
  info.addByte(context.length);
  info.add(context);
  return hkdfExpand(secret, info.toBytes(), length);
}

/// Computes (clientInitialSecret, serverInitialSecret) from the client DCID.
(Uint8List, Uint8List) computeInitialSecrets(Uint8List clientDestConnId) {
  final initialSecret = hkdfExtract(quicSaltV1, clientDestConnId);
  final clientSecret = hkdfExpandLabel(
    initialSecret,
    'client in',
    const [],
    32,
  );
  final serverSecret = hkdfExpandLabel(
    initialSecret,
    'server in',
    const [],
    32,
  );
  return (clientSecret, serverSecret);
}

/// Computes (key, iv, hpKey) from a traffic secret (Initial, Handshake, or 1-RTT).
(Uint8List key, Uint8List iv, Uint8List hpKey) computeKeyAndIv(
  Uint8List secret,
) {
  final key = hkdfExpandLabel(secret, 'quic key', const [], 16);
  final iv = hkdfExpandLabel(secret, 'quic iv', const [], 12);
  final hpKey = hkdfExpandLabel(secret, 'quic hp', const [], 16);
  return (key, iv, hpKey);
}

/// Header protector using AES-ECB mask evaluation (RFC 9001, Section 5.4.1).
class AesHeaderProtector {
  AesHeaderProtector(Uint8List hpKey) {
    _cipher = pc.AESEngine()..init(true, pc.KeyParameter(hpKey));
  }

  late final pc.AESEngine _cipher;

  /// Applies or removes the header protection in-place on header bytes.
  void apply({
    required Uint8List sample,
    required Uint8List headerBytes,
    required int pnOffset,
    required int pnLen,
    required bool isLongHeader,
  }) {
    if (sample.length < 16)
      throw ArgumentError('Sample must be at least 16 bytes');
    final mask = Uint8List(16);
    _cipher.processBlock(sample, 0, mask, 0);

    if (isLongHeader) {
      headerBytes[0] ^= (mask[0] & 0x0f);
    } else {
      headerBytes[0] ^= (mask[0] & 0x1f);
    }

    for (var i = 0; i < pnLen; i++) {
      headerBytes[pnOffset + i] ^= mask[1 + i];
    }
  }
}

/// QUIC AEAD Packet Sealer and Opener using AES-128-GCM (RFC 9001, Section 5.3).
class QuicPacketCipher {
  QuicPacketCipher({required this.key, required this.iv, required this.hp});

  final Uint8List key;
  final Uint8List iv;
  final AesHeaderProtector hp;

  /// Derives the 12-byte per-packet nonce: iv XOR packetNumber (big-endian 64-bit).
  Uint8List _makeNonce(int packetNumber) {
    final nonce = Uint8List.fromList(iv);
    for (var i = 0; i < 8; i++) {
      nonce[11 - i] ^= (packetNumber >> (i * 8)) & 0xff;
    }
    return nonce;
  }

  /// Encrypts and protects a QUIC packet payload and header.
  Uint8List seal({required ExtendedHeader header, required Uint8List payload}) {
    final pnLen = header.packetNumberLen;
    // Set length in header: packetNumberLen + payload ciphertext length (payload.len + 16-byte AEAD tag)
    header.length = pnLen + payload.length + 16;

    final headerBytes = header.append();
    final pnOffset = headerBytes.length - pnLen;

    // AES-128-GCM encrypt
    final nonce = _makeNonce(header.packetNumber);
    final gcm = pc.GCMBlockCipher(pc.AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      128,
      nonce,
      headerBytes,
    );
    gcm.init(true, params);

    final ciphertextBuf = Uint8List(gcm.getOutputSize(payload.length));
    final outLen = gcm.processBytes(
      payload,
      0,
      payload.length,
      ciphertextBuf,
      0,
    );
    final finalLen = gcm.doFinal(ciphertextBuf, outLen);
    final ciphertext = Uint8List.sublistView(
      ciphertextBuf,
      0,
      outLen + finalLen,
    );

    // Apply header protection
    // Sample is taken starting 4 bytes after the packet number field (RFC 9001 Section 5.4.2)
    final sampleOffset = 4 - pnLen;
    final sample = Uint8List.sublistView(
      ciphertext,
      sampleOffset,
      sampleOffset + 16,
    );
    hp.apply(
      sample: sample,
      headerBytes: headerBytes,
      pnOffset: pnOffset,
      pnLen: pnLen,
      isLongHeader: header.isLongHeader,
    );

    final datagram = BytesBuilder(copy: false);
    datagram.add(headerBytes);
    datagram.add(ciphertext);
    return datagram.toBytes();
  }

  /// Removes header protection and decrypts the QUIC packet payload.
  (ExtendedHeader, Uint8List plaintext) open(
    Uint8List packetBytes, {
    int destConnIdLen = 0,
    int largestPn = 0,
  }) {
    if (packetBytes.length < 25) {
      throw const FormatException('Packet too short for QUIC AEAD');
    }

    // Work on a mutable copy of packet bytes to unmask header in place
    final buf = Uint8List.fromList(packetBytes);
    final isLong = (buf[0] & 0x80) != 0;

    // 1. Locate packet number offset and sample
    int pnOffset;
    if (isLong) {
      var cursor = 5; // 1 type + 4 version
      final dcidLen = buf[cursor++];
      cursor += dcidLen;
      final scidLen = buf[cursor++];
      cursor += scidLen;

      final type = (buf[0] >> 4) & 0x03;
      if (type == packetTypeInitial) {
        final (tokenLen, n1) = parseVarInt(buf, cursor);
        cursor += n1 + tokenLen;
      }
      final (_, n2) = parseVarInt(buf, cursor);
      cursor += n2;
      pnOffset = cursor;
    } else {
      pnOffset = 1 + destConnIdLen;
    }

    // 2. Unmask header: sample is at pnOffset + 4
    final sample = Uint8List.sublistView(buf, pnOffset + 4, pnOffset + 20);
    // Determine packet number length by unmasking first byte temporarily
    final mask = Uint8List(16);
    hp._cipher.processBlock(sample, 0, mask, 0);
    if (isLong) {
      buf[0] ^= (mask[0] & 0x0f);
    } else {
      buf[0] ^= (mask[0] & 0x1f);
    }
    final pnLen = (buf[0] & 0x03) + 1;

    for (var i = 0; i < pnLen; i++) {
      buf[pnOffset + i] ^= mask[1 + i];
    }

    // 3. Parse ExtendedHeader from unmasked bytes
    final (header, headerLen) = ExtendedHeader.parse(
      buf,
      destConnIdLen: destConnIdLen,
    );

    // 4. Ciphertext slice
    final ciphertextLen = isLong
        ? (header.length - pnLen)
        : (packetBytes.length - headerLen);
    if (headerLen + ciphertextLen > packetBytes.length) {
      throw const FormatException('Truncated ciphertext in QUIC packet');
    }
    final ciphertext = Uint8List.sublistView(
      packetBytes,
      headerLen,
      headerLen + ciphertextLen,
    );
    final unmaskedHeaderBytes = Uint8List.sublistView(buf, 0, headerLen);

    // 5. AES-128-GCM decrypt
    final nonce = _makeNonce(header.packetNumber);
    final gcm = pc.GCMBlockCipher(pc.AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(key),
      128,
      nonce,
      unmaskedHeaderBytes,
    );
    gcm.init(false, params);

    final plaintext = Uint8List(gcm.getOutputSize(ciphertext.length));
    final outLen = gcm.processBytes(
      ciphertext,
      0,
      ciphertext.length,
      plaintext,
      0,
    );
    final finalLen = gcm.doFinal(plaintext, outLen);

    return (header, Uint8List.sublistView(plaintext, 0, outLen + finalLen));
  }
}
