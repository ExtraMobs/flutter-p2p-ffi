// Port of github.com/pion/dtls/v3 pkg/crypto/elliptic/elliptic.go
//
// Provides elliptic curve cryptography for DTLS.

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as pkg_cryptography;
import 'package:pointycastle/export.dart' as pc;

/// errInvalidNamedCurve -> Go's "invalid named curve".
class InvalidNamedCurveException implements Exception {
  const InvalidNamedCurveException();

  @override
  String toString() => 'invalid named curve';
}

/// CurvePointFormat is used to represent the IANA registered curve points.
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xml#tls-parameters-9
class CurvePointFormat {
  const CurvePointFormat(this.value);

  final int value;

  static const CurvePointFormat uncompressed = CurvePointFormat(0);
}

/// CurveType is used to represent the IANA registered curve types for TLS.
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-10
class CurveType {
  const CurveType(this.value);

  final int value;

  static const CurveType namedCurve = CurveType(0x03);

  @override
  bool operator ==(Object other) => other is CurveType && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// CurveTypes returns all known curves.
Set<CurveType> curveTypes() => {CurveType.namedCurve};

/// Curve is used to represent the IANA registered curves for TLS.
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xml#tls-parameters-8
class Curve {
  const Curve(this.value);

  final int value;

  static const Curve p256 = Curve(0x0017);
  static const Curve p384 = Curve(0x0018);
  static const Curve x25519 = Curve(0x001d);

  @override
  String toString() {
    switch (value) {
      case 0x0017:
        return 'P-256';
      case 0x0018:
        return 'P-384';
      case 0x001d:
        return 'X25519';
      default:
        return '0x${value.toRadixString(16)}';
    }
  }

  @override
  bool operator ==(Object other) => other is Curve && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Curves returns all curves this port implements.
Set<Curve> curves() => {Curve.x25519, Curve.p256, Curve.p384};

/// Keypair is a Curve with a Private/Public Keypair.
class Keypair {
  const Keypair({
    required this.curve,
    required this.publicKey,
    required this.privateKey,
  });

  final Curve curve;
  final Uint8List publicKey;
  final Uint8List privateKey;
}

final pkg_cryptography.X25519 _x25519 = pkg_cryptography.X25519();

String _curveDomainName(Curve curve) {
  if (curve == Curve.p256) return 'prime256v1';
  if (curve == Curve.p384) return 'secp384r1';
  throw const InvalidNamedCurveException();
}

int _curveByteLength(Curve curve) {
  if (curve == Curve.p256) return 32;
  if (curve == Curve.p384) return 48;
  throw const InvalidNamedCurveException();
}

Uint8List _bigIntToFixedBytes(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

pc.ECPrivateKey _ecKeyGen(pc.ECDomainParameters domain) {
  final keyGen = pc.ECKeyGenerator();
  final secureRandom = pc.FortunaRandom();
  final seedSource = Random.secure();
  final seed = Uint8List(32);
  for (var i = 0; i < seed.length; i++) {
    seed[i] = seedSource.nextInt(256);
  }
  secureRandom.seed(pc.KeyParameter(seed));
  keyGen.init(
    pc.ParametersWithRandom(pc.ECKeyGeneratorParameters(domain), secureRandom),
  );
  final pair = keyGen.generateKeyPair();
  return pair.privateKey as pc.ECPrivateKey;
}

/// GenerateKeypair generates a keypair for the given Curve.
///
/// Go's `crypto/ecdh` gives synchronous key generation for every curve.
/// `package:pointycastle` (already used elsewhere in this port for stdlib
/// `crypto/*` mappings) covers P-256/P-384 synchronously, but this
/// repository's X25519 support only exists via `package:cryptography`, whose
/// API is asynchronous -- so this port returns a [Future], the smallest
/// adaptation that keeps a single code path for all three curves instead of
/// forking the public API by curve.
Future<Keypair> generateKeypair(Curve curve) async {
  if (curve == Curve.x25519) {
    final kp = await _x25519.newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    return Keypair(
      curve: curve,
      publicKey: Uint8List.fromList(pub.bytes),
      privateKey: Uint8List.fromList(priv),
    );
  }

  final domain = pc.ECDomainParameters(_curveDomainName(curve));
  final priv = _ecKeyGen(domain);
  final pubPoint = domain.G * priv.d;
  final pubBytes = pubPoint!.getEncoded(false); // SEC1 uncompressed: 04||X||Y
  final privBytes = _bigIntToFixedBytes(priv.d!, _curveByteLength(curve));

  return Keypair(
    curve: curve,
    publicKey: Uint8List.fromList(pubBytes),
    privateKey: privBytes,
  );
}
