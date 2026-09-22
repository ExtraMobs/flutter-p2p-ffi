/// Port of `golang.org/x/time/rate`'s `rate.go` (token-bucket rate limiter).
///
/// Go: package `rate` (`rate.go:1-14`).
///
/// Adaptations recorded here (and to be echoed into
/// doc/transpilation/PROGRESS.md by whoever wires this package in):
///
///  * `sync.Mutex` (`Limiter.mu`, `rate.go:58`) is dropped. A Dart isolate
///    does not preempt inside synchronous code, and none of the regions it
///    guards awaits anything, so the lock has no work to do. Same precedent
///    as `packages/transpiled_libp2p/lib/src/p2p/net/connmgr/connmgr.dart`.
///  * `context.Context` (`Limiter.WaitN`, `rate.go:241`) has no single Dart
///    equivalent, so [Limiter.waitN] takes its two roles apart explicitly: a
///    `deadline` (`ctx.Deadline()`) and a `cancellation` future
///    (`ctx.Done()`). See [Limiter.waitN]'s doc comment.
///  * `(value, error)` returns become thrown exceptions:
///    [WaitBurstExceededException] and [WaitDeadlineExceededException]
///    replace the two `fmt.Errorf` branches of `WaitN`, and
///    [WaitCanceledException] replaces `ctx.Err()`.
///  * `time.Duration` (nanoseconds, int64) becomes Dart's [Duration]
///    (microseconds, int64). [infDuration] keeps the same *role* --
///    the largest representable duration, used only as a "wait forever" /
///    error sentinel -- rather than the same nanosecond count; see its own
///    doc comment.
library;

import 'dart:async';

/// Go: `InfDuration` (`rate.go:143-144`), converted from nanoseconds to
/// microseconds.
///
/// Go defines this as `time.Duration(math.MaxInt64)`, i.e. `2^63 - 1`
/// *nanoseconds* (~292 years). Dart's [Duration] counts microseconds, and a
/// byte-identical copy of the raw `2^63 - 1` integer reinterpreted as
/// microseconds would mean ~292,471 years instead -- 1000x the real span
/// Go represents, and one large enough that `DateTime.add` on any ordinary
/// date throws `RangeError` (`DateTime`'s own range is capped at roughly
/// +/-273,790 years from the epoch, well short of that). This divides by
/// 1000 instead, the correct nanoseconds-to-microseconds conversion, which
/// keeps the *actual wall-clock magnitude* Go's sentinel represents
/// (~292 years) rather than its raw digit sequence. That magnitude is what
/// every use of `InfDuration` in this file relies on: it is added to a
/// [DateTime], compared against another [Duration], or returned to the
/// caller as an "effectively forever" / "not ok" signal, never decomposed
/// back into a token count, so a real multi-century span serves the same
/// role as Go's nanosecond-exact one without overflowing [DateTime].
const int _infDurationMicroseconds = 9223372036854775; // (2^63-1) ~/ 1000

/// Go: `InfDuration` (`rate.go:143-144`). See [_infDurationMicroseconds]
/// for why this is not a literal copy of Go's integer.
const Duration infDuration = Duration(microseconds: _infDurationMicroseconds);

/// Go: `Limit` (`rate.go:16-19`).
///
/// `type Limit float64` is a Go *defined type*, not an alias: it has its own
/// method set (`durationFromTokens`, `tokensFromDuration`) distinct from
/// `float64`. A Dart `typedef` would collapse that distinction and is
/// vetoed by the no-typedef-shims rule regardless, so this is a real class
/// wrapping the `double`.
class Limit {
  /// Go: `Limit` conversions, e.g. `Limit(interval.Seconds())`
  /// (`rate.go:29`).
  const Limit(this.value);

  /// The number of events per second this [Limit] allows.
  final double value;

  /// Go: `Inf` (`rate.go:21-22`).
  ///
  /// Go: `Inf = Limit(math.MaxFloat64)`. Dart's [double.maxFinite] is the
  /// identical IEEE-754 double value that `math.MaxFloat64` is; using
  /// [double.infinity] instead would change [_durationFromTokens]'s
  /// arithmetic (`tokens / value` rounds to `0` for any finite `tokens`
  /// when `value` is actually infinite, instead of the tiny nonzero
  /// quotient a merely-huge finite divisor produces), so it is deliberately
  /// avoided.
  static const Limit inf = Limit(double.maxFinite);

