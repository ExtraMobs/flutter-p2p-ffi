part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_server_hello.go.

const int _messageServerHelloVariableWidthStart = 2 + randomLength;

/// MessageServerHello is sent in response to a ClientHello message when it
/// was able to find an acceptable set of algorithms. If it cannot find such
/// a match, it will respond with a handshake failure alert.
/// https://tools.ietf.org/html/rfc5246#section-7.4.1.3
///
/// Port of `MessageServerHello` (message_server_hello.go:17-26) and its
/// methods `Type`/`Marshal`/`Unmarshal` (message_server_hello.go:33-124).
final class MessageServerHello implements Message {
  protocol.Version version;
  Random random;
  Uint8List sessionId;
  int? cipherSuiteId;
  protocol.CompressionMethod? compressionMethod;
  List<extension.Extension> extensions;

  MessageServerHello({
    protocol.Version? version,
    Random? random,
    Uint8List? sessionId,
    this.cipherSuiteId,
    this.compressionMethod,
    List<extension.Extension>? extensions,
  }) : version = version ?? protocol.version1_2,
       random = random ?? Random(),
       sessionId = sessionId ?? Uint8List(0),
       extensions = extensions ?? [];

  @override
  HandshakeType get type => HandshakeType.serverHello;

  /// Marshal encodes the Handshake.
  @override
  Uint8List marshal() {
    final cipherSuite = cipherSuiteId;
    final compression = compressionMethod;
    if (cipherSuite == null) throw _errCipherSuiteUnset;
    if (compression == null) throw _errCompressionMethodUnset;

    final body = BytesBuilder();
    final head = Uint8List(_messageServerHelloVariableWidthStart);
    head[0] = version.major;
    head[1] = version.minor;
    head.setRange(
      2,
      _messageServerHelloVariableWidthStart,
      random.marshalFixed(),
    );
    body.add(head);

    body.addByte(sessionId.length);
    body.add(sessionId);

    body.add([(cipherSuite >> 8) & 0xff, cipherSuite & 0xff]);
    body.addByte(compression.id);

    body.add(extension.marshalExtensions(extensions));

    return body.toBytes();
  }

  /// Unmarshal populates the message from encoded data.
  @override
  void unmarshal(Uint8List data) {
    if (data.length < 2 + randomLength) throw _errBufferTooSmall;

    version = protocol.Version(data[0], data[1]);
    random.unmarshalFixed(Uint8List.sublistView(data, 2, 2 + randomLength));

    var currOffset = _messageServerHelloVariableWidthStart;
    currOffset++;
    if (data.length <= currOffset) throw _errBufferTooSmall;

    final n = data[currOffset - 1];
    if (data.length <= currOffset + n) throw _errBufferTooSmall;
    sessionId = Uint8List.fromList(data.sublist(currOffset, currOffset + n));
    currOffset += sessionId.length;

    if (data.length < currOffset + 2) throw _errBufferTooSmall;
    cipherSuiteId = (data[currOffset] << 8) | data[currOffset + 1];
    currOffset += 2;

    if (data.length <= currOffset) throw _errBufferTooSmall;
    final supported = protocol.compressionMethods()[data[currOffset]];
    if (supported != null) {
      compressionMethod = supported;
      currOffset++;
    } else {
      throw _errInvalidCompressionMethod;
    }

    if (data.length <= currOffset) {
      extensions = [];
      return;
    }

    extensions = extension.unmarshalExtensions(
      Uint8List.sublistView(data, currOffset),
    );
  }
}
