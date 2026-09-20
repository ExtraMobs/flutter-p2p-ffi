// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/provider/reprovider.dart
//
// Port of boxo's provider/reprovider.go (revision
// 25b1db8931508bb069eb6e67243b34d353cbe845, see UPSTREAM_LOCK.md): the
// [System] implementation that schedules periodic reprovides.
//
// This is half of PROGRESS.md's Marco F.5 (the scheduling half; persistent
// peerstore/`pstoreds` is the other half, owned elsewhere). Ported
// faithfully: `DefaultReproviderInterval` (22h -- reprovider.go:24), the
// one-minute initial-reprovide delay and its "only if interval > 1 minute"
// setup rule (reprovider.go:150-153), reprovideInterval == 0 disabling
// scheduling entirely (reprovider.go:242-244), the "already running" guard
// on [Reprovider.reprovide] (reprovider.go, `Reprovide`'s
// `s.mu.TryLock()`), the persisted last-reprovide time used to avoid an
// unnecessary reprovide right after restart (`getLastReprovideTime`/
// `storeTime`, reprovider.go:520-556), and the mid-cycle error behavior: a
// [Provider.provide] failure partway through a reprovide is logged and
// aborts *that* run without throwing or updating stats/last-run, exactly
// like `doProvideMany` returning early and `Reprovide`'s `continue`
// (reprovider.go: `provideCid`/`Reprovide`).
//
// Deliberately NOT ported here (see provider.dart's file doc comment for
// the KeyChanFunc-composition gap, and the package doc comment above for
// context):
// * The durable, dsqueue-backed initial-provide queue (`s.q`,
//   `provideWorker`, `ProvideWorkerCount`, `batchReadSize`,
//   `dedupCacheSize`, `provideDelayWarnDuration`). `go-dsqueue` is its own
//   go.mod module and is not ported anywhere in this tree; this embedded
//   node's initial "announce new content" path calls the DHT directly
//   (`IpfsNode.provide` -> `DhtClient.provide`), so [provide] below is a
//   direct passthrough to the online [Provider] instead of an enqueue.
//   [clear] therefore always returns 0 -- there is no queue to clear.
// * `verifcid.ValidateCid`/`Allowlist` hash-security filtering
//   (reprovider.go: `s.allowlist`, every `verifcid.ValidateCid` call). No
//   `verifcid` port exists anywhere in this tree yet. Every key from the
//   key provider is reprovided as-is. This is a security-relevant gap,
//   flagged for whoever ports `verifcid`.
// * `Ready`/`waitUntilProvideSystemReady`sys, `ProvideMany`/batch-size
//   splitting, `MaxBatchSize`, `ThroughputReport` and its callback/worker
//   concurrency. None of these affect scheduling fidelity, which is this
//   half-milestone's acceptance criterion; this embedded node's `Provider`
//   (the DHT client) has no `Ready` gate today, and a reprovide here always
//   processes its whole key stream as one Go-shaped "batch" (the default
//   `maxReprovideBatchSize = math.MaxUint`, i.e. unbounded, applies
//   whenever `MaxBatchSize`/`ThroughputReport` aren't set upstream either).
import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

import 'provider.dart';

final _log = Logger('provider');

/// MAGIC: how long we wait before reproviding a key. Equivalent to boxo's
/// `DefaultReproviderInterval` (reprovider.go:24 --
/// https://github.com/ipfs/kubo/pull/9326).
///
/// NOTE: this project's own `AGENTS.md`/`doc/transpilation/PROGRESS.md`
/// state "o Kubo republica a cada 12h", which is wrong -- that document
/// text was not re-derived from this file. The upstream constant, ported
/// here unchanged, is 22 hours.
const Duration defaultReproviderInterval = Duration(hours: 22);

/// MAGIC: if the reprovide ticker is larger than a minute (likely), provide
/// once after we've been up a minute rather than immediately (in case the
/// process is about to stop). Equivalent to boxo's unexported
/// `defaultInitialReprovideDelay` (reprovider.go:28).
const Duration _defaultInitialReprovideDelay = Duration(minutes: 1);

