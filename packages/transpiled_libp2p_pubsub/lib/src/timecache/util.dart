// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/timecache/util.dart
//
// Port of go-libp2p-pubsub's timecache/util.go. Go's `background` goroutine
// (a `select` over a ticker channel and a cancellation context) becomes a
// Dart `Timer.periodic`, cancelled via `Timer.cancel()` instead of context
// cancellation -- the natural Dart equivalent, no behavior lost. `sweep`
// itself is kept as a standalone pure function taking `now` explicitly
// (matching Go exactly), which is also what makes its expiry logic
// directly unit-testable without waiting on a real timer to fire.
import 'dart:async';

/// How often the background sweep removes expired entries by default.
/// Equivalent to go-libp2p-pubsub's `backgroundSweepInterval`.
const Duration backgroundSweepInterval = Duration(minutes: 1);

/// Starts a periodic sweep of [m] every [interval], removing entries whose
/// expiry has passed. Equivalent to go-libp2p-pubsub's `background`
/// (ported as a `Timer.periodic` in place of Go's ticker-driven goroutine
/// -- see this file's header).
Timer startBackgroundSweep(Map<String, DateTime> m, Duration interval) {
  return Timer.periodic(interval, (_) => sweep(m, DateTime.now()));
}

/// Removes every entry in [m] whose expiry is before [now]. Equivalent to
/// go-libp2p-pubsub's `sweep`.
void sweep(Map<String, DateTime> m, DateTime now) {
  m.removeWhere((_, expiry) => expiry.isBefore(now));
}
