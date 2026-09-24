part of 'handshake.dart';

// Port of pkg/protocol/handshake/message_server_hello_done.go.

/// MessageServerHelloDone is final non-encrypted message from server this
/// communicates server has sent all its handshake messages and next should
/// be MessageFinished.
///
/// Port of `MessageServerHelloDone` (message_server_hello_done.go:9) and its
/// methods `Type`/`Marshal`/`Unmarshal` (message_server_hello_done.go:12-24).
final class MessageServerHelloDone implements Message {
  @override
  HandshakeType get type => HandshakeType.serverHelloDone;

  @override
  Uint8List marshal() => Uint8List(0);

  @override
  void unmarshal(Uint8List data) {}
}
