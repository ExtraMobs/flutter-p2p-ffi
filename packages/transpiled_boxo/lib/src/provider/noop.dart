// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/provider/noop.dart
//
// Port of boxo's provider/noop.go (revision
// 25b1db8931508bb069eb6e67243b34d353cbe845, see UPSTREAM_LOCK.md).
import 'package:transpiled_cid/transpiled_cid.dart';

import 'provider.dart';

/// Creates a [System] that does nothing. Equivalent to boxo's
/// `NewNoopProvider`, which returns its `System` interface backed by an
/// unexported `noopProvider` struct -- [_NoopProviderSystem] (below) stays
/// private to mirror that, matching Go's own shape rather than inventing a
/// public Dart type name with no upstream counterpart (`AGENTS.md`).
System noopProviderSystem() => const _NoopProviderSystem();

/// A [System] that does nothing. Equivalent to boxo's unexported
/// `noopProvider` struct. Construct via [noopProviderSystem].
final class _NoopProviderSystem implements System {
  const _NoopProviderSystem();

  @override
  int clear() => 0;

  @override
  Future<void> close() async {}

  @override
  Future<void> provide(Cid cid, bool announce) async {}

  @override
  Future<void> reprovide() async {}

  @override
  ReproviderStats stat() => const ReproviderStats(
    totalReprovides: 0,
    lastReprovideBatchSize: 0,
    reprovideInterval: Duration.zero,
    avgReprovideDuration: Duration.zero,
    lastReprovideDuration: Duration.zero,
    lastRun: null,
  );

  @override
  void setKeyProvider(KeyChanFunc kp) {}
}
