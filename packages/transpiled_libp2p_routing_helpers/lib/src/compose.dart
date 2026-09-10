// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/compose.dart
//
// Port of go-libp2p-routing-helpers's composed.go: combines independent
// ValueStore/PeerRouting/ContentRouting implementations into a single
// Routing. Leaving a component unset behaves like NullRouter for that
// piece.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    as core_routing
    show getPublicKey;

import 'bootstrap.dart';
import 'multi_error.dart';
import 'null_router.dart';

/// Composes independent routing components into a single [Routing].
/// Leaving a component `null` behaves like [NullRouter] for that piece.
/// Also implements [Bootstrap]: all *distinct* components implementing it
/// are bootstrapped in parallel (identical components aren't bootstrapped
/// twice). Equivalent to go-libp2p-routing-helpers's `Compose`.
class Compose implements Routing, PubKeyFetcher, Bootstrap {
  /// Creates a composed router from its (optionally absent) pieces.
  Compose({this.valueStore, this.peerRouting, this.contentRouting});

  /// The value-store component, or `null` to behave like [NullRouter].
  final ValueStore? valueStore;

  /// The peer-routing component, or `null` to behave like [NullRouter].
  final PeerRouting? peerRouting;

  /// The content-routing component, or `null` to behave like [NullRouter].
  final ContentRouting? contentRouting;

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {
    final store = valueStore;
    if (store == null) throw const RoutingNotSupportedException();
    return store.putValue(key, value, options: options);
  }

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    final store = valueStore;
    if (store == null) throw const RoutingNotFoundException();
    return store.getValue(key, options: options);
  }

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) {
    final store = valueStore;
    if (store == null) return const Stream.empty();
    return store.searchValue(key, options: options);
  }

  @override
  Future<void> provide(Cid cid, bool local) async {
    final routing = contentRouting;
    if (routing == null) throw const RoutingNotSupportedException();
    return routing.provide(cid, local);
  }

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) {
    final routing = contentRouting;
    if (routing == null) return const Stream.empty();
    return routing.findProvidersAsync(cid, count);
  }

  @override
  Future<AddrInfo> findPeer(PeerId id) async {
    final routing = peerRouting;
    if (routing == null) throw const RoutingNotFoundException();
    return routing.findPeer(id);
  }

  @override
  Future<PubKey> getPublicKey(PeerId id) async {
    final store = valueStore;
    if (store == null) throw const RoutingNotFoundException();
    return core_routing.getPublicKey(store, id);
  }

  @override
  Future<void> bootstrap() async {
    // Deduplicate by identity: calling bootstrap multiple times shouldn't
    // be an issue, but using the same router for multiple fields of
    // Compose is common.
    final routers = <Bootstrap>{};
    for (final component in <Object?>[
      valueStore,
      contentRouting,
      peerRouting,
    ]) {
      if (component == null || component is NullRouter) continue;
      if (component is Bootstrap) routers.add(component);
    }

    final results = await Future.wait(
      routers.map(
        (r) =>
            r.bootstrap().then<Object?>((_) => null, onError: (Object e) => e),
      ),
    );
    final errors = results.whereType<Object>().toList();
    final combined = combineErrors(errors);
    if (combined != null) throw combined;
  }
}
