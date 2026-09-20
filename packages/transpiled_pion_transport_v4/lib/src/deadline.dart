// Port of github.com/pion/transport/v4/deadline/deadline.go (revision fixed
// in doc/transpilation/UPSTREAM_LOCK.md).
//
// Byte-for-byte identical in behavior to v3's `deadline` package (only
// parameter names and `interface{}` -> `any` differ upstream between the two
// module versions), but ported separately here because `pion/transport/v3`
// and `pion/transport/v4` are distinct go.mod boundaries (Rule 11) and this
// package cannot depend on `transpiled_pion_transport`, which belongs to the
// v3 boundary.
import 'dart:async';

/// Thrown when [Deadline.err] observes that the deadline has elapsed. Port of
/// the Go sentinel `context.DeadlineExceeded`, which `deadline.go:104`
/// returns from `Err()` (deadline.go:102-108).
class DeadlineExceededException implements Exception {
  @override
  String toString() => 'DeadlineExceededException: deadline exceeded';
}

enum _DeadlineState { stopped, started, exceeded }

/// Updatable deadline timer. Port of `deadline.Deadline` (deadline.go:26-33).
///
/// In Go, `Deadline` also implements `context.Context` (deadline.go:22) so
/// that `github.com/pion/dtls` can pass it directly as a `context.Context` to
/// cancellable reads/writes. This project has no general `context.Context`
/// port (AGENTS.md: adapt Go concurrency primitives to the closest Dart
/// equivalent only when behavior requires it), so only the members Go's
/// `Deadline` actually exposes are ported below, with Dart idioms in place of
/// the `context.Context` method names: [done] replaces `Done()`, [err]
/// replaces `Err()`, [deadline] replaces `Deadline()`, and [value] replaces
/// `Value(any)`.
///
/// Go guards every field with a `sync.RWMutex` (deadline.go:27) and tracks a
/// `pending uint8` counter (deadline.go:33) solely to detect the race
/// between a `time.AfterFunc` callback firing on its own goroutine and a
/// concurrent call to [set] -- Go's timer callback can run truly
/// concurrently with the goroutine that called `Set`. Dart has no such race:
/// a single isolate never runs two callbacks at once, so a `Timer` callback
/// can never overlap a call to [set]. Both the mutex and the `pending`
/// counter are therefore dropped; [set] and the timer callback simply run to
/// completion in the deterministic order the event loop gives them, which
/// reproduces the same observable end state the Go counter existed to
/// guarantee under real concurrency.
class Deadline {
  /// Creates a new deadline timer, initially unset. Port of `New()`
  /// (deadline.go:36-40).
  Deadline();

  Timer? _timer;
  Completer<void> _doneCompleter = Completer<void>();
  DateTime? _deadline;
  _DeadlineState _state = _DeadlineState.stopped;

  void _timeout() {
    if (_state != _DeadlineState.started) return;
    _state = _DeadlineState.exceeded;
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }

  /// Sets a new deadline. `null` means no deadline, mirroring the Go zero
  /// value `time.Time{}` (deadline.go:72-77). Port of `Set` (deadline.go:57-92).
  void set(DateTime? t) {
    _timer?.cancel();
    _timer = null;

    _deadline = t;

    if (_state == _DeadlineState.exceeded) {
      // A previous deadline already fired and completed [_doneCompleter];
      // Go re-makes the `done` channel here (deadline.go:75) so a fresh
      // wait can start. Mirror that with a fresh Completer.
      _doneCompleter = Completer<void>();
    }

    if (t == null) {
      _state = _DeadlineState.stopped;
      return;
    }

    final dur = t.difference(DateTime.now());
    if (dur > Duration.zero) {
      _state = _DeadlineState.started;
      _timer = Timer(dur, _timeout);
      return;
    }

    _state = _DeadlineState.exceeded;
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }

  /// Completes when the deadline elapses. Port of `Done()` (deadline.go:94-98),
  /// adapted from a Go `<-chan struct{}` to a `Future`: awaiting (or
  /// listening to) the same instance from multiple call sites is supported
  /// by `Future`, just as multiple goroutines can `select` on the same
  /// channel.
  Future<void> get done => _doneCompleter.future;

  /// Returns [DeadlineExceededException] once the deadline has elapsed,
  /// otherwise `null`. Port of `Err()` (deadline.go:102-108).
  DeadlineExceededException? get err =>
      _state == _DeadlineState.exceeded ? DeadlineExceededException() : null;

  /// Returns the current deadline, or `null` if none is set. Port of
  /// `Deadline()` (deadline.go:112-118); Go returns `(time.Time, bool)`
  /// where the `bool` is `false` only when the time is the zero value --
  /// collapsed here into a single nullable value, since a `null` deadline
  /// carries exactly that information without an extra tuple element (and
  /// this is a value/presence pair, not a Go `(value, error)` result).
  DateTime? get deadline => _deadline;

  /// Always returns `null`. Port of `Value(any) any` (deadline.go:122-124),
  /// which is a no-op in the Go source and exists only to satisfy the
  /// `context.Context` interface; [Deadline] carries no context-scoped
  /// key/value data.
  Object? value(Object? key) => null;
}
