// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/discovery/routing/routing.dart
//
// Port of go-libp2p/p2p/discovery/routing/routing.go: adapts a
// `routing.ContentRouting` (typically a DHT) into a `discovery.Discovery`
// ([RoutingDiscovery]), and the reverse -- a `discovery.Discovery` into a
// `routing.ContentRouting` ([DiscoveryRouting]).
//
// Go's `context.Context` is not represented here: this module's contract
// (`core/discovery/discovery.dart`'s `Discovery`) already dropped it in
// favor of Dart's own Future/Stream cancellation -- callers cancel a
// `findPeers` subscription instead of cancelling a context, and `advertise`
// is a plain `Future`. The one place Go used a context for a purpose beyond
// cancellation propagation -- `Advertise`'s 60s DHT-provide deadline -- is
// reproduced with `Future.timeout`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

import '../../../core/discovery/discovery.dart';
import '../../../core/discovery/options.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/routing/routing.dart' as core_routing;

/// How long [RoutingDiscovery.advertise] waits for the DHT to find the
/// closest peers to a key before giving up on providing the record to
/// them, matching go-libp2p's `routing.go` inline 60s timeout comment: not
/// setting a timeout here would make the DHT wander forever.
const Duration _provideTimeout = Duration(seconds: 60);

/// The DHT provider record validity is 24h, but it is recommended to
/// republish at least every 6h; go-libp2p goes one step further and
/// republishes every 3h. Matches `routing.go`'s inline comment and the
/// literal `3*time.Hour` it clamps to.
const Duration _maxAdvertiseTtl = Duration(hours: 3);

/// An implementation of [Discovery] backed by a
/// [core_routing.ContentRouting] (typically a DHT). Namespaces are
/// translated to Cids using the SHA2-256 hash. Equivalent to go-libp2p's
/// `RoutingDiscovery`.
class RoutingDiscovery implements Discovery {
  /// Wraps [router] as a [Discovery]. Equivalent to go-libp2p's
  /// `NewRoutingDiscovery`.
  RoutingDiscovery(this.router);

  /// The underlying content routing system.
  final core_routing.ContentRouting router;

  @override
  Future<Duration> advertise(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) async {
    final opts = DiscoveryOptions()..apply(options);

    var ttlValue = opts.ttl;
    if (ttlValue == Duration.zero || ttlValue > _maxAdvertiseTtl) {
      ttlValue = _maxAdvertiseTtl;
    }

    final cid = _nsToCid(namespace);
    await router.provide(cid, true).timeout(_provideTimeout);

    return ttlValue;
  }

  @override
  Stream<AddrInfo> findPeers(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) {
    // Default limit if not specified in options.
    final opts = DiscoveryOptions()
      ..limit = 100
      ..apply(options);

    final cid = _nsToCid(namespace);
    return router.findProvidersAsync(cid, opts.limit);
  }
}

/// Adapts a [Discovery] into a [core_routing.ContentRouting] -- the reverse
/// direction of [RoutingDiscovery]. Equivalent to go-libp2p's
/// `DiscoveryRouting`.
class DiscoveryRouting implements Discovery, core_routing.ContentRouting {
  /// Wraps [disc], applying [options] to every [advertise]/[findPeers] call
  /// made on its behalf. Equivalent to go-libp2p's `NewDiscoveryRouting`.
  DiscoveryRouting(this.disc, [this.options = const []]);

  /// The underlying discovery system.
  final Discovery disc;

  /// Options applied to every delegated call.
  final List<DiscoveryOption> options;

  @override
  Future<Duration> advertise(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) => disc.advertise(namespace, options: options);

  @override
  Stream<AddrInfo> findPeers(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) => disc.findPeers(namespace, options: options);

  @override
  Future<void> provide(Cid cid, bool local) async {
    // Go's third parameter is named `bcast`: `Provide(ctx, c, bcast)`, only
    // announcing when true, otherwise a no-op. This interface's existing
    // Dart signature (`core/routing/routing.dart`) names it `local`, but it
    // occupies the same position and role.
    if (!local) return;
    await advertise(_cidToNs(cid), options: options);
  }

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) =>
      findPeers(_cidToNs(cid), options: [limit(count), ...options]);
}

/// Translates a discovery namespace into a Cid via SHA2-256, matching
/// go-libp2p's private `nsToCid`.
Cid _nsToCid(String ns) {
  final digest = MultihashUtils.sum(
    'sha2-256',
    Uint8List.fromList(utf8.encode(ns)),
  );
  return Cid.v1('raw', digest);
}

/// Translates a Cid into a discovery namespace, matching go-libp2p's
/// private `cidToNs`.
String _cidToNs(Cid c) => '/provider/$c';
