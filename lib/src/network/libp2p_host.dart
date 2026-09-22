import 'package:transpiled_libp2p/transpiled_libp2p.dart' as libp2p;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// Adapts the ported go-libp2p `AddrInfo` to the host.
final class Libp2pRouter {
  /// Creates an adapter for [host].
  const Libp2pRouter(this.host);

  /// Host used for connections and streams.
  final libp2p.Host host;

  /// Connects the host to the complete peer information in [peer].
  Future<void> connect(libp2p.AddrInfo peer) async {
    host.peerstore.addAddrs(peer.id, peer.addrs, const Duration(minutes: 2));
    await host.connect(peer);
  }

  /// Adds addresses for [peer] to the underlying peerstore with [ttl].
  ///
  /// Matches go-libp2p-kad-dht's `maybeAddAddrs` behavior with `TempAddrTTL`.
  Future<void> addAddrs(
    libp2p.AddrInfo peer, [
    Duration ttl = libp2p.tempAddrTtl,
  ]) async {
    if (peer.addrs.isEmpty) return;
    if (peer.id == host.id) return;
    host.peerstore.addAddrs(peer.id, peer.addrs, ttl);
  }

  /// Looks up addresses stored for [peerId] in the peerstore.
  Future<List<Multiaddr>> getAddrs(libp2p.PeerId peerId) async {
    try {
      return host.peerstore.addrs(peerId);
    } catch (_) {
      return const [];
    }
  }

  /// Returns peer ID for stream creation.
  libp2p.PeerId runtimePeerId(libp2p.PeerId peer) => peer;
}
