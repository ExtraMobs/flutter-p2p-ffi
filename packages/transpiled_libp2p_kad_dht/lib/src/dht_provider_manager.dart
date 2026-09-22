import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// Default validity of a stored provider record. Equivalent to
/// go-libp2p-kad-dht/amino's `DefaultProvideValidity` (48h).
const Duration dhtProvideValidity = Duration(hours: 48);

/// Stores DHT `ADD_PROVIDER` records and serves `GET_PROVIDERS`, expiring
/// records after [validity]. Equivalent to go-libp2p-kad-dht/records's
/// `ProviderManager` (the concrete type `dht.providerStore` is constructed
/// with), minus its datastore persistence, LRU cache and background GC
/// goroutine -- see the `ponytail:` note on [_byKey]. Its `ProviderStore`
/// interface counterpart is not ported: [DhtServer] is this type's only
/// consumer, so the interface would be an abstraction over a single
/// implementation (see the same judgment call made for `DhtRoutingTable`,
/// documented in PROGRESS.md).
final class ProviderManager {
  /// Creates a provider store whose records expire after [validity].
  ProviderManager({this.validity = dhtProvideValidity});

  /// How long a provider record stays valid after being added or refreshed.
  final Duration validity;

  // ponytail: plain in-memory map, expired entries dropped lazily on read.
  // No LRU cap, no background GC sweep, no datastore persistence -- upgrade
  // to a bounded/disk-backed store if memory growth or restart persistence
  // (Marco F.5) becomes a real requirement.
  final Map<String, Map<PeerId, _ProviderRecord>> _byKey = {};

  /// Stores [provider] as a provider of raw [key], refreshing its TTL if
  /// already present. Equivalent to `ProviderManager.AddProvider`.
  void addProvider(Uint8List key, AddrInfo provider) {
    final byPeer = _byKey.putIfAbsent(_encodeKey(key), () => {});
    byPeer[provider.id] = _ProviderRecord(provider.addrs, DateTime.now());
  }

  /// Returns the non-expired providers stored for raw [key], in insertion
  /// order. Equivalent to `ProviderManager.GetProviders`.
  List<AddrInfo> getProviders(Uint8List key) {
    final encoded = _encodeKey(key);
    final byPeer = _byKey[encoded];
    if (byPeer == null) return const [];
    final now = DateTime.now();
    byPeer.removeWhere(
      (_, record) => now.difference(record.addedAt) > validity,
    );
    if (byPeer.isEmpty) {
      _byKey.remove(encoded);
      return const [];
    }
    return [
      for (final entry in byPeer.entries)
        AddrInfo(id: entry.key, addrs: entry.value.addrs),
    ];
  }

  String _encodeKey(Uint8List key) => base64Encode(key);
}

final class _ProviderRecord {
  _ProviderRecord(this.addrs, this.addedAt);
  final List<Multiaddr> addrs;
  final DateTime addedAt;
}
