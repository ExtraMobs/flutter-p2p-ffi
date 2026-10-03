/// Shim do pacote Go `context` (porta de `context/context.go` do Go 1.26):
/// `Context`, `Background`/`TODO`, `WithCancel`/`WithCancelCause`,
/// `WithDeadline`/`WithTimeout` (+ `Cause`), `WithValue`, `WithoutCancel`,
/// `AfterFunc`, `Cause`, `Canceled`, `DeadlineExceeded`.
///
/// `Context` entra em `SHIM_INTERFACES` (`g2d/config.py`): um tipo gerado
/// com os quatro métodos declara `implements context.Context`, e o shim
/// funciona com essas implementações de fora (o cancelamento de um pai
/// desconhecido se propaga por uma goroutine que espera `parent.Done()`,
/// como no Go).
///
/// `Done()` devolve `Chan<EmptyStruct>?` (`<-chan struct{}`; nil para
/// `Background`/`TODO`/`WithoutCancel`). Nada aqui suspende: `Err()` não
/// precisa do `<-c.Done()` do Go (que só sincroniza memória entre threads).
// ignore_for_file: library_prefixes
library;

import 'dart:async';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'fmt.dart' show Stringer;
import 'time.dart' as time;

part 'src/context/impl.dart';

/// `context.Context`. Os nomes dos métodos seguem a regra do g2d (`Value`
/// → `value$`, membro das bases do runtime).
abstract interface class Context {
  /// `Deadline() (deadline time.Time, ok bool)`.
  (time.Time, bool) deadline();

  /// `Done() <-chan struct{}`.
  Chan<EmptyStruct>? done();

  /// `Err() error`.
  GoError? err();

  /// `Value(key any) any`.
  Object? value$(Object? key);
}

/// `context.CancelFunc` (`func()`).
typedef CancelFunc = void Function();

/// `context.CancelCauseFunc` (`func(cause error)`).
typedef CancelCauseFunc = void Function(GoError? cause);

/// `context.Canceled`.
final GoError canceled = ErrorString(
  Golang.String.fromDart('context canceled'),
);

/// `context.DeadlineExceeded` (um `context.deadlineExceededError{}`, com
/// `Timeout()`/`Temporary()` verdadeiros).
final GoError deadlineExceeded = _DeadlineExceededError();

/// `deadlineExceededError{}`: struct vazia guardada por valor na interface
/// (`$isValue`), então `%T`/`%#v` saem sem `*` e todo valor é igual.
final class _DeadlineExceededError extends GoStruct<_DeadlineExceededError>
    implements GoError {
  _DeadlineExceededError() {
    $isValue = true;
  }

  @override
  Golang.String error() => Golang.String.fromDart('context deadline exceeded');

  /// `Timeout() bool`.
  bool timeout() => true;

  /// `Temporary() bool`.
  bool temporary() => true;

  static const _ms = ['Error', 'Temporary', 'Timeout'];

  @override
  String get $goType => 'context.deadlineExceededError';
  @override
  List<String> get $valueMethods => _ms;
  @override
  List<String> get $ptrMethods => _ms;

  @override
  _DeadlineExceededError $copy() => _DeadlineExceededError();
  @override
  void $set(_DeadlineExceededError o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
}

final _background = _BackgroundCtx();
final _todo = _TodoCtx();

/// `context.Background()`.
Context background() => _background;

/// `context.TODO()`.
Context todo() => _todo;

Context _nonNil(Context? parent) =>
    parent ?? _panic('cannot create context from nil parent');

/// `context.WithCancel(parent)`.
(Context, CancelFunc) withCancel(Context? parent) {
  final c = _withCancel(parent);
  return (c, () => c.cancel(true, canceled, null));
}

/// `context.WithCancelCause(parent)`.
(Context, CancelCauseFunc) withCancelCause(Context? parent) {
  final c = _withCancel(parent);
  return (c, (GoError? cause) => c.cancel(true, canceled, cause));
}

_CancelCtx _withCancel(Context? parent) {
  final p = _nonNil(parent);
  final c = _CancelCtx();
  c.propagateCancel(p, c);
  return c;
}

/// `context.Cause(c)`: a causa do cancelamento (a passada a um
/// `CancelCauseFunc` ou `With*Cause`), ou `c.Err()`.
GoError? cause(Context? c) {
  if (c == null) nilDeref();
  final err = c.err();
  if (err == null) return null;
  final cc = c.value$(_cancelCtxKey);
  if (cc is _CancelCtx && cc._cause != null) return cc._cause;
  return err;
}

/// `context.AfterFunc(ctx, f)`: roda [f] numa goroutine nova quando [ctx]
/// for cancelado (na hora, se já foi). `stop()` impede [f] de rodar e
/// devolve `true` se conseguiu.
bool Function() afterFunc(Context? ctx, FutureOr<void> Function()? f) {
  if (ctx == null) nilDeref();
  final a = _AfterFuncCtx(() => f!());
  a.propagateCancel(ctx, a);
  return () {
    var stopped = false;
    if (!a._once) {
      a._once = true;
      stopped = true;
    }
    if (stopped) a.cancel(true, canceled, null);
    return stopped;
  };
}

/// `context.WithoutCancel(parent)`: os valores de [parent], sem prazo nem
/// cancelamento.
Context withoutCancel(Context? parent) => _WithoutCancelCtx(_nonNil(parent));

/// `context.WithDeadline(parent, d)`.
(Context, CancelFunc) withDeadline(Context? parent, time.Time d) =>
    withDeadlineCause(parent, d, null);

/// `context.WithDeadlineCause(parent, d, cause)`.
(Context, CancelFunc) withDeadlineCause(
  Context? parent,
  time.Time d,
  GoError? cause,
) {
  final p = _nonNil(parent);
  final (cur, ok) = p.deadline();
  if (ok && cur.before(d)) return withCancel(p);
  final c = _TimerCtx(d.$copy());
  c.propagateCancel(p, c);
  final dur = time.until(d);
  if (dur <= time.Duration()) {
    c.cancel(true, deadlineExceeded, cause); // o prazo já passou.
    return (c, () => c.cancel(false, canceled, null));
  }
  if (c._err == null) {
    c._timer = time.afterFunc(dur, () {
      c.cancel(true, deadlineExceeded, cause);
    });
  }
  return (c, () => c.cancel(true, canceled, null));
}

/// `context.WithTimeout(parent, timeout)`: `WithDeadline(parent,
/// time.Now().Add(timeout))`.
(Context, CancelFunc) withTimeout(Context? parent, time.Duration timeout) =>
    withDeadline(parent, time.now().add(timeout));

/// `context.WithTimeoutCause(parent, timeout, cause)`.
(Context, CancelFunc) withTimeoutCause(
  Context? parent,
  time.Duration timeout,
  GoError? cause,
) => withDeadlineCause(parent, time.now().add(timeout), cause);

/// `context.WithValue(parent, key, val)`.
Context withValue(Context? parent, Object? key, Object? val) {
  final p = _nonNil(parent);
  if (key == null) _panic('nil key');
  if (!goComparable(key)) _panic('key is not comparable');
  return _ValueCtx(p, key, val);
}