  /// Go: `Limit.durationFromTokens` (`rate.go:403-418`).
  Duration _durationFromTokens(double tokens) {
    if (value <= 0) return infDuration;

    final durationMicros = (tokens / value) * Duration.microsecondsPerSecond;

    // Go caps against `math.MaxInt64` nanoseconds, i.e. against its own
    // InfDuration; this caps against the microsecond equivalent,
    // `_infDurationMicroseconds`, for the same reason (see infDuration's
    // doc comment above).
    if (durationMicros > _infDurationMicroseconds.toDouble()) {
      return infDuration;
    }
    return Duration(microseconds: durationMicros.truncate());
  }

  /// Go: `Limit.tokensFromDuration` (`rate.go:420-427`).
  double _tokensFromDuration(Duration d) {
    if (value <= 0) return 0;
    return (d.inMicroseconds / Duration.microsecondsPerSecond) * value;
  }

  @override
  bool operator ==(Object other) => other is Limit && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Limit($value)';
}

/// Go: `Every` (`rate.go:24-30`).
Limit every(Duration interval) {
  if (interval <= Duration.zero) return Limit.inf;
  final seconds = interval.inMicroseconds / Duration.microsecondsPerSecond;
  return Limit(1 / seconds);
}

/// Thrown by [Limiter.waitN] when `n` exceeds the limiter's burst size
/// while the limit is not [Limit.inf].
///
/// Go: the first `fmt.Errorf` branch of `Limiter.wait` (`rate.go:259-261`).
class WaitBurstExceededException implements Exception {
  /// Creates the exception for a rejected `waitN(n)` call against the given
  /// [burst].
  const WaitBurstExceededException(this.n, this.burst);

  /// The number of tokens that were requested.
  final int n;

  /// The limiter's burst size at the time of the call.
  final int burst;

  @override
  String toString() => "rate: Wait(n=$n) exceeds limiter's burst $burst";
}

/// Thrown by [Limiter.waitN] when granting `n` tokens would need to wait
/// past the caller's deadline.
///
/// Go: the second `fmt.Errorf` branch of `Limiter.wait` (`rate.go:274-277`).
class WaitDeadlineExceededException implements Exception {
  /// Creates the exception for a `waitN(n)` call that cannot be honored
  /// before its deadline.
  const WaitDeadlineExceededException(this.n);

  /// The number of tokens that were requested.
  final int n;

  @override
  String toString() => 'rate: Wait(n=$n) would exceed context deadline';
}

/// Thrown by [Limiter.waitN] when its `cancellation` future completes
/// before a token becomes available.
///
/// Go: `ctx.Err()` returned from the two `<-ctx.Done()` branches of
/// `Limiter.wait` (`rate.go:264-266`, `rate.go:290-294`).
class WaitCanceledException implements Exception {
  /// Creates the exception for a canceled wait.
  const WaitCanceledException();

  @override
  String toString() => 'rate: wait canceled';
}

/// Go: `Reservation` (`rate.go:120-129`).
///
/// All fields are unexported in Go and stay private here; nothing upstream
/// reads them except through [ok], [delay], [delayFrom], [cancel] and
/// [cancelAt].
class Reservation {
  Reservation._({
    required bool ok,
    required Limiter lim,
    required Limit limit,
    int tokens = 0,
    DateTime? timeToAct,
  }) : _ok = ok,
       _lim = lim,
       _limit = limit,
       _tokens = tokens,
       _timeToAct = timeToAct;

  final bool _ok;
  final Limiter _lim;
  final Limit _limit;

  /// Go: `Reservation.tokens` (`rate.go:125`), unexported upstream and kept
  /// private here.
  final int _tokens;
  final DateTime? _timeToAct;

  /// Go: `Reservation.OK` (`rate.go:131-136`).
  bool get ok => _ok;

  /// Go: `Reservation.Delay` (`rate.go:138-141`).
  Duration delay() => delayFrom(DateTime.now());

  /// Go: `Reservation.DelayFrom` (`rate.go:146-159`).
  Duration delayFrom(DateTime t) {
    if (!_ok) return infDuration;
    final d = _timeToAct!.difference(t);
    if (d < Duration.zero) return Duration.zero;
    return d;
  }

