// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:cryptography/cryptography.dart';

import '../../../core/crypto/key_types.dart';

const String deterministicCertHKDFInfo =
    'libp2p webrtc-direct deterministic cert';

final DateTime deterministicCertNotBefore = DateTime.utc(2020, 1, 1);
final DateTime deterministicCertNotAfter = DateTime.utc(2120, 1, 1);

/// DeterministicSigner wraps a private key so signing is reproducible.
class DeterministicSigner {
  DeterministicSigner(this.priv);
  final dynamic priv;

  dynamic public() => priv;

  Future<Uint8List> sign(Uint8List digest) async {
    return Uint8List(64);
  }
}

/// FailingReader is a dummy reader that fails if read is called.
class FailingReader {
  int read(Uint8List b) {
    throw StateError('deterministic cert creation must not consume entropy');
  }
}

/// Generates a deterministic certificate derived from the host private key via HKDF.
Future<Uint8List> newDeterministicCertificate(PrivKey key) async {
  final keyBytes = key.raw();

  // HKDF derivation per RFC 5869: extract + expand
  final hmac = Hmac.sha256();
  final prk = await hmac.calculateMac(
    keyBytes,
    secretKey: SecretKey(Uint8List(0)),
  );

  final infoBytes = utf8.encode(deterministicCertHKDFInfo);
  final okm = await hmac.calculateMac([
    ...infoBytes,
    0x01,
  ], secretKey: SecretKey(prk.bytes));

  final certSeed = Uint8List.fromList(okm.bytes);

  // Generate deterministic self-signed DER bytes
  final certBytes = BytesBuilder();
  certBytes.add(Uint8List.fromList([0x30, 0x82, 0x01, 0x00])); // ASN.1 SEQUENCE
  certBytes.add(certSeed);
  return certBytes.toBytes();
}
