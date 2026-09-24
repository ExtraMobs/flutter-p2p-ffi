// Port of github.com/pion/dtls/v3 pkg/crypto/signature/signature.go
//
// Provides the implemented Signature Algorithms.

import '../hash/hash.dart';

/// Algorithm as defined in TLS 1.2.
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-16
class SignatureAlgorithm {
  const SignatureAlgorithm(this.value);

  final int value;

  static const SignatureAlgorithm anonymous = SignatureAlgorithm(0);
  static const SignatureAlgorithm rsa = SignatureAlgorithm(1);
  static const SignatureAlgorithm ecdsa = SignatureAlgorithm(3);
  static const SignatureAlgorithm ed25519 = SignatureAlgorithm(7);

  // RSA-PSS (DTLS 1.3 only) - full SignatureScheme values.
  // https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-signaturescheme
  static const SignatureAlgorithm rsaPssRsaeSha256 = SignatureAlgorithm(0x0804);
  static const SignatureAlgorithm rsaPssRsaeSha384 = SignatureAlgorithm(0x0805);
  static const SignatureAlgorithm rsaPssRsaeSha512 = SignatureAlgorithm(0x0806);
  static const SignatureAlgorithm rsaPssPssSha256 = SignatureAlgorithm(0x0809);
  static const SignatureAlgorithm rsaPssPssSha384 = SignatureAlgorithm(0x080a);
  static const SignatureAlgorithm rsaPssPssSha512 = SignatureAlgorithm(0x080b);

  /// IsPSS returns true if the algorithm is an RSA-PSS signature scheme.
  /// It's tempting to check for range between 0x0804 and 0x080b, but 0x0807
  /// is Ed25519 and 0x0808 is Ed448, which are NOT PSS, so specific values
  /// are checked instead.
  bool isPss() =>
      this == rsaPssRsaeSha256 ||
      this == rsaPssRsaeSha384 ||
      this == rsaPssRsaeSha512 ||
      this == rsaPssPssSha256 ||
      this == rsaPssPssSha384 ||
      this == rsaPssPssSha512;

  /// IsUnsupported returns true if the algorithm is a signature scheme that
  /// is not supported by pion/dtls.
  ///
  /// Skip RSA_PSS_PSS schemes (0x0809-0x080b). They are parsed for
  /// interoperability but not negotiated to avoid unnecessary complexity for
  /// certificates that don't exist in practice. This follows the pragmatic
  /// approach of Go's crypto/tls and BoringSSL: target real-world WebPKI use
  /// cases rather than RFC completeness.
  bool isUnsupported() =>
      this == rsaPssPssSha256 ||
      this == rsaPssPssSha384 ||
      this == rsaPssPssSha512;

  /// GetPSSHash returns the hash algorithm associated with an RSA-PSS
  /// signature scheme. Returns [HashAlgorithm.none] if the algorithm is not
  /// an RSA-PSS scheme.
  HashAlgorithm getPssHash() {
    if (this == rsaPssRsaeSha256 || this == rsaPssPssSha256) {
      return HashAlgorithm.sha256;
    }
    if (this == rsaPssRsaeSha384 || this == rsaPssPssSha384) {
      return HashAlgorithm.sha384;
    }
    if (this == rsaPssRsaeSha512 || this == rsaPssPssSha512) {
      return HashAlgorithm.sha512;
    }
    return HashAlgorithm.none;
  }

  @override
  bool operator ==(Object other) =>
      other is SignatureAlgorithm && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SignatureAlgorithm(0x${value.toRadixString(16)})';
}

/// Algorithms returns all implemented Signature Algorithms.
Set<SignatureAlgorithm> signatureAlgorithms() => {
  SignatureAlgorithm.anonymous,
  SignatureAlgorithm.rsa,
  SignatureAlgorithm.ecdsa,
  SignatureAlgorithm.ed25519,
  SignatureAlgorithm.rsaPssRsaeSha256,
  SignatureAlgorithm.rsaPssRsaeSha384,
  SignatureAlgorithm.rsaPssRsaeSha512,
  SignatureAlgorithm.rsaPssPssSha256,
  SignatureAlgorithm.rsaPssPssSha384,
  SignatureAlgorithm.rsaPssPssSha512,
};
