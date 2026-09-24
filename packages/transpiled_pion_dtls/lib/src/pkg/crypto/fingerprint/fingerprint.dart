// Port of github.com/pion/dtls/v3 pkg/crypto/fingerprint/fingerprint.go
//
// Provides a helper to create a fingerprint string from a certificate.

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;

/// errHashUnavailable -> Go's "fingerprint: hash algorithm is not linked
/// into the binary". `package:crypto`'s [pkg_crypto.Hash] values are always
/// linked in, so this is only thrown for the null placeholder.
class HashUnavailableException implements Exception {
  const HashUnavailableException();

  @override
  String toString() =>
      'fingerprint: hash algorithm is not linked into the binary';
}

/// Fingerprint creates a fingerprint for a certificate using the specified
/// hash algorithm.
///
/// Go's signature takes an `*x509.Certificate` and hashes `cert.Raw` (the
/// certificate's ASN.1 DER encoding). No X.509 parser/encoder has been
/// ported into this module boundary yet (see PROGRESS.md), so this takes
/// the DER bytes directly -- the exact bytes Go's `cert.Raw` already is --
/// rather than a certificate object.
String fingerprint(Uint8List certDer, pkg_crypto.Hash? algo) {
  if (algo == null) {
    throw const HashUnavailableException();
  }
  final digestBytes = Uint8List.fromList(algo.convert(certDer).bytes);
  final digest = _hexEncode(digestBytes);

  final digestlen = digest.length;
  if (digestlen == 0) {
    return '';
  }

  final res = StringBuffer();
  for (var i = 0; i < digest.length; i++) {
    res.write(digest[i]);
    if (i.isOdd && i < digestlen - 1) {
      res.write(':');
    }
  }

  return res.toString();
}

const List<String> _hexDigits = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
];

String _hexEncode(Uint8List bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(_hexDigits[(b >> 4) & 0xF]);
    out.write(_hexDigits[b & 0xF]);
  }
  return out.toString();
}
