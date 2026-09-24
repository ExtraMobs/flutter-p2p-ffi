part of 'extension.dart';

// Port of pkg/protocol/extension/signature_algorithms_cert.go.

/// SignatureAlgorithmsCert allows a Client/Server to indicate which
/// signature algorithms may be used in digital signatures for X.509
/// certificates. This is separate from signature_algorithms which applies
/// to handshake signatures.
///
/// RFC 8446 Section 4.2.3: "TLS 1.2 implementations SHOULD also process this
/// extension. If present, the signature_algorithms_cert extension SHALL be
/// treated as being equivalent to signature_algorithms for the purposes of
/// certificate chain validation."
/// https://tools.ietf.org/html/rfc8446#section-4.2.3
///
/// Port of `SignatureAlgorithmsCert` (signature_algorithms_cert.go:19-21)
/// and its methods `TypeValue`/`Marshal`/`Unmarshal`
/// (signature_algorithms_cert.go:24-43).
final class SignatureAlgorithmsCert implements Extension {
  List<signaturehash.Algorithm> signatureHashAlgorithms;

  SignatureAlgorithmsCert([List<signaturehash.Algorithm>? algorithms])
    : signatureHashAlgorithms = algorithms ?? [];

  @override
  TypeValue get typeValue => TypeValue.signatureAlgorithmsCert;

  @override
  Uint8List marshal() =>
      _marshalGenericSignatureHashAlgorithm(typeValue, signatureHashAlgorithms);

  @override
  void unmarshal(Uint8List data) {
    signatureHashAlgorithms = [];
    _unmarshalGenericSignatureHashAlgorithm(
      typeValue,
      data,
      signatureHashAlgorithms,
    );
  }
}