/// Default prefix for this system's persisted state in the datastore.
/// Equivalent to boxo's `DefaultKeyPrefix` (reprovider.go:117,
/// `datastore.NewKey("/provider")`).
final Key defaultKeyPrefix = Key('/provider');

/// Thrown by [Reprovider.reprovide] when a reprovide is already running.
/// Equivalent to boxo's `Reprovide` returning
/// `fmt.Errorf("instance of reprovide already running")`.
///
/// Kept private: Go itself never gives this condition a named/sentinel
/// error (no `ErrX` var, no `XError` type -- just an ad hoc
/// `fmt.Errorf` string), so an unmatchable-by-type Dart exception is the
/// closer-fidelity choice, and it also keeps this internal scheduling
/// guard off the public API surface per `AGENTS.md`'s rule that helper
/// types without an exported Go counterpart stay private.
final class _ReproviderAlreadyRunningException implements Exception {
  /// Creates the exception.
  const _ReproviderAlreadyRunningException();

  @override
  String toString() => 'instance of reprovide already running';
}

/// Thrown by [online] when a [System] returned by [reproviderSystem] is
/// already bound to a provider. Equivalent to boxo's `Online` returning
/// `errors.New("trying to register two providers on the same reprovider")`.
/// Kept private for the same reason as
/// [_ReproviderAlreadyRunningException].
final class _ReproviderAlreadyOnlineException implements Exception {
  /// Creates the exception.
  const _ReproviderAlreadyOnlineException();

  @override
  String toString() =>
      'trying to register two providers on the same reprovider';
}

/// A functional option configuring the [System] built by [reproviderSystem].
/// Equivalent to boxo's `Option`. `_ReproviderSystem` stays private (see its
/// doc comment); callers only ever build a [ReproviderOption] via this
/// file's own option functions ([reproviderInterval], [keyProvider],
/// [datastorePrefix], [online]), never by naming the private parameter type
/// directly.
// ignore: library_private_types_in_public_api
typedef ReproviderOption = void Function(_ReproviderSystem system);

/// Sets the interval between two reprovides. A value of [Duration.zero]
/// disables automatic reprovide entirely. Equivalent to boxo's
/// `ReproviderInterval`.
ReproviderOption reproviderInterval(Duration interval) =>
    (system) => system._reprovideInterval = interval;

/// Replaces the key provider used to enumerate what should be reprovided.
/// Equivalent to boxo's `KeyProvider`.
ReproviderOption keyProvider(KeyChanFunc fn) =>
    (system) => system._keyProvider = fn;

/// Sets the prefix for this system's persisted state in the datastore.
/// Defaults to [defaultKeyPrefix]. Equivalent to boxo's `DatastorePrefix`.
ReproviderOption datastorePrefix(Key prefix) =>
    (system) => system._keyPrefix = prefix;

/// Enables the system and makes it send (re)provides through [provider].
/// Throws [_ReproviderAlreadyOnlineException] if applied twice. Equivalent
/// to boxo's `Online`.
ReproviderOption online(Provider provider) => (system) {
  if (system._rsys != null) {
    throw const _ReproviderAlreadyOnlineException();
  }
  system._rsys = provider;
};

/// Computes the delay before the first scheduled reprovide, given the last
/// persisted reprovide time (if any). Equivalent to the inline scheduling
/// math at the top of boxo's `reprovideSchedulingWorker`
/// (reprovider.go:246-254): normally [initialReprovideDelay], but if a
/// reprovide already ran recently enough that waiting the full
/// [initialReprovideDelay] would reprovide sooner than one full
/// [reprovideInterval] after that last run, wait out the remainder of that
/// interval instead. Never negative.
///
/// Go tests this as unexported, same-package whitebox logic
/// (`reprovider_test.go`). This project's atomic tests are black-box,
/// external-package tests (see `AGENTS.md`, Regra 24), so this scheduling
/// math is deliberately exposed as its own top-level pure function -- the
/// smallest public surface that keeps it directly testable without
/// spinning up real multi-hour timers.
Duration reprovideFirstDelay({
  required Duration reprovideInterval,
  required Duration initialReprovideDelay,
  required DateTime now,
  DateTime? lastReprovide,
}) {
  var firstDelay = initialReprovideDelay;
  if (lastReprovide != null &&
      now.difference(lastReprovide) <
          reprovideInterval - initialReprovideDelay) {
    firstDelay = lastReprovide.add(reprovideInterval).difference(now);
  }
  return firstDelay < Duration.zero ? Duration.zero : firstDelay;
}

