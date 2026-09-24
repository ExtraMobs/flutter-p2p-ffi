// Port of github.com/pion/dtls/v3 pkg/crypto/prf/prf.go
//
// Implements the TLS 1.2 Pseudorandom Functions.

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:cryptography/cryptography.dart' as pkg_cryptography;
import 'package:pointycastle/export.dart' as pc;

import '../elliptic/elliptic.dart';

const String _masterSecretLabel = 'master secret';
const String _extendedMasterSecretLabel = 'extended master secret';
const String _keyExpansionLabel = 'key expansion';
const String _verifyDataClientLabel = 'client finished';
const String _verifyDataServerLabel = 'server finished';

/// HashFunc allows callers to decide what hash is used in PRF.
///
/// Mirrors Go's named function type `type HashFunc func() hash.Hash`; Dart
/// has no non-typedef way to name a function signature, and this is a type
/// alias declared in the upstream Go repository itself, matching the
/// AGENTS.md exception for typedefs.
typedef HashFunc = pkg_crypto.Hash Function();

final pkg_cryptography.X25519 _x25519Algorithm = pkg_cryptography.X25519();

/// EncryptionKeys is all the state needed for a TLS CipherSuite.
class EncryptionKeys {
  const EncryptionKeys({
    required this.masterSecret,
    required this.clientMacKey,
    required this.serverMacKey,
    required this.clientWriteKey,
    required this.serverWriteKey,
    required this.clientWriteIv,
    required this.serverWriteIv,
  });

  final Uint8List masterSecret;
  final Uint8List clientMacKey;
  final Uint8List serverMacKey;
  final Uint8List clientWriteKey;
  final Uint8List serverWriteKey;
  final Uint8List clientWriteIv;
  final Uint8List serverWriteIv;

  @override
  String toString() =>
      'encryptionKeys:\n'
      '- masterSecret: $masterSecret\n'
      '- clientMACKey: $clientMacKey\n'
      '- serverMACKey: $serverMacKey\n'
      '- clientWriteKey: $clientWriteKey\n'
      '- serverWriteKey: $serverWriteKey\n'
      '- clientWriteIV: $clientWriteIv\n'
      '- serverWriteIV: $serverWriteIv\n';
}

Uint8List _concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, p) => sum + p.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}

Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);

/// PSKPreMasterSecret generates the PSK Premaster Secret. The premaster
/// secret is formed as follows: if the PSK is N octets long, concatenate a
/// uint16 with the value N, N zero octets, a second uint16 with the value
/// N, and the PSK itself.
///
/// https://tools.ietf.org/html/rfc4279#section-2
Uint8List pskPreMasterSecret(Uint8List psk) {
  final pskLen = psk.length;
  final out = Uint8List(2 + pskLen + 2 + pskLen);
  final view = ByteData.sublistView(out);
  view.setUint16(0, pskLen);
  out.setRange(2, 2 + pskLen, psk);
  view.setUint16(2 + pskLen, pskLen);
  out.setRange(2 + pskLen + 2, out.length, psk);
  return out;
}

/// EcdhePSKPreMasterSecret implements TLS 1.2 Premaster Secret generation
/// given a psk, a keypair and a curve.
///
/// https://datatracker.ietf.org/doc/html/rfc5489#section-2
Future<Uint8List> ecdhePskPreMasterSecret(
  Uint8List psk,
  Uint8List publicKey,
  Uint8List privateKey,
  Curve curve,
) async {
  final preMaster = await preMasterSecret(publicKey, privateKey, curve);
  final out = Uint8List(2 + preMaster.length + 2 + psk.length);
  final view = ByteData.sublistView(out);
  var offset = 0;
  view.setUint16(offset, preMaster.length);
  offset += 2;
  out.setRange(offset, offset + preMaster.length, preMaster);
  offset += preMaster.length;
  view.setUint16(offset, psk.length);
  offset += 2;
  out.setRange(offset, out.length, psk);
  return out;
}

/// PreMasterSecret implements TLS 1.2 Premaster Secret generation given a
/// keypair and a curve.
///
/// Go's `crypto/ecdh` computes this synchronously for every curve; this
/// module's only available X25519 implementation (`package:cryptography`)
/// is asynchronous, so the port returns a [Future] for all curves rather
/// than forking the API by curve (see elliptic.dart's `generateKeypair`
/// for the same trade-off).
Future<Uint8List> preMasterSecret(
  Uint8List publicKey,
  Uint8List privateKey,
  Curve curve,
) async {
  if (curve == Curve.x25519) {
    final keyPair = await _x25519Algorithm.newKeyPairFromSeed(privateKey);
    final shared = await _x25519Algorithm.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: pkg_cryptography.SimplePublicKey(
        publicKey,
        type: pkg_cryptography.KeyPairType.x25519,
      ),
    );
    return Uint8List.fromList(await shared.extractBytes());
  }

  if (curve != Curve.p256 && curve != Curve.p384) {
    throw const InvalidNamedCurveException();
  }

  return _ecdhAgreementSync(publicKey, privateKey, curve);
}