  /// Go: `Reservation.Cancel` (`rate.go:161-164`).
  void cancel() => cancelAt(DateTime.now());

  /// Go: `Reservation.CancelAt` (`rate.go:166-204`).
  void cancelAt(DateTime t) {
    if (!_ok) return;

    if (_lim._limit == Limit.inf || _tokens == 0 || _timeToAct!.isBefore(t)) {
      return;
    }

    // Calculate tokens to restore. The duration between lim.lastEvent and
    // r.timeToAct tells us how many tokens were reserved after r was
    // obtained. Those tokens should not be restored.
    final restoreTokens =
        _tokens.toDouble() -
        _limit._tokensFromDuration(_lim._lastEvent.difference(_timeToAct));
    if (restoreTokens <= 0) return;

    // Advance time to now.
    var newTokens = _lim._advance(t);
    // Calculate new number of tokens.
    newTokens += restoreTokens;
    final burst = _lim._burst.toDouble();
    if (newTokens > burst) newTokens = burst;

    // Update state.
    _lim._last = t;
    _lim._tokens = newTokens;
    if (_timeToAct.isAtSameMomentAs(_lim._lastEvent)) {
      final prevEvent = _timeToAct.add(
        _limit._durationFromTokens(-_tokens.toDouble()),
      );
      if (!prevEvent.isBefore(t)) {
        _lim._lastEvent = prevEvent;
      }
    }
  }
}

/// Go: `Limiter` (`rate.go:32-66`).
///
/// The Go zero value (`limit: Limit(0), burst: 0`) rejects every event.
/// `Limiter(const Limit(0), 0)` reproduces that with no separate no-arg
/// constructor, since Go itself has none beyond the zero-value composite
/// literal `Limiter{}` -- there is no public factory for it to map to.
class Limiter {
  /// Go: `NewLimiter` (`rate.go:98-106`).
  Limiter(Limit r, int b)
    : _limit = r,
      _burst = b,
      _tokens = b.toDouble(),
      _last = DateTime.fromMicrosecondsSinceEpoch(0),
      _lastEvent = DateTime.fromMicrosecondsSinceEpoch(0);

  Limit _limit;
  int _burst;
  double _tokens;
  DateTime _last;
  DateTime _lastEvent;

  /// Go: `Limiter.Limit` (`rate.go:68-73`).
  Limit get limit => _limit;

  /// Go: `Limiter.Burst` (`rate.go:75-83`).
  int get burst => _burst;

  /// Go: `Limiter.TokensAt` (`rate.go:85-91`).
  double tokensAt(DateTime t) => _advance(t);

  /// Go: `Limiter.Tokens` (`rate.go:93-96`).
  double tokens() => tokensAt(DateTime.now());

  /// Go: `Limiter.Allow` (`rate.go:108-111`).
  bool allow() => allowN(DateTime.now(), 1);

  /// Go: `Limiter.AllowN` (`rate.go:113-118`).
  bool allowN(DateTime t, int n) => _reserveN(t, n, Duration.zero).ok;

  /// Go: `Limiter.Reserve` (`rate.go:206-209`).
  Reservation reserve() => reserveN(DateTime.now(), 1);

  /// Go: `Limiter.ReserveN` (`rate.go:211-230`).
  Reservation reserveN(DateTime t, int n) => _reserveN(t, n, infDuration);

  /// Go: `Limiter.Wait` (`rate.go:232-235`).
  ///
  /// See [waitN] for how `context.Context` maps to [deadline] and
  /// [cancellation].
  Future<void> wait({DateTime? deadline, Future<void>? cancellation}) =>
      waitN(1, deadline: deadline, cancellation: cancellation);

