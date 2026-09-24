part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_finished.go.

/// MessageFinished is a DTLS Handshake Message this message is the first
/// one protected with the just negotiated algorithms, keys, and secrets.
/// Recipients of Finished messages MUST verify that the contents are
/// correct.
/// https://tools.ietf.org/html/rfc5246#section-7.4.9
///
/// Port of `MessageFinished` (message_finished.go:12-14) and its methods
/// `Type`/`Marshal`/`Unmarshal` (message_finished.go:17-31).
final class MessageFinished implements Message {
  Uint8List verifyData;

  MessageFinished([Uint8List? verifyData])
    : verifyData = verifyData ?? Uint8List(0);

  @override
  HandshakeType get type => HandshakeType.finished;

  @override
  Uint8List marshal() => Uint8List.fromList(verifyData);

  @override
  void unmarshal(Uint8List data) {
    verifyData = Uint8List.fromList(data);
  }
}
