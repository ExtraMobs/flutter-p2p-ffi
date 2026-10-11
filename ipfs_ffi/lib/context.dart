/// O pacote `context` do Go (escrito à mão; ver go/runtime.go): o `Context`
/// que os métodos assíncronos recebem e o cancelamento deles.
///
/// ```dart
/// import 'package:ipfs_ffi/context.dart' as context;
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

  /// Go: `func (context.Context).Err() error`: null enquanto não cancelado.
  String? err() => $callSync('context.Context.Err', [this]) as String?;
}

/// Go: `context.CancelFunc`: chame `cancel()` para cancelar.
class CancelFunc extends GoHandle {
  CancelFunc.$h(super.$h);

  void call() => $callSync('context.CancelFunc', [this]);
}

/// Go: `func context.Background() context.Context`.
Context background() =>
    Context.$h($callSync('context.Background', const []) as int);

(Context, CancelFunc) _pair(Object? r) {
  final l = r as List;
  return (Context.$h(l[0] as int), CancelFunc.$h(l[1] as int));
}

/// Go: `func context.WithCancel(parent Context) (ctx Context, cancel CancelFunc)`.
(Context, CancelFunc) withCancel(Context parent) =>
    _pair($callSync('context.WithCancel', [parent]));

/// Go: `func context.WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)`.
(Context, CancelFunc) withTimeout(Context parent, Duration timeout) =>
    _pair($callSync('context.WithTimeout', [parent, timeout]));

/// Go: `func context.WithDeadline(parent Context, d time.Time) (Context, CancelFunc)`.
(Context, CancelFunc) withDeadline(Context parent, DateTime d) =>
    _pair($callSync('context.WithDeadline', [parent, d]));
