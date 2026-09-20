// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/provider/provider.dart
//
// Port of boxo's provider/provider.go (revision
// 25b1db8931508bb069eb6e67243b34d353cbe845, see UPSTREAM_LOCK.md): the
// exported interfaces of the (re)provider subsystem.
//
// Deliberately not ported from provider.go: `MultihashProvider`,
// `NewBufferedProvider`, `NewPrioritizedProvider` and `NewConcatProvider`.
// Those compose multiple `KeyChanFunc` streams (pinned DAG + MFS + ...) for
// Kubo's full reprovider wiring; this embedded node has no pinner yet, so
// there is nothing to compose. `reproviderSystem()` in reprovider.dart
// accepts any `KeyChanFunc`, so those combinators can be added later without
// changing this contract.
import 'package:transpiled_cid/transpiled_cid.dart';

/// Announces blocks to the network. Equivalent to boxo's `Provider`.
abstract class Provider {
  /// Attempts to announce [cid] to the network. [announce] is always `true`
  /// for calls originating from [Reprovider.reprovide];
  /// it survives the transpilation only as a signature-compatibility
  /// parameter for other callers.
  Future<void> provide(Cid cid, bool announce);
}

/// Reannounces blocks to the network. Equivalent to boxo's `Reprovider`.
abstract class Reprovider {
  /// Starts a new reprovide, unless one is already running.
  Future<void> reprovide();
}

/// The interface for interacting with the value provider system. Equivalent
/// to boxo's `System`.
abstract class System implements Provider, Reprovider {
  /// Removes all entries from the provide queue. Returns the number of Cids
  /// removed from the queue.
  ///
  /// This transpilation does not persist an initial-provide queue (see the
  /// `reproviderSystem` doc comment), so this always returns `0`.
  int clear();

  /// Releases the resources held by this system, awaiting any in-flight
  /// reprovide scheduling loop.
  Future<void> close();

  /// Various stats about this provider system.
  ReproviderStats stat();

  /// Replaces the current key provider.
  void setKeyProvider(KeyChanFunc kp);
}

/// Streams the Cids that should be (re)provided. Equivalent to boxo's
/// `KeyChanFunc` (`func(context.Context) (<-chan cid.Cid, error)`); the
/// `context.Context` and `(chan, error)` tuple are dropped per this
/// project's conventions -- a synchronous setup failure throws instead of
/// returning an error, and a stream replaces the channel.
typedef KeyChanFunc = Stream<Cid> Function();

/// Various stats about a provider system. Equivalent to boxo's
/// `ReproviderStats`.
final class ReproviderStats {
  /// Creates a stats snapshot.
  const ReproviderStats({
    required this.totalReprovides,
    required this.lastReprovideBatchSize,
    required this.reprovideInterval,
    required this.avgReprovideDuration,
    required this.lastReprovideDuration,
    required this.lastRun,
  });

  /// Total number of keys reprovided since the system started running.
  final int totalReprovides;

  /// Number of keys reprovided in the last reprovide run.
  final int lastReprovideBatchSize;

  /// The configured interval between two reprovides.
  final Duration reprovideInterval;

  /// The average duration of a single reprovide, across all runs.
  final Duration avgReprovideDuration;

  /// The duration of the last reprovide run.
  final Duration lastReprovideDuration;

  /// When the last reprovide run happened, or `null` if none has run yet.
  final DateTime? lastRun;
}
