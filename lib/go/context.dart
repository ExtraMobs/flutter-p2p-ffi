/// Go's `context` package (hand-written; functions 16–21 of WIRE.md): the
/// `Context` that asynchronous methods receive and their cancellation.
///
/// ```dart
/// import 'package:p2p_ffi/p2p_ffi.dart';
///
/// final (ctx, cancel) =
///     goContext.withTimeout(goContext.background(), Duration(seconds: 30));
/// try {
///   await api.unixfs().get(ctx, path);
/// } finally {
///   cancel();
/// }
/// ```
library;

import 'package:p2p_ffi/src/go.dart' show GoContext;
import 'package:p2p_ffi/src/runtime.dart';

part 'context.g.dart';

/// Go: `context.Context` (handle).
class Context extends GoHandle {
  Context.$h(super.$h);

  /// Go: `func (context.Context).Err() error`: null while not canceled.
  String? err() => $callSync(21, $W()..h(this)).err();
}

/// Go: `context.CancelFunc`: call `cancel()` to cancel.
class ContextCancelFunc extends GoHandle {
  ContextCancelFunc.$h(super.$h);

  void call() => $callSync(20, $W()..h(this));
}

(Context, ContextCancelFunc) _pair($R r) =>
    (r.hnn(Context.$h), r.hnn(ContextCancelFunc.$h));

/// Go: the package-level functions of `context` (`goContext`).
extension GoContextApi on GoContext {
  /// Go: `func context.Background() context.Context`.
  Context background() => $callSync(16).hnn(Context.$h);

  /// Go: `func context.WithCancel(parent Context) (ctx Context, cancel CancelFunc)`.
  (Context, ContextCancelFunc) withCancel(Context parent) =>
      _pair($callSync(17, $W()..h(parent)));

  /// Go: `func context.WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)`.
  (Context, ContextCancelFunc) withTimeout(Context parent, Duration timeout) =>
      _pair($callSync(
          18,
          $W()
            ..h(parent)
            ..i64(timeout.inMicroseconds * 1000)));

  /// Go: `func context.WithDeadline(parent Context, d time.Time) (Context, CancelFunc)`.
  (Context, ContextCancelFunc) withDeadline(Context parent, DateTime d) =>
      _pair($callSync(
          19,
          $W()
            ..h(parent)
            ..i64(d.microsecondsSinceEpoch * 1000)));
}
