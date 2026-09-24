part of 'extension.dart';

// Port of pkg/protocol/extension/generic_signature_hash_extension.go.
//
// Depends on `pkg/crypto/hash`, `pkg/crypto/signature`,
// `pkg/crypto/signaturehash`, owned by a concurrent agent -- see
// `extension.dart`'s library doc.

/// marshalGenericSignatureHashAlgorithm encodes the extension. This supports
/// hybrid encoding: TLS 1.3 PSS schemes are encoded as full uint16, while
/// TLS 1.2 schemes use hash (high byte) + signature (low byte) encoding.
///
/// Port of `marshalGenericSignatureHashAlgorithm`
/// (generic_signature_hash_extension.go:15-35).
Uint8List _marshalGenericSignatureHashAlgorithm(
  TypeValue typeValue,
  List<signaturehash.Algorithm> sigHashAlgs,
) {
  final builder = _CryptobyteBuilder();
  builder.addUint16(typeValue.value);
  builder.addUint16LengthPrefixed((extBuilder) {
    extBuilder.addUint16LengthPrefixed((algBuilder) {
      for (final v in sigHashAlgs) {
        if (v.signature.isPSS()) {
          algBuilder.addUint16(v.signature.value);
        } else {
          algBuilder.addUint8(v.hash.value);
          algBuilder.addUint8(v.signature.value);
        }
      }
    });
  });
  return builder.toBytes();
}

/// unmarshalGenericSignatureAlgorithm populates the extension from encoded
/// data. This supports hybrid encoding: detects TLS 1.3 PSS schemes and
/// handles them as full uint16, while TLS 1.2 schemes use byte-split
/// encoding.
///
/// Port of `unmarshalGenericSignatureHashAlgorithm`
/// (generic_signature_hash_extension.go:39-77).
void _unmarshalGenericSignatureHashAlgorithm(
  TypeValue typeValue,
  Uint8List data,
  List<signaturehash.Algorithm> dst,
) {
  final val = _CryptobyteReader(data);
  final extension = val.readUint16();
  if (extension != typeValue.value) throw _errInvalidExtensionType;

  final extData = val.readUint16LengthPrefixedReader();
  final algData = extData.readUint16LengthPrefixedReader();

  final hashAlgorithms = hash.algorithms();
  final signatureAlgorithms = signature.algorithms();

  while (!algData.isEmpty) {
    final scheme = algData.readUint16();
    final parsed = parseSignatureScheme(scheme);
    if (hashAlgorithms.contains(parsed.hash) &&
        signatureAlgorithms.contains(parsed.signature)) {
      dst.add(
        signaturehash.Algorithm(hash: parsed.hash, signature: parsed.signature),
      );
    }
  }
}
