part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_certificate.go.

const int _handshakeMessageCertificateLengthFieldSize = 3;

/// MessageCertificate is a DTLS Handshake Message it can contain either a
/// Client or Server Certificate.
/// https://tools.ietf.org/html/rfc5246#section-7.4.2
///
/// Port of `MessageCertificate` (message_certificate.go:13-15) and its
/// methods `Type`/`Marshal`/`Unmarshal` (message_certificate.go:18-73).
final class MessageCertificate implements Message {
  List<Uint8List> certificate;

  MessageCertificate([List<Uint8List>? certificate])
    : certificate = certificate ?? [];

  @override
  HandshakeType get type => HandshakeType.certificate;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    final body = BytesBuilder();
    for (final r in certificate) {
      final lenBytes = Uint8List(_handshakeMessageCertificateLengthFieldSize);
      util.putBigEndianUint24(lenBytes, r.length);
      body.add(lenBytes);
      body.add(r);
    }
    final bodyBytes = body.toBytes();

    final out = Uint8List(
      _handshakeMessageCertificateLengthFieldSize + bodyBytes.length,
    );
    util.putBigEndianUint24(out, bodyBytes.length);
    out.setRange(
      _handshakeMessageCertificateLengthFieldSize,
      out.length,
      bodyBytes,
    );
    return out;
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < _handshakeMessageCertificateLengthFieldSize) {
      throw _errBufferTooSmall;
    }

    final certificateBodyLen = util.bigEndianUint24(data);
    if (certificateBodyLen + _handshakeMessageCertificateLengthFieldSize !=
        data.length) {
      throw _errLengthMismatch;
    }

    certificate = [];
    var offset = _handshakeMessageCertificateLengthFieldSize;
    while (offset < data.length) {
      final certificateLen = util.bigEndianUint24(
        Uint8List.sublistView(data, offset),
      );
      offset += _handshakeMessageCertificateLengthFieldSize;

      if (offset + certificateLen > data.length) throw _errLengthMismatch;

      certificate.add(
        Uint8List.fromList(data.sublist(offset, offset + certificateLen)),
      );
      offset += certificateLen;
    }
  }
}