/// PHash is the PRF -- the SHA-256 hash function is used for all cipher
/// suites defined in this TLS 1.2 document and in TLS documents published
/// prior to this document when TLS 1.2 is negotiated. New cipher suites
/// MUST explicitly specify a PRF and, in general, SHOULD use the TLS PRF
/// with SHA-256 or a stronger standard hash function.
///
///     P_hash(secret, seed) = HMAC_hash(secret, A(1) + seed) +
///                            HMAC_hash(secret, A(2) + seed) +
///                            HMAC_hash(secret, A(3) + seed) + ...
///
/// A() is defined as:
///
///     A(0) = seed
///     A(i) = HMAC_hash(secret, A(i-1))
///
/// P_hash can be iterated as many times as necessary to produce the
/// required quantity of data.
///
/// https://tools.ietf.org/html/rfc4346w
Uint8List pHash(
  Uint8List secret,
  Uint8List seed,
  int requestedLength,
  HashFunc hashFunc,
) {
  Uint8List hmacHash(Uint8List key, Uint8List data) {
    final mac = pkg_crypto.Hmac(hashFunc(), key);
    return Uint8List.fromList(mac.convert(data).bytes);
  }

  var lastRound = seed;
  final out = BytesBuilder();

  final hashLen = hashFunc().convert(const []).bytes.length;
  final iterations = (requestedLength / hashLen).ceil();

  for (var i = 0; i < iterations; i++) {
    lastRound = hmacHash(secret, lastRound);
    final withSecret = hmacHash(secret, _concat([lastRound, seed]));
    out.add(withSecret);
  }

  final all = out.toBytes();
  return Uint8List.fromList(all.sublist(0, requestedLength));
}

/// ExtendedMasterSecret generates an Extended MasterSecret as defined in
/// https://tools.ietf.org/html/rfc7627
Uint8List extendedMasterSecret(
  Uint8List preMasterSecret,
  Uint8List sessionHash,
  HashFunc h,
) {
  final seed = _concat([_ascii(_extendedMasterSecretLabel), sessionHash]);
  return pHash(preMasterSecret, seed, 48, h);
}

/// MasterSecret generates a TLS 1.2 MasterSecret.
Uint8List masterSecret(
  Uint8List preMasterSecret,
  Uint8List clientRandom,
  Uint8List serverRandom,
  HashFunc h,
) {
  final seed = _concat([
    _ascii(_masterSecretLabel),
    clientRandom,
    serverRandom,
  ]);
  return pHash(preMasterSecret, seed, 48, h);
}

/// GenerateEncryptionKeys is the final step of the TLS 1.2 PRF. Given all
/// state generated so far, generates the final keys needed for encryption.
EncryptionKeys generateEncryptionKeys(
  Uint8List masterSecret,
  Uint8List clientRandom,
  Uint8List serverRandom,
  int macLen,
  int keyLen,
  int ivLen,
  HashFunc h,
) {
  final seed = _concat([
    _ascii(_keyExpansionLabel),
    serverRandom,
    clientRandom,
  ]);
  var keyMaterial = pHash(
    masterSecret,
    seed,
    (2 * macLen) + (2 * keyLen) + (2 * ivLen),
    h,
  );

  final clientMacKey = keyMaterial.sublist(0, macLen);
  keyMaterial = keyMaterial.sublist(macLen);

  final serverMacKey = keyMaterial.sublist(0, macLen);
  keyMaterial = keyMaterial.sublist(macLen);

  final clientWriteKey = keyMaterial.sublist(0, keyLen);
  keyMaterial = keyMaterial.sublist(keyLen);

  final serverWriteKey = keyMaterial.sublist(0, keyLen);
  keyMaterial = keyMaterial.sublist(keyLen);

  final clientWriteIv = keyMaterial.sublist(0, ivLen);
  keyMaterial = keyMaterial.sublist(ivLen);

  final serverWriteIv = keyMaterial.sublist(0, ivLen);

  return EncryptionKeys(
    masterSecret: masterSecret,
    clientMacKey: clientMacKey,
    serverMacKey: serverMacKey,
    clientWriteKey: clientWriteKey,
    serverWriteKey: serverWriteKey,
    clientWriteIv: clientWriteIv,
    serverWriteIv: serverWriteIv,
  );
}

Uint8List _prfVerifyData(
  Uint8List masterSecret,
  Uint8List handshakeBodies,
  String label,
  HashFunc hashFunc,
) {
  final h = hashFunc().convert(handshakeBodies).bytes;
  final seed = _concat([_ascii(label), Uint8List.fromList(h)]);
  return pHash(masterSecret, seed, 12, hashFunc);
}

/// VerifyDataClient is called on the Client Side to either verify or
/// generate the VerifyData message.
Uint8List verifyDataClient(
  Uint8List masterSecret,
  Uint8List handshakeBodies,
  HashFunc h,
) => _prfVerifyData(masterSecret, handshakeBodies, _verifyDataClientLabel, h);

/// VerifyDataServer is called on the Server Side to either verify or
/// generate the VerifyData message.
Uint8List verifyDataServer(
  Uint8List masterSecret,
  Uint8List handshakeBodies,
  HashFunc h,
) => _prfVerifyData(masterSecret, handshakeBodies, _verifyDataServerLabel, h);

/// Synchronous NIST-curve ECDH (P-256/P-384) via pointycastle, returning the
/// raw shared X-coordinate at the curve's fixed byte length, matching Go's
/// `crypto/ecdh` `(*PrivateKey).ECDH`.
Uint8List _ecdhAgreementSync(
  Uint8List publicKey,
  Uint8List privateKey,
  Curve curve,
) {
  final domainName = curve == Curve.p256 ? 'prime256v1' : 'secp384r1';
  final byteLen = curve == Curve.p256 ? 32 : 48;
  final domain = pc.ECDomainParameters(domainName);

  final point = domain.curve.decodePoint(publicKey);
  if (point == null) {
    throw const InvalidNamedCurveException();
  }
  final remotePublicKey = pc.ECPublicKey(point, domain);

  final d = _bytesToBigInt(privateKey);
  final localPrivateKey = pc.ECPrivateKey(d, domain);

  final agreement = pc.ECDHBasicAgreement()..init(localPrivateKey);
  final shared = agreement.calculateAgreement(remotePublicKey);

  return _bigIntToFixedBytesLocal(shared, byteLen);
}

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

Uint8List _bigIntToFixedBytesLocal(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}