/// Creates a [System] that schedules periodic reprovides, persisting its
/// scheduling state under [ds]. Applies [options] in order, then --
/// matching boxo's `New` -- starts the reprovide scheduling loop
/// immediately if [online] was one of them. Equivalent to boxo's
/// `New(ds, opts...) (System, error)`.
///
/// A top-level function rather than a public class's constructor: Go's own
/// `New` returns the `System` interface backed by an unexported `reprovider`
/// struct, so [_ReproviderSystem] (below) is kept private to mirror that,
/// and this function is the public construction surface -- matching Go's
/// own shape more closely than inventing a public Dart type name with no
/// upstream counterpart would (`AGENTS.md`'s rule against inventing public
/// API surface for Go-internal-only helpers). This isn't the `newX()`
/// constructor-function pattern `AGENTS.md` separately bans (that rule
/// targets free functions standing in for a public type's own
/// constructor); there is deliberately no public type here to have one.
System reproviderSystem(Batching ds, {List<ReproviderOption> options = const []}) =>
    _ReproviderSystem(ds, options: options);

/// Schedules and runs periodic reprovides of a stream of Cids. Equivalent
/// to boxo's unexported `reprovider` struct. Construct via
/// [reproviderSystem].
final class _ReproviderSystem implements System {
  _ReproviderSystem(Batching ds, {List<ReproviderOption> options = const []})
    : _ds = ds {
    for (final option in options) {
      option(this);
    }
    if (!_initialReprovideDelaySet &&
        _reprovideInterval > _defaultInitialReprovideDelay) {
      _initialReprovideDelay = _defaultInitialReprovideDelay;
      _initialReprovideDelaySet = true;
    }
    _run();
  }

  final Batching _ds;

  Duration _reprovideInterval = defaultReproviderInterval;
  Duration _initialReprovideDelay = Duration.zero;
  bool _initialReprovideDelaySet = false;
  Provider? _rsys;
  KeyChanFunc _keyProvider = () => const Stream.empty();
  Key _keyPrefix = defaultKeyPrefix;

  bool _reprovideRunning = false;
  bool _closed = false;
  Completer<void>? _closeSignal;
  Future<void>? _schedulingTask;
  _ReproviderTicker? _ticker;

  int _totalReprovides = 0;
  int _lastReprovideBatchSize = 0;
  Duration _avgReprovideDuration = Duration.zero;
  Duration _lastReprovideDuration = Duration.zero;
  DateTime? _lastRun;

  void _run() {
    if (_reprovideInterval > Duration.zero) {
      _closeSignal = Completer<void>();
      _schedulingTask = _reprovideSchedulingWorker();
    }
  }

  Future<void> _reprovideSchedulingWorker() async {
    final lastReprovide = await _getLastReprovideTime();
    final firstDelay = reprovideFirstDelay(
      reprovideInterval: _reprovideInterval,
      initialReprovideDelay: _initialReprovideDelay,
      now: DateTime.now(),
      lastReprovide: lastReprovide,
    );
    if (!await _waitFirst(firstDelay)) return;

    final ticker = _ReproviderTicker(_reprovideInterval);
    _ticker = ticker;
    try {
      while (true) {
        try {
          await reprovide();
        } catch (error, stackTrace) {
          if (_closed) return;
          _log.severe('failed to reprovide', error, stackTrace);
        }
        if (!await ticker.waitTick(_closeSignal!)) return;
      }
    } finally {
      ticker.stop();
      if (_ticker == ticker) _ticker = null;
    }
  }

