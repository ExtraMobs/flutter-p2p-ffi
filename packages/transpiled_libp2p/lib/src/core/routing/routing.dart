// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/routing/routing.dart
//
// Port of go-libp2p's core/routing/routing.go: the interfaces for peer
// routing, content routing, and a routing system's key/value store (what
// a DHT, among other things, implements).
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';

import '../crypto/key_codec.dart';
import '../crypto/key_types.dart';
import '../peer/addr_info.dart';
import '../peer/peer_id.dart';
import 'options.dart';

/// Thrown when a router fails to find the requested record. Equivalent to
/// go-libp2p's `ErrNotFound`.
class RoutingNotFoundException implements Exception {
  /// Creates the exception.
  const RoutingNotFoundException();
  @override
  String toString() => 'routing: not found';
}

/// Thrown when a router doesn't support the given record type/operation.
/// Equivalent to go-libp2p's `ErrNotSupported`.
class RoutingNotSupportedException implements Exception {
  /// Creates the exception.
  const RoutingNotSupportedException();
  @override
  String toString() => 'routing: operation or key not supported';
}

/// Announces where to find content on the routing system. Equivalent to
/// go-libp2p's `ContentProviding`.
abstract class ContentProviding {
  /// Adds [cid] to the content routing system. If [local] is `true`, it
  /// also announces it; otherwise it's just kept in local accounting.
  Future<void> provide(Cid cid, bool local);
}

/// Retrieves providers for a given Cid using the routing system.
/// Equivalent to go-libp2p's `ContentDiscovery`.
abstract class ContentDiscovery {
  /// Searches for peers able to provide [cid]. When [count] is 0, returns
  /// an unbounded number of results.
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count);
}

/// A value-provider layer of indirection used to find who has what
/// content. Equivalent to go-libp2p's `ContentRouting`.
abstract class ContentRouting implements ContentProviding, ContentDiscovery {}

/// Finds address information for peers. Equivalent to go-libp2p's
/// `PeerRouting`.
abstract class PeerRouting {
  /// Searches for a peer with the given [id], returning its addresses.
  Future<AddrInfo> findPeer(PeerId id);
}

/// A basic put/get interface for a routing system. Equivalent to
/// go-libp2p's `ValueStore`.
abstract class ValueStore {
  /// Adds [value] under [key].
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  });

  /// Searches for the value corresponding to [key].
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  });

  /// Searches for progressively better values for [key]. Implementations
  /// must stop after a "good" value (one [getValue] would return) is
  /// found. Never throws [RoutingNotFoundException]; when nothing is
  /// found, the stream simply closes without emitting.
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  });
}

/// The combination of routing types a libp2p routing system supports (a
/// DHT, for example, or several specialized pieces composed together).
/// Equivalent to go-libp2p's `Routing`.
abstract class Routing implements ContentRouting, PeerRouting, ValueStore {
  /// Hints to the routing system to get into (and remain in) a
  /// bootstrapped state. Not synchronous.
  Future<void> bootstrap();
}

/// Implemented by [ValueStore]s that can optimize public key retrieval.
/// Equivalent to go-libp2p's `PubKeyFetcher`.
abstract class PubKeyFetcher {
  /// Returns the public key for peer [id].
  Future<PubKey> getPublicKey(PeerId id);
}

/// The key used to store/retrieve a peer's public key in a [ValueStore].
/// Equivalent to go-libp2p's `KeyForPublicKey`.
String keyForPublicKey(PeerId id) => '/pk/${String.fromCharCodes(id.value)}';

/// Retrieves the public key for [id] from [store]: the identity multihash
/// (if [id] embeds one), then [store]'s optimized [PubKeyFetcher] path (if
/// it implements one), then a plain [ValueStore.getValue] lookup as a last
/// resort. Equivalent to go-libp2p's `GetPublicKey`.
Future<PubKey> getPublicKey(ValueStore store, PeerId id) async {
  try {
    return id.extractPublicKey();
  } on NoPublicKeyException {
    // Fall through to the value store.
  }

  if (store is PubKeyFetcher) {
    final PubKeyFetcher fetcher = store as PubKeyFetcher;
    return fetcher.getPublicKey(id);
  }
  final value = await store.getValue(keyForPublicKey(id));
  return unmarshalPublicKey(value);
}
