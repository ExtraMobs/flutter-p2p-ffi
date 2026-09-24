part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_certificate_verify.go.
//
// Depends on `pkg/crypto/hash`/`pkg/crypto/signature`, owned by a concurrent
// agent -- see `handshake.dart`'s library doc for the assumed shape.

const int _handshakeMessageCertificateVerifyMinLength = 4;

/// MessageCertificateVerify provide explicit verification of a client
/// certificate.
/// https://tools.ietf.org/html/rfc5246#section-7.4.8
///
/// Port of `MessageCertificateVerify` (message_certificate_verify.go:15-19)
/// and its methods `Type`/`Marshal`/`Unmarshal`
/// (message_certificate_verify.go:26-66).
final class MessageCertificateVerify implements Message {
  hash.Algorithm hashAlgorithm;
  signature.Algorithm signatureAlgorithm;
  Uint8List signatureBytes;

  MessageCertificateVerify({
    hash.Algorithm? hashAlgorithm,
    signature.Algorithm? signatureAlgorithm,
    Uint8List? signatureBytes,
  }) : hashAlgorithm = hashAlgorithm ?? hash.none,
       signatureAlgorithm = signatureAlgorithm ?? signature.anonymous,
       signatureBytes = signatureBytes ?? Uint8List(0);

  @override
  HandshakeType get type => HandshakeType.certificateVerify;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    final out = Uint8List(1 + 1 + 2 + signatureBytes.length);
    out[0] = hashAlgorithm.value;
    out[1] = signatureAlgorithm.value;
    out[2] = (signatureBytes.length >> 8) & 0xff;
    out[3] = signatureBytes.length & 0xff;
    out.setRange(4, out.length, signatureBytes);
    return out;
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < _handshakeMessageCertificateVerifyMinLength) {
      throw _errBufferTooSmall;
    }

    final h = hash.Algorithm(data[0]);
    if (!hash.algorithms().contains(h)) throw _errInvalidHashAlgorithm;
    hashAlgorithm = h;

    final s = signature.Algorithm(data[1]);
    if (!signature.algorithms().contains(s))
      throw _errInvalidSignatureAlgorithm;
    signatureAlgorithm = s;

    final signatureLength = (data[2] << 8) | data[3];
    if ((signatureLength + 4) != data.length) throw _errBufferTooSmall;

    signatureBytes = Uint8List.fromList(data.sublist(4));
  }
}