  /// Go: `Limiter.WaitN` (`rate.go:237-250`) merged with the unexported
  /// `wait` helper it delegates to (`rate.go:253-296`).
  ///
  /// Adaptation: Go threads one `context.Context` through `wait` for two
  /// independent jobs -- a deadline and a cancellation signal. Dart has no
  /// single equivalent type, so they are taken apart explicitly:
  /// [deadline] stands for `ctx.Deadline()`, and [cancellation], an
  /// optional future, stands for `ctx.Done()` -- when it completes before a
  /// token is granted, the wait is aborted and the reservation is rolled
  /// back exactly as Go's `r.Cancel()` does, then [WaitCanceledException] is
  /// thrown in place of `ctx.Err()`. Passing neither reproduces a
  /// `context.Background()` wait bounded only by what [reserveN] itself
  /// decides.
  ///
  /// One more adaptation: Go's `wait` checks `ctx.Done()` synchronously
  /// before reserving anything. A Dart [Future] cannot be inspected
  /// synchronously for "already complete", so this instead lets one
  /// microtask turn pass and checks then -- an already-canceled
  /// [cancellation] is still caught before any token is reserved, just one
  /// microtask later than Go's version.
  Future<void> waitN(
    int n, {
    DateTime? deadline,
    Future<void>? cancellation,
  }) async {
    final burst = _burst;
    final currentLimit = _limit;
    if (n > burst && currentLimit != Limit.inf) {
      throw WaitBurstExceededException(n, burst);
    }

    if (cancellation != null) {
      var canceledAlready = false;
      unawaited(cancellation.then((_) => canceledAlready = true));
      await Future<void>.delayed(Duration.zero);
      if (canceledAlready) throw const WaitCanceledException();
    }

    final t = DateTime.now();
    final waitLimit = deadline == null ? infDuration : deadline.difference(t);

    final r = _reserveN(t, n, waitLimit);
    if (!r.ok) {
      throw WaitDeadlineExceededException(n);
    }

    final d = r.delayFrom(t);
    if (d <= Duration.zero) return;

    final timerFuture = Future<void>.delayed(d);
    if (cancellation == null) {
      await timerFuture;
      return;
    }

    final canceled = await Future.any<bool>(<Future<bool>>[
      timerFuture.then((_) => false),
      cancellation.then((_) => true),
    ]);
    if (canceled) {
      r.cancel();
      throw const WaitCanceledException();
    }
  }

  /// Go: `Limiter.SetLimit` (`rate.go:298-301`).
  void setLimit(Limit newLimit) => setLimitAt(DateTime.now(), newLimit);

  /// Go: `Limiter.SetLimitAt` (`rate.go:303-315`).
  void setLimitAt(DateTime t, Limit newLimit) {
    final newTokens = _advance(t);
    _last = t;
    _tokens = newTokens;
    _limit = newLimit;
  }

  /// Go: `Limiter.SetBurst` (`rate.go:317-320`).
  void setBurst(int newBurst) => setBurstAt(DateTime.now(), newBurst);

  /// Go: `Limiter.SetBurstAt` (`rate.go:322-332`).
  void setBurstAt(DateTime t, int newBurst) {
    final newTokens = _advance(t);
    _last = t;
    _tokens = newTokens;
    _burst = newBurst;
  }

  /// Go: `Limiter.reserveN` (`rate.go:334-381`).
  Reservation _reserveN(DateTime t, int n, Duration maxFutureReserve) {
    if (_limit == Limit.inf) {
      return Reservation._(
        ok: true,
        lim: this,
        limit: const Limit(0),
        tokens: n,
        timeToAct: t,
      );
    }

    var newTokens = _advance(t);
    newTokens -= n.toDouble();

    var waitDuration = Duration.zero;
    if (newTokens < 0) {
      waitDuration = _limit._durationFromTokens(-newTokens);
    }

    final ok = n <= _burst && waitDuration <= maxFutureReserve;

    if (!ok) {
      return Reservation._(ok: false, lim: this, limit: _limit);
    }

    final timeToAct = t.add(waitDuration);
    _last = t;
    _tokens = newTokens;
    _lastEvent = timeToAct;
    return Reservation._(
      ok: true,
      lim: this,
      limit: _limit,
      tokens: n,
      timeToAct: timeToAct,
    );
  }

  /// Go: `Limiter.advance` (`rate.go:383-401`).
  ///
  /// Does not mutate the limiter.
  double _advance(DateTime t) {
    var last = _last;
    if (t.isBefore(last)) {
      last = t;
    }
    final elapsed = t.difference(last);
    final delta = _limit._tokensFromDuration(elapsed);
    var newTokens = _tokens + delta;
    final burst = _burst.toDouble();
    if (newTokens > burst) newTokens = burst;
    return newTokens;
  }
}
