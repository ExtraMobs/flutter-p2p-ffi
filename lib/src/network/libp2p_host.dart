import 'package:transpiled_libp2p/transpiled_libp2p.dart' as core;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// Adapts the ported go-libp2p `AddrInfo` to the host.
final class Libp2pRouter {
  /// Creates an adapter for [host].
  const Libp2pRouter(this.host);

  /// Host used for connections and streams.
  final core.Host host;

  /// Connects the host to the complete peer information in [peer].
  Future<void> connect(core.AddrInfo peer) async {
    host.peerstore.addAddrs(
      peer.id,
      peer.addrs,
      const Duration(minutes: 2),
    );
    await host.connect(peer);
  }

  /// Adds addresses for [peer] to the underlying peerstore with [ttl].
  ///
  /// Matches go-libp2p-kad-dht's `maybeAddAddrs` behavior with `TempAddrTTL`.
  Future<void> addAddrs(
    core.AddrInfo peer, [
    Duration ttl = core.tempAddrTtl,
  ]) async {
    if (peer.addrs.isEmpty) return;
    if (peer.id == host.id) return;
    host.peerstore.addAddrs(peer.id, peer.addrs, ttl);
  }

  /// Looks up addresses stored for [peerId] in the peerstore.
  Future<List<Multiaddr>> getAddrs(core.PeerId peerId) async {
    try {
      return host.peerstore.addrs(peerId);
    } catch (_) {
      return const [];
    }
  }

  /// Returns peer ID for stream creation.
  core.PeerId runtimePeerId(core.PeerId peer) => peer;
}
