// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/peer_metrics.dart
//
// Minimal stand-in for go-libp2p's core/peerstore.Metrics -- that whole
// package hasn't been ported yet (see doc/transpilation/PROGRESS.md).
// RoutingTable only ever calls LatencyEWMA, so that's the only piece
// pulled forward here; replace with the real peerstore.Metrics port's
// type once it exists.
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// The latency-tracking subset of go-libp2p's `peerstore.Metrics` that
/// [RoutingTable] depends on.
abstract class PeerMetrics {
  /// The exponentially-weighted moving average latency last recorded for
  /// [id], or [Duration.zero] if none has been recorded.
  Duration latencyEwma(PeerId id);
}
