part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_hello_verify_request.go.

/// MessageHelloVerifyRequest is as follows:
///
/// ```
/// struct {
///   ProtocolVersion server_version;
///   opaque cookie<0..2^8-1>;
/// } HelloVerifyRequest;
/// ```
///
/// The HelloVerifyRequest message type is hello_verify_request(3).
///
/// When the client sends its ClientHello message to the server, the server
/// MAY respond with a HelloVerifyRequest message. This message contains a
/// stateless cookie generated using the technique of [PHOTURIS]. The client
/// MUST retransmit the ClientHello with the cookie added.
/// https://tools.ietf.org/html/rfc6347#section-4.2.1
///
/// Port of `MessageHelloVerifyRequest` (message_hello_verify_request.go:24-27)
/// and its methods `Type`/`Marshal`/`Unmarshal`
/// (message_hello_verify_request.go:30-63).
final class MessageHelloVerifyRequest implements Message {
  protocol.Version version;
  Uint8List cookie;

  MessageHelloVerifyRequest({protocol.Version? version, Uint8List? cookie})
    : version = version ?? protocol.version1_2,
      cookie = cookie ?? Uint8List(0);

  @override
  HandshakeType get type => HandshakeType.helloVerifyRequest;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    if (cookie.length > 255) throw _errCookieTooLong;
    final out = Uint8List(3 + cookie.length);
    out[0] = version.major;
    out[1] = version.minor;
    out[2] = cookie.length;
    out.setRange(3, out.length, cookie);
    return out;
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < 3) throw _errBufferTooSmall;
    version = protocol.Version(data[0], data[1]);
    final cookieLength = data[2];
    if (data.length < cookieLength + 3) throw _errBufferTooSmall;
    cookie = Uint8List.fromList(data.sublist(3, 3 + cookieLength));
  }
}
