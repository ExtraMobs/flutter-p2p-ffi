// Port of github.com/benbjohnson/clock v1.3.5 (96c602caabb567343046c08a8fca8560b4f00bb4).
//
// Upstream file: clock.go. The package exists so that time-dependent code can
// be driven deterministically from tests: production wires [Clock.new] and
// tests wire a [Mock] whose time only advances when told to.
//
// Deliberate omissions from the upstream `Clock` interface, recorded in
// doc/transpilation/PROGRESS.md:
//
//  * `WithDeadline` and `WithTimeout` (clock.go:28-29, implemented in
//    context.go). They wrap `context.Context`, which this port does not model;
//    no consumer in this repository uses them.
//  * `type Duration = time.Duration` (clock.go:11). Dart's `Duration` is the
//    native type, so the re-export alias has nothing to name.
//
// The upstream `internalTimer` and `internalTicker` types (clock.go:319, 386)
// are a Go idiom -- a struct converted to a second named type purely to attach
// a different method set to the same memory. Dart has no such conversion, so
// [Timer] and [Ticker] implement the private [_ClockTimer] contract directly.

import 'dart:async' hide Timer;
import 'dart:async' as async show Timer;

/// An interface to the functions in the standard library time package.
///
/// Two implementations are available: the default [Clock.new] is a real-time
/// clock that simply wraps the platform clock, and [Mock] only changes when
/// programmatically adjusted.
///
/// Go: `clock.Clock` (`clock.go:18-30`).
abstract interface class Clock {
  /// Returns an instance of a real-time clock.
  ///
  /// Go: `clock.New()` (`clock.go:33-35`).
  factory Clock() = _RealClock;

  /// Waits for [d] to elapse and then yields the current time.
  ///
  /// Go: `After` (`clock.go:39`), whose channel receives exactly one value.
  Future<DateTime> after(Duration d);

  /// Waits for [d] to elapse and then runs [f].
  ///
  /// Go: `AfterFunc` (`clock.go:41-43`).
  Timer afterFunc(Duration d, void Function() f);

  /// The current wall time.
  ///
  /// Go: `Now` (`clock.go:45`).
  DateTime now();

  /// The time elapsed since [t], measured against this clock.
  ///
  /// Go: `Since` (`clock.go:47`).
  Duration since(DateTime t);

  /// The time remaining until [t], measured against this clock.
  ///
  /// Go: `Until` (`clock.go:49`).
  Duration until(DateTime t);

  /// Pauses for [d], measured against this clock.
  ///
  /// On a [Mock] this only completes once the clock is advanced past [d] from
  /// elsewhere, exactly as the upstream blocks until another goroutine calls
  /// [Mock.add].
  ///
  /// Go: `Sleep` (`clock.go:51`).
  Future<void> sleep(Duration d);

  /// Ticks at every interval of [d] on a stream that cannot be stopped.
  ///
  /// Go: `Tick` (`clock.go:53`).
  Stream<DateTime> tick(Duration d);

  /// A new [Ticker] firing every [d].
  ///
  /// Go: `Ticker` (`clock.go:55-58`).
  Ticker ticker(Duration d);

  /// A new [Timer] firing once after [d].
  ///
  /// Go: `Timer` (`clock.go:60-63`).
  Timer timer(Duration d);
}

/// Implements a real-time clock by wrapping the platform's time functions.
///
/// Go: the unexported `clock` struct (`clock.go:38`).
final class _RealClock implements Clock {
  _RealClock();

  @override
  Future<DateTime> after(Duration d) => timer(d).c.first;

  @override
  Timer afterFunc(Duration d, void Function() f) => Timer._realAfterFunc(d, f);

  @override
  DateTime now() => DateTime.now();

  @override
  Duration since(DateTime t) => now().difference(t);

  @override
  Duration until(DateTime t) => t.difference(now());

  @override
  Future<void> sleep(Duration d) => Future<void>.delayed(d);

  @override
  Stream<DateTime> tick(Duration d) => ticker(d).c;

  @override
  Ticker ticker(Duration d) => Ticker._real(d);

  @override
  Timer timer(Duration d) => Timer._real(d);
}

/// An object with an associated next-fire time, held by [Mock].
///
/// Go: the unexported `clockTimer` interface (`clock.go:289-292`).
abstract interface class _ClockTimer {
  DateTime get next;

  Future<void> tick(DateTime now);
}

