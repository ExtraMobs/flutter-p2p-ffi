/// Go's `context` package (hand-written; functions 16–21 of WIRE.md): the
/// `Context` that asynchronous methods receive and their cancellation.
///
/// ```dart
/// import 'package:ipfs_ffi/go/context.dart' as context;
///
/// final (ctx, cancel) = context.withTimeout(context.background(), Duration(seconds: 30));
/// try {
///   await api.unixfs().get(ctx, path);
/// } finally {
///   cancel();
/// }
/// ```
library;

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: `context.Context` (handle).
class Context extends GoHandle {
  Context.$h(super.$h);

  /// Go: `func (context.Context).Err() error`: null while not canceled.
  String? err() => $callSync(21, $W()..h(this)).err();
}

/// Go: `context.CancelFunc`: call `cancel()` to cancel.
class CancelFunc extends GoHandle {
  CancelFunc.$h(super.$h);

  void call() => $callSync(20, $W()..h(this));
}

/// Go: `func context.Background() context.Context`.
Context background() => $callSync(16).hnn(Context.$h);

(Context, CancelFunc) _pair($R r) => (r.hnn(Context.$h), r.hnn(CancelFunc.$h));

/// Go: `func context.WithCancel(parent Context) (ctx Context, cancel CancelFunc)`.
(Context, CancelFunc) withCancel(Context parent) =>
    _pair($callSync(17, $W()..h(parent)));

/// Go: `func context.WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)`.
(Context, CancelFunc) withTimeout(Context parent, Duration timeout) =>
    _pair($callSync(
        18,
        $W()
          ..h(parent)
          ..i64(timeout.inMicroseconds * 1000)));

/// Go: `func context.WithDeadline(parent Context, d time.Time) (Context, CancelFunc)`.
(Context, CancelFunc) withDeadline(Context parent, DateTime d) =>
    _pair($callSync(
        19,
        $W()
          ..h(parent)
          ..i64(d.microsecondsSinceEpoch * 1000)));
