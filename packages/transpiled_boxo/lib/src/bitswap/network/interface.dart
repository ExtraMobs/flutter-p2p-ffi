import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_boxo/bitswap/message.dart';

/// Abstração flexível de stream
abstract interface class P2pStream {
  String get protocol;
  Future<void> write(List<int> data);
  void setWriteDeadline(DateTime deadline);
  void setDeadline(DateTime deadline);
  Future<void> close();
  void reset();
}

/// Abstração flexível de host
abstract interface class P2pHost {
  void setStreamHandler(String protocol, void Function(P2pStream) handler);
  Future<P2pStream> newStream(PeerId peer, List<String> protocols);
  void removeStreamHandler(String protocol);
  Future<void> connect(AddrInfo peer);
  List<PeerId> get peers;
}

/// BitSwapNetwork provides network connectivity for Bitswap sessions.
abstract interface class BitSwapNetwork implements Pinger, PeerTagger {
  /// SendMessage sends a Bitswap message to a peer.
  Future<void> sendMessage(PeerId peer, BitSwapMessage message);

  /// Start registers the Receiver and starts handling new messages, connectivity events, etc.
  void start(List<Receiver> receivers);

  /// Stop stops the network service.
  void stop();

  Future<void> connect(AddrInfo peer);
  Future<void> disconnectFrom(PeerId peer);
  bool isConnectedToPeer(PeerId peer);

  Future<MessageSender> newMessageSender(PeerId peer, MessageSenderOpts opts);

  P2pHost host();

  Stats stats();

  PeerId self();
}

/// PeerTagger is an interface for tagging peers with metadata
abstract interface class PeerTagger {
  void tagPeer(PeerId peer, String tag, int weight);
  void untagPeer(PeerId peer, String tag);
  void protect(PeerId peer, String tag);
  bool unprotect(PeerId peer, String tag);
}

/// MessageSender is an interface for sending a series of messages over the bitswap
/// network
abstract interface class MessageSender {
  Future<void> sendMsg(BitSwapMessage msg);
  Future<void> reset();
  /// Indicates whether the remote peer supports HAVE / DONT_HAVE messages
  bool supportsHave();
}

class MessageSenderOpts {
  final int maxRetries;
  final Duration sendTimeout;
  final Duration sendErrorBackoff;

  MessageSenderOpts({
    required this.maxRetries,
    required this.sendTimeout,
    required this.sendErrorBackoff,
  });
}

/// Receiver is an interface that can receive messages from the BitSwapNetwork.
abstract interface class Receiver {
  void receiveMessage(PeerId sender, BitSwapMessage incoming);
  void receiveError(Exception error);

  /// Connected/Disconnected warns bitswap about peer connections.
  void peerConnected(PeerId peer);
  void peerDisconnected(PeerId peer);
}

/// Routing is an interface to providing and finding providers on a bitswap
/// network.
abstract interface class Routing implements ContentDiscovery {
  /// Provide provides the key to the network.
  Future<void> provide(Cid key);
}

class PingResult {
  final Duration rtt;
  final Exception? error;

  PingResult(this.rtt, [this.error]);
}

/// Pinger is an interface to ping a peer and get the average latency of all pings
abstract interface class Pinger {
  /// Ping a peer
  Future<PingResult> ping(PeerId peer);
  /// Get the average latency of all pings
  Duration latency(PeerId peer);
}

/// Stats is a container for statistics about the bitswap network
class Stats {
  int messagesSent;
  int messagesRecvd;

  Stats({
    this.messagesSent = 0,
    this.messagesRecvd = 0,
  });
}
