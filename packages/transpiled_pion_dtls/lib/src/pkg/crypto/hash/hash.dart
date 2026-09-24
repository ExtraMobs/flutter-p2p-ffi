// Port of github.com/pion/dtls/v3 pkg/crypto/hash/hash.go
//
// Provides the TLS HashAlgorithm as defined in TLS 1.2.

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;

/// Algorithm is used to indicate the hash algorithm used.
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-18
class HashAlgorithm {
  const HashAlgorithm(this.value);

  final int value;

  static const HashAlgorithm none = HashAlgorithm(0); // Blacklisted
  static const HashAlgorithm md5 = HashAlgorithm(1); // Blacklisted
  static const HashAlgorithm sha1 = HashAlgorithm(2); // Blacklisted
  static const HashAlgorithm sha224 = HashAlgorithm(3);
  static const HashAlgorithm sha256 = HashAlgorithm(4);
  static const HashAlgorithm sha384 = HashAlgorithm(5);
  static const HashAlgorithm sha512 = HashAlgorithm(6);
  static const HashAlgorithm ed25519 = HashAlgorithm(8);

  /// String makes hashAlgorithm printable.
  @override
  String toString() {
    switch (value) {
      case 0:
        return 'none';
      case 1:
        return 'md5'; // [RFC3279]
      case 2:
        return 'sha-1'; // [RFC3279]
      case 3:
        return 'sha-224'; // [RFC4055]
      case 4:
        return 'sha-256'; // [RFC4055]
      case 5:
        return 'sha-384'; // [RFC4055]
      case 6:
        return 'sha-512'; // [RFC4055]
      case 8:
        return 'null';
      default:
        return 'unknown or unsupported hash algorithm';
    }
  }

  /// Digest performs a digest on the passed value.
  Uint8List? digest(Uint8List b) {
    switch (value) {
      case 0:
        return null;
      case 1:
        return Uint8List.fromList(pkg_crypto.md5.convert(b).bytes);
      case 2:
        return Uint8List.fromList(pkg_crypto.sha1.convert(b).bytes);
      case 3:
        return Uint8List.fromList(pkg_crypto.sha224.convert(b).bytes);
      case 4:
        return Uint8List.fromList(pkg_crypto.sha256.convert(b).bytes);
      case 5:
        return Uint8List.fromList(pkg_crypto.sha384.convert(b).bytes);
      case 6:
        return Uint8List.fromList(pkg_crypto.sha512.convert(b).bytes);
      default:
        return null;
    }
  }

  /// Insecure returns if the given HashAlgorithm is considered secure in
  /// DTLS 1.2.
  bool insecure() => value == 0 || value == 1 || value == 2;

  /// CryptoHash returns the `package:crypto` [pkg_crypto.Hash] implementation
  /// for the given HashAlgorithm, standing in for Go's `crypto.Hash` enum:
  /// unlike Go's registry-of-constructors, `package:crypto`'s [pkg_crypto.Hash]
  /// instances (e.g. [pkg_crypto.sha256]) are directly usable digesters, so
  /// this doubles as both the identifier and the callable hash.
  pkg_crypto.Hash? cryptoHash() {
    switch (value) {
      case 0:
        return null;
      case 1:
        return pkg_crypto.md5;
      case 2:
        return pkg_crypto.sha1;
      case 3:
        return pkg_crypto.sha224;
      case 4:
        return pkg_crypto.sha256;
      case 5:
        return pkg_crypto.sha384;
      case 6:
        return pkg_crypto.sha512;
      case 8:
        return null;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is HashAlgorithm && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Algorithms returns all the supported Hash Algorithms.
///
/// Go's `map[Algorithm]struct{}` (a set encoded as a map with empty values)
/// becomes a plain [Set] in Dart.
Set<HashAlgorithm> hashAlgorithms() => {
  HashAlgorithm.none,
  HashAlgorithm.md5,
  HashAlgorithm.sha1,
  HashAlgorithm.sha224,
  HashAlgorithm.sha256,
  HashAlgorithm.sha384,
  HashAlgorithm.sha512,
  HashAlgorithm.ed25519,
};

/// ExtractHashFromPSS extracts the hash algorithm from an RSA-PSS
/// SignatureScheme value. This handles TLS 1.3 PSS schemes. Returns
/// [HashAlgorithm.none] if the scheme is not a recognized PSS scheme.
HashAlgorithm extractHashFromPss(int pssScheme) {
  switch (pssScheme) {
    case 0x0804:
    case 0x0809:
      return HashAlgorithm.sha256;
    case 0x0805:
    case 0x080a:
      return HashAlgorithm.sha384;
    case 0x0806:
    case 0x080b:
      return HashAlgorithm.sha512;
    default:
      return HashAlgorithm.none;
  }
}
