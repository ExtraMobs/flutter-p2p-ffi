// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/core/discovery/discovery.go.
import 'dart:async';

import '../peer/addr_info.dart';
import 'options.dart';

/// Advertises services to the network.
abstract interface class Advertiser {
  /// Advertises [namespace] and returns the advertisement TTL.
  ///
  /// Go's `context.Context` is represented by Dart's normal Future/Stream
  /// cancellation and lifecycle mechanisms, so it is not an argument here.
  Future<Duration> advertise(
    String namespace, {
    List<DiscoveryOption> options = const [],
  });
}

/// Discovers peers providing a service.
abstract interface class Discoverer {
  /// Finds peers providing [namespace]. A zero option limit is unbounded.
  Stream<AddrInfo> findPeers(
    String namespace, {
    List<DiscoveryOption> options = const [],
  });
}

/// Combines service advertisement and peer discovery.
abstract interface class Discovery implements Advertiser, Discoverer {}
