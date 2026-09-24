part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_client_hello.go.

const int _handshakeMessageClientHelloVariableWidthStart = 34;

/// MessageClientHello is for when a client first connects to a server it is
/// required to send the client hello as its first message. The client can
/// also send a client hello in response to a hello request or on its own
/// initiative in order to renegotiate the security parameters in an
/// existing connection.
///
/// Port of `MessageClientHello` (message_client_hello.go:19-28) and its
/// methods `Type`/`Marshal`/`Unmarshal` (message_client_hello.go:35-134).
final class MessageClientHello implements Message {
  protocol.Version version;
  Random random;
  Uint8List cookie;
  Uint8List sessionId;
  List<int> cipherSuiteIds;
  List<protocol.CompressionMethod> compressionMethods;
  List<extension.Extension> extensions;

  MessageClientHello({
    protocol.Version? version,
    Random? random,
    Uint8List? cookie,
    Uint8List? sessionId,
    List<int>? cipherSuiteIds,
    List<protocol.CompressionMethod>? compressionMethods,
    List<extension.Extension>? extensions,
  }) : version = version ?? protocol.version1_2,
       random = random ?? Random(),
       cookie = cookie ?? Uint8List(0),
       sessionId = sessionId ?? Uint8List(0),
       cipherSuiteIds = cipherSuiteIds ?? [],
       compressionMethods = compressionMethods ?? [],
       extensions = extensions ?? [];

  @override
  HandshakeType get type => HandshakeType.clientHello;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    if (cookie.length > 255) throw _errCookieTooLong;

    final out = Uint8List(_handshakeMessageClientHelloVariableWidthStart);
    out[0] = version.major;
    out[1] = version.minor;
    out.setRange(2, 34, random.marshalFixed());

    final body = BytesBuilder();
    body.add(out);
    body.addByte(sessionId.length);
    body.add(sessionId);

    body.addByte(cookie.length);
    body.add(cookie);
    body.add(_encodeCipherSuiteIds(cipherSuiteIds));
    body.add(protocol.encodeCompressionMethods(compressionMethods));

    body.add(extension.marshalExtensions(extensions));

    return body.toBytes();
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < 2 + randomLength) throw _errBufferTooSmall;

    version = protocol.Version(data[0], data[1]);
    random.unmarshalFixed(Uint8List.sublistView(data, 2, 2 + randomLength));

    var currOffset = _handshakeMessageClientHelloVariableWidthStart;

    currOffset++;
    if (data.length <= currOffset) throw _errBufferTooSmall;
    var n = data[currOffset - 1];
    if (data.length <= currOffset + n) throw _errBufferTooSmall;
    sessionId = Uint8List.fromList(data.sublist(currOffset, currOffset + n));
    currOffset += sessionId.length;

    currOffset++;
    if (data.length <= currOffset) throw _errBufferTooSmall;
    n = data[currOffset - 1];
    if (data.length <= currOffset + n) throw _errBufferTooSmall;
    cookie = Uint8List.fromList(data.sublist(currOffset, currOffset + n));
    currOffset += cookie.length;

    // Cipher Suites.
    if (data.length < currOffset) throw _errBufferTooSmall;
    cipherSuiteIds = _decodeCipherSuiteIds(
      Uint8List.sublistView(data, currOffset),
    );
    if (data.length < currOffset + 2) throw _errBufferTooSmall;
    currOffset += ((data[currOffset] << 8) | data[currOffset + 1]) + 2;

    // Compression Methods.
    if (data.length < currOffset) throw _errBufferTooSmall;
    compressionMethods = protocol.decodeCompressionMethods(
      Uint8List.sublistView(data, currOffset),
    );
    if (data.length < currOffset) throw _errBufferTooSmall;
    currOffset += data[currOffset] + 1;

    // Extensions.
    extensions = extension.unmarshalExtensions(
      Uint8List.sublistView(data, currOffset),
    );
  }
}
