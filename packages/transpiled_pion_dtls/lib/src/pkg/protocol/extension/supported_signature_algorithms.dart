part of 'extension.dart';

// Port of pkg/protocol/extension/supported_signature_algorithms.go.

/// SupportedSignatureAlgorithms allows a Client/Server to negotiate what
/// SignatureHash Algorithms they both support.
/// https://tools.ietf.org/html/rfc5246#section-7.4.1.4.1
///
/// Port of `SupportedSignatureAlgorithms` (supported_signature_algorithms.go:12-14)
/// and its methods `TypeValue`/`Marshal`/`Unmarshal`
/// (supported_signature_algorithms.go:17-36).
final class SupportedSignatureAlgorithms implements Extension {
  List<signaturehash.Algorithm> signatureHashAlgorithms;

  SupportedSignatureAlgorithms([List<signaturehash.Algorithm>? algorithms])
    : signatureHashAlgorithms = algorithms ?? [];

  @override
  TypeValue get typeValue => TypeValue.supportedSignatureAlgorithms;

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
