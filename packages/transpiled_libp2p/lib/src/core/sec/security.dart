import '../network/network.dart';
import '../peer/peer_id.dart';
import '../transport/transport.dart';

/// Authenticated byte connection, port of core/sec.SecureConn.
/// RawConn supplies the runtime's asynchronous equivalent of net.Conn.
abstract interface class SecureConn implements RawConn, ConnSecurity {}

/// Authentication negotiated before the stream multiplexer.
/// Port of core/sec.SecureTransport; connection cancellation closes RawConn.
abstract interface class SecureTransport {
  /// Authenticates the remote initiator, allowing an empty expected peer.
  Future<SecureConn> secureInbound(RawConn insecure, PeerId peer);
  /// Authenticates the remote responder against the expected peer.
  Future<SecureConn> secureOutbound(RawConn insecure, PeerId peer);
  /// Multistream-select security protocol identifier.
  String id();
}

/// core/sec.ErrPeerIDMismatch, preserving the upstream diagnostic.
class PeerIdMismatchException implements Exception {
  /// Records the requested identity and the authenticated identity.
  const PeerIdMismatchException({required this.expected, required this.actual});

  /// Identity requested by the caller.
  final PeerId expected;
  /// Identity derived from the remote public key.
  final PeerId actual;

  @override
  String toString() =>
      'peer id mismatch: expected $expected, but remote key matches $actual';
}
