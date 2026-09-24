// Port of github.com/pion/dtls/v3 pkg/crypto/fingerprint/hash.go

import 'package:crypto/crypto.dart' as pkg_crypto;

/// errInvalidHashAlgorithm -> Go's "fingerprint: invalid hash algorithm".
class InvalidHashAlgorithmException implements Exception {
  const InvalidHashAlgorithmException();

  @override
  String toString() => 'fingerprint: invalid hash algorithm';
}

Map<String, pkg_crypto.Hash> _nameToHash() => {
  'md5': pkg_crypto.md5, // [RFC3279]
  'sha-1': pkg_crypto.sha1, // [RFC3279]
  'sha-224': pkg_crypto.sha224, // [RFC4055]
  'sha-256': pkg_crypto.sha256, // [RFC4055]
  'sha-384': pkg_crypto.sha384, // [RFC4055]
  'sha-512': pkg_crypto.sha512, // [RFC4055]
};

/// HashFromString allows looking up a hash algorithm by its string
/// representation.
pkg_crypto.Hash hashFromString(String s) {
  final h = _nameToHash()[s.toLowerCase()];
  if (h == null) {
    throw const InvalidHashAlgorithmException();
  }
  return h;
}

/// StringFromHash allows looking up a string representation of the hash.
String stringFromHash(pkg_crypto.Hash hash) {
  for (final entry in _nameToHash().entries) {
    if (entry.value == hash) {
      return entry.key;
    }
  }
  throw const InvalidHashAlgorithmException();
}
