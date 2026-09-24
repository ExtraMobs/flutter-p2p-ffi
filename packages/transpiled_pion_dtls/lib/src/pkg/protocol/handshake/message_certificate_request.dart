part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_certificate_request.go.
//
// Depends on `pkg/crypto/clientcertificate`, `pkg/crypto/hash`,
// `pkg/crypto/signature`, `pkg/crypto/signaturehash`, owned by a concurrent
// agent -- see `handshake.dart`'s library doc for the assumed shape
// (`clientcertificate.ClientCertificateType` an open value class per the
// same unchecked-wire-byte reasoning as `elliptic.Curve`, since
// `clientcertificate.Type(data[offset+i])` in Go is also an unchecked cast;
// `clientcertificate.types()` returning `Set<ClientCertificateType>`).

const int _messageCertificateRequestMinLength = 5;

/// MessageCertificateRequest is so a non-anonymous server can optionally
/// request a certificate from the client, if appropriate for the selected
/// cipher suite. This message, if sent, will immediately follow the
/// ServerKeyExchange message (if it is sent; otherwise, this message
/// follows the server's Certificate message).
/// https://tools.ietf.org/html/rfc5246#section-7.4.4
///
/// Port of `MessageCertificateRequest` (message_certificate_request.go:20-24)
/// and its methods `Type`/`Marshal`/`Unmarshal`
/// (message_certificate_request.go:35-144).
final class MessageCertificateRequest implements Message {
  List<clientcertificate.ClientCertificateType> certificateTypes;
  List<signaturehash.Algorithm> signatureHashAlgorithms;
  List<Uint8List> certificateAuthoritiesNames;

  MessageCertificateRequest({
    List<clientcertificate.ClientCertificateType>? certificateTypes,
    List<signaturehash.Algorithm>? signatureHashAlgorithms,
    List<Uint8List>? certificateAuthoritiesNames,
  }) : certificateTypes = certificateTypes ?? [],
       signatureHashAlgorithms = signatureHashAlgorithms ?? [],
       certificateAuthoritiesNames = certificateAuthoritiesNames ?? [];

  @override
  HandshakeType get type => HandshakeType.certificateRequest;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    final out = BytesBuilder();
    out.addByte(certificateTypes.length);
    for (final v in certificateTypes) {
      out.addByte(v.value);
    }

    final algLen = signatureHashAlgorithms.length * 2;
    out.add([(algLen >> 8) & 0xff, algLen & 0xff]);
    for (final v in signatureHashAlgorithms) {
      out.addByte(v.hash.value);
      out.addByte(v.signature.value);
    }

    // Distinguished Names.
    var casLength = 0;
    for (final ca in certificateAuthoritiesNames) {
      casLength += ca.length + 2;
    }
    out.add([(casLength >> 8) & 0xff, casLength & 0xff]);
    if (casLength > 0) {
      for (final ca in certificateAuthoritiesNames) {
        out.add([(ca.length >> 8) & 0xff, ca.length & 0xff]);
        out.add(ca);
      }
    }

    return out.toBytes();
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < _messageCertificateRequestMinLength) {
      throw _errBufferTooSmall;
    }

    var offset = 0;
    final certificateTypesLength = data[0];
    offset++;

    if ((offset + certificateTypesLength) > data.length) {
      throw _errBufferTooSmall;
    }

    certificateTypes = [];
    final supportedCertTypes = clientcertificate.types();
    for (var i = 0; i < certificateTypesLength; i++) {
      final certType = clientcertificate.ClientCertificateType(
        data[offset + i],
      );
      if (supportedCertTypes.contains(certType)) {
        certificateTypes.add(certType);
      }
    }
    offset += certificateTypesLength;
    if (data.length < offset + 2) throw _errBufferTooSmall;

    final signatureHashAlgorithmsLength =
        (data[offset] << 8) | data[offset + 1];
    offset += 2;

    if ((offset + signatureHashAlgorithmsLength) > data.length) {
      throw _errBufferTooSmall;
    }

    signatureHashAlgorithms = [];
    final supportedHash = hash.algorithms();
    final supportedSignature = signature.algorithms();
    for (var i = 0; i < signatureHashAlgorithmsLength; i += 2) {
      if (data.length < (offset + i + 2)) throw _errBufferTooSmall;
      final h = hash.Algorithm(data[offset + i]);
      final s = signature.Algorithm(data[offset + i + 1]);

      if (!supportedHash.contains(h)) continue;
      if (!supportedSignature.contains(s)) continue;
      signatureHashAlgorithms.add(
        signaturehash.Algorithm(hash: h, signature: s),
      );
    }

    offset += signatureHashAlgorithmsLength;
    if (data.length < offset + 2) throw _errBufferTooSmall;
    final casLength = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    if ((offset + casLength) > data.length) throw _errBufferTooSmall;
    var cas = Uint8List.sublistView(data, offset, offset + casLength);
    certificateAuthoritiesNames = [];
    while (cas.isNotEmpty) {
      if (cas.length < 2) throw _errBufferTooSmall;
      final caLen = (cas[0] << 8) | cas[1];
      cas = Uint8List.sublistView(cas, 2);

      if (cas.length < caLen) throw _errBufferTooSmall;

      certificateAuthoritiesNames.add(Uint8List.sublistView(cas, 0, caLen));
      cas = Uint8List.sublistView(cas, caLen);
    }
  }
}