/// A clock that only moves forward programmatically.
///
/// Preferable to a real-time clock when testing time-based functionality.
///
/// Go: `clock.Mock` (`clock.go:75-82`), constructed by `NewMock`
/// (`clock.go:86-88`) at the Unix epoch.
final class Mock implements Clock {
  /// Creates a mock clock whose current time is the Unix epoch.
  ///
  /// Go: `NewMock()` (`clock.go:86-88`), which uses `time.Unix(0, 0)`.
  Mock() : _now = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime _now;
  final List<_ClockTimer> _timers = <_ClockTimer>[];

  /// Moves the current time forward by [d], running every timer that falls due.
  ///
  /// Go: `Add` (`clock.go:92-110`).
  Future<void> add(Duration d) async {
    final target = _now.add(d);
    while (await _runNextTimer(target)) {}
    _now = target;
    await _gosched();
  }

  /// Moves the current time to [t], running every timer that falls due.
  ///
  /// Go: `Set` (`clock.go:114-127`).
  Future<void> set(DateTime t) async {
    while (await _runNextTimer(t)) {}
    _now = t;
    await _gosched();
  }

  /// Advances the clock until no timer is left pending, and yields the time
  /// reached.
  ///
  /// As upstream, a registered [Ticker] never stops being pending, so this does
  /// not terminate while one is running.
  ///
  /// Go: `WaitForAllTimers` (`clock.go:130-144`).
  Future<DateTime> waitForAllTimers() async {
    while (true) {
      if (_timers.isEmpty) return now();
      _sortTimers();
      final next = _timers[_timers.length - 1].next;
      await set(next);
    }
  }

  /// Runs the next timer in chronological order and moves the current time to
  /// that timer's fire time, unless it falls after [max].
  ///
  /// Go: `runNextTimer` (`clock.go:149-174`).
  Future<bool> _runNextTimer(DateTime max) async {
    _sortTimers();
    if (_timers.isEmpty) return false;
    final t = _timers[0];
    if (t.next.isAfter(max)) return false;
    _now = t.next;
    await t.tick(_now);
    return true;
  }

  void _sortTimers() => _timers.sort((a, b) => a.next.compareTo(b.next));

  /// Go: `removeClockTimer` (`clock.go:277-286`).
  void _removeClockTimer(_ClockTimer t) {
    _timers.remove(t);
    _sortTimers();
  }

  @override
  Future<DateTime> after(Duration d) => timer(d).c.first;

  @override
  Timer afterFunc(Duration d, void Function() f) {
    final t = Timer._mockAfterFunc(this, _now.add(d), f);
    _timers.add(t);
    return t;
  }

  @override
  DateTime now() => _now;

  @override
  Duration since(DateTime t) => _now.difference(t);

  @override
  Duration until(DateTime t) => t.difference(_now);

  @override
  Future<void> sleep(Duration d) => after(d);

  @override
  Stream<DateTime> tick(Duration d) => ticker(d).c;

  @override
  Ticker ticker(Duration d) {
    final t = Ticker._mock(this, d, _now.add(d));
    _timers.add(t);
    return t;
  }

  @override
  Timer timer(Duration d) {
    final t = Timer._mock(this, _now.add(d));
    _timers.add(t);
    unawaited(_runNextTimer(_now));
    return t;
  }
}

/// A single event.
///
/// The current time is emitted on [c], unless the timer was created by
/// [Clock.afterFunc], in which case [c] never emits -- mirroring the nil
/// channel upstream hands back from `AfterFunc`.
///
/// Go: `clock.Timer` (`clock.go:302-310`).
final class Timer implements _ClockTimer {
  Timer._real(Duration d) : _mock = null, _fn = null, _next = DateTime.now() {
    _realTimer = async.Timer(d, () {
      _stopped = true;
      if (!_controller.isClosed) _controller.add(DateTime.now());
    });
  }

  Timer._realAfterFunc(Duration d, void Function() f)
    : _mock = null,
      _fn = f,
      _next = DateTime.now() {
    _realTimer = async.Timer(d, () {
      _stopped = true;
      f();
    });
  }

  Timer._mock(Mock this._mock, this._next) : _fn = null;

  Timer._mockAfterFunc(Mock this._mock, this._next, void Function() f)
    : _fn = f;

  final Mock? _mock;
  final void Function()? _fn;

  /// Single-subscription on purpose: it buffers the fire time until something
  /// listens, which is the behaviour of the buffered-by-one channel upstream
  /// allocates for a timer (`clock.go:190`, `clock.go:259`).
  final StreamController<DateTime> _controller = StreamController<DateTime>();
  async.Timer? _realTimer;
  DateTime _next;
  bool _stopped = false;