  Future<bool> _waitFirst(Duration duration) {
    final signal = _closeSignal;
    if (signal == null || signal.isCompleted) return Future.value(false);
    if (duration == Duration.zero) return Future.value(true);
    final completer = Completer<bool>();
    Timer? timer;
    timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete(true);
    });
    signal.future.then((_) {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });
    return completer.future;
  }

  @override
  Future<void> provide(Cid cid, bool announce) async {
    final rsys = _rsys;
    if (rsys == null) {
      throw StateError('reprovider system is offline');
    }
    await rsys.provide(cid, announce);
  }

  @override
  Future<void> reprovide() async {
    if (_reprovideRunning) {
      throw const _ReproviderAlreadyRunningException();
    }
    _reprovideRunning = true;
    try {
      final rsys = _rsys;
      if (rsys == null) return;

      final keys = <Cid>{};
      await for (final c in _keyProvider()) {
        keys.add(c);
      }
      if (keys.isEmpty) return;

      _log.info('starting reprovide of ${keys.length} keys');
      final start = DateTime.now();
      try {
        for (final c in keys) {
          await rsys.provide(c, true);
        }
      } catch (error, stackTrace) {
        _log.severe('reproviding failed', error, stackTrace);
        return;
      }
      final dur = DateTime.now().difference(start);

      final totalProvideTimeUs =
          _avgReprovideDuration.inMicroseconds * _totalReprovides;
      _totalReprovides += keys.length;
      _avgReprovideDuration = Duration(
        microseconds: (totalProvideTimeUs + dur.inMicroseconds) ~/
            _totalReprovides,
      );
      _lastReprovideBatchSize = keys.length;
      _lastReprovideDuration = dur;
      _lastRun = DateTime.now();
      await _persistLastReprovideTime(_lastRun!);
    } finally {
      _reprovideRunning = false;
    }
  }

  Key get _lastReprovideKey => Key('$_keyPrefix/reprovide/lastreprovide');

  Future<DateTime?> _getLastReprovideTime() async {
    try {
      final bytes = await _ds.get(_lastReprovideKey);
      final nanos = int.parse(utf8.decode(bytes));
      return DateTime.fromMicrosecondsSinceEpoch(nanos ~/ 1000);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistLastReprovideTime(DateTime t) async {
    try {
      final nanos = t.microsecondsSinceEpoch * 1000;
      await _ds.put(_lastReprovideKey, utf8.encode(nanos.toString()));
      await _ds.sync(_lastReprovideKey);
    } catch (error) {
      _log.severe('could not store last reprovide time', error);
    }
  }

  @override
  int clear() => 0;

  @override
  Future<void> close() async {
    _closed = true;
    final signal = _closeSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
    _ticker?.stop();
    final task = _schedulingTask;
    if (task != null) await task;
  }

  @override
  ReproviderStats stat() => ReproviderStats(
    totalReprovides: _totalReprovides,
    lastReprovideBatchSize: _lastReprovideBatchSize,
    reprovideInterval: _reprovideInterval,
    avgReprovideDuration: _avgReprovideDuration,
    lastReprovideDuration: _lastReprovideDuration,
    lastRun: _lastRun,
  );

  @override
  void setKeyProvider(KeyChanFunc kp) => _keyProvider = kp;
}

final class _ReproviderTicker {
  _ReproviderTicker(this.interval) {
    _timer = Timer.periodic(interval, (_) {
      if (_waitingCompleter != null && !_waitingCompleter!.isCompleted) {
        _waitingCompleter!.complete(true);
        _waitingCompleter = null;
      } else {
        _hasTick = true;
      }
    });
  }

  final Duration interval;
  Timer? _timer;
  bool _hasTick = false;
  Completer<bool>? _waitingCompleter;

  Future<bool> waitTick(Completer<void> closeSignal) {
    if (closeSignal.isCompleted) return Future.value(false);
    if (_hasTick) {
      _hasTick = false;
      return Future.value(true);
    }
    final c = Completer<bool>();
    _waitingCompleter = c;
    closeSignal.future.then((_) {
      if (!c.isCompleted) c.complete(false);
    });
    return c.future;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_waitingCompleter != null && !_waitingCompleter!.isCompleted) {
      _waitingCompleter!.complete(false);
      _waitingCompleter = null;
    }
  }
}
