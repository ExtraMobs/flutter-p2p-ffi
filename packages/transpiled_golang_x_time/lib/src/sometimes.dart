/// Port of `golang.org/x/time/rate`'s `sometimes.go`.
///
/// Go: package `rate` (`sometimes.go:5`).
library;

/// Go: `Sometimes` (`sometimes.go:22-30`).
///
/// Omission: `sync.Mutex mu` (`sometimes.go:27`) is dropped for the same
/// reason as `Limiter`'s in `rate.dart` -- a Dart isolate does not preempt
/// inside synchronous code, and [run]'s body has no `await`, so no second
/// call can interleave inside it. Same precedent as
/// packages/transpiled_libp2p/lib/src/p2p/net/connmgr/connmgr.dart.
///
/// Renaming: Go's method is `Do`, which collides with Dart's reserved `do`
/// keyword and cannot be used as an identifier. This is named [run]
/// instead; register the rename in doc/transpilation/PROGRESS.md when this
/// package is wired in.
class Sometimes {
  /// Go: `Sometimes.First` (`sometimes.go:23`). If non-zero, the first
  /// [first] calls to [run] perform the action.
  int first = 0;

  /// Go: `Sometimes.Every` (`sometimes.go:24`). If non-zero, every
  /// [every]th call to [run] performs the action.
  int every = 0;

  /// Go: `Sometimes.Interval` (`sometimes.go:25`). If non-zero and
  /// [interval] has elapsed since the action last ran, [run] performs it.
  Duration interval = Duration.zero;

  int _count = 0;
  DateTime? _last;

  /// Go: `Sometimes.Do` (`sometimes.go:56-69`).
  ///
  /// The model is a union (not intersection) of filters: the first call to
  /// [run] always performs [f]; subsequent calls perform it if allowed by
  /// [first], [every] or [interval]. See the Go doc comment
  /// (`sometimes.go:32-55`) for the full semantics.
  void run(void Function() f) {
    final intervalElapsed =
        interval > Duration.zero &&
        (_last == null || DateTime.now().difference(_last!) >= interval);

    if (_count == 0 ||
        (first > 0 && _count < first) ||
        (every > 0 && _count % every == 0) ||
        intervalElapsed) {
      f();
      if (interval > Duration.zero) {
        _last = DateTime.now();
      }
    }
    _count++;
  }
}