  /// Emits the fire time once the timer elapses.
  ///
  /// Go: the exported `C` channel field (`clock.go:303`).
  Stream<DateTime> get c => _controller.stream;

  @override
  DateTime get next => _next;

  /// Turns off the timer, reporting whether it was still registered.
  ///
  /// Go: `Stop` (`clock.go:313-324`).
  bool stop() {
    final realTimer = _realTimer;
    if (realTimer != null) {
      final wasActive = realTimer.isActive;
      realTimer.cancel();
      _stopped = true;
      return wasActive;
    }
    final registered = !_stopped;
    _mock!._removeClockTimer(this);
    _stopped = true;
    return registered;
  }

  /// Changes the expiry time of the timer, reporting whether it was still
  /// registered.
  ///
  /// Go: `Reset` (`clock.go:327-342`).
  bool reset(Duration d) {
    final realTimer = _realTimer;
    if (realTimer != null) {
      final wasActive = realTimer.isActive;
      realTimer.cancel();
      final fn = _fn;
      _realTimer = async.Timer(d, () {
        _stopped = true;
        if (fn != null) {
          fn();
        } else if (!_controller.isClosed) {
          _controller.add(DateTime.now());
        }
      });
      _stopped = false;
      return wasActive;
    }
    final mock = _mock!;
    _next = mock._now.add(d);
    final registered = !_stopped;
    if (_stopped) mock._timers.add(this);
    _stopped = false;
    return registered;
  }

  @override
  Future<void> tick(DateTime now) async {
    final fn = _fn;
    if (fn != null) {
      fn();
    } else if (!_controller.isClosed) {
      _controller.add(now);
    }
    _mock!._removeClockTimer(this);
    _stopped = true;
    await _gosched();
  }
}

/// Emits "ticks" at regular intervals on [c].
///
/// Go: `clock.Ticker` (`clock.go:370-377`).
final class Ticker implements _ClockTimer {
  Ticker._real(this._d) : _mock = null, _next = DateTime.now() {
    _realTicker = async.Timer.periodic(_d, (_) {
      if (!_controller.isClosed) _controller.add(DateTime.now());
    });
  }

  Ticker._mock(Mock this._mock, this._d, this._next);

  final Mock? _mock;
  final StreamController<DateTime> _controller =
      StreamController<DateTime>.broadcast();
  async.Timer? _realTicker;
  Duration _d;
  DateTime _next;
  bool _stopped = false;

  /// Emits the fire time on every tick.
  ///
  /// A tick with no listener attached is dropped, matching the non-blocking
  /// channel send upstream (`clock.go:389-392`).
  ///
  /// Go: the exported `C` channel field (`clock.go:371`).
  Stream<DateTime> get c => _controller.stream;

  @override
  DateTime get next => _next;

  /// Turns off the ticker.
  ///
  /// Go: `Stop` (`clock.go:380-389`).
  void stop() {
    final realTicker = _realTicker;
    if (realTicker != null) {
      realTicker.cancel();
      _stopped = true;
      return;
    }
    _mock!._removeClockTimer(this);
    _stopped = true;
  }

  /// Resets the ticker to a new interval [dur].
  ///
  /// Go: `Reset` (`clock.go:392-407`).
  void reset(Duration dur) {
    final realTicker = _realTicker;
    if (realTicker != null) {
      realTicker.cancel();
      _d = dur;
      _realTicker = async.Timer.periodic(dur, (_) {
        if (!_controller.isClosed) _controller.add(DateTime.now());
      });
      return;
    }
    final mock = _mock!;
    if (_stopped) {
      mock._timers.add(this);
      _stopped = false;
    }
    _d = dur;
    _next = mock._now.add(dur);
  }

  @override
  Future<void> tick(DateTime now) async {
    if (!_controller.isClosed) _controller.add(now);
    _next = now.add(_d);
    await _gosched();
  }
}

/// Yields so that pending listeners can process what a tick just delivered.
///
/// Go: `gosched()` (`clock.go:410`), which sleeps 1ms to let other goroutines
/// run. Dart has no other thread to hand off to, so this drains the microtask
/// queue and one event-loop turn instead, which is what makes a
/// `StreamController` deliver to its listeners before the mock clock advances
/// again.
Future<void> _gosched() => Future<void>.delayed(Duration.zero);
