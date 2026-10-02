part of '../../context.dart';

// Os contextos concretos do Go (`emptyCtx`, `cancelCtx`, `timerCtx`,
// `valueCtx`, `withoutCancelCtx`, `afterFuncCtx`), portados 1:1. Sem
// `sync.Mutex`/`atomic`: o código Dart roda num laço de eventos só, e nada
// aqui suspende no meio.

Never _panic(String s) => throw Panic(Golang.String.fromDart(s));

Golang.String _gs(String s) => Golang.String.fromDart(s);

/// `&cancelCtxKey`: a chave com que um contexto acha o `cancelCtx` mais
/// próximo pela cadeia de `Value` (inclusive através de implementações de
/// fora que embutem um contexto do shim).
final Object _cancelCtxKey = Object();

/// `closedchan`: o `Done()` de quem foi cancelado antes de alguém pedir o
/// canal.
final Chan<EmptyStruct> _closedchan = Chan<EmptyStruct>(0, EmptyStruct())
  ..close();

const _ctxMethods = ['Deadline', 'Done', 'Err', 'String', 'Value'];

/// `contextName(c)`: `String()` se houver, senão o nome do tipo.
Golang.String _contextName(Context c) {
  if (c is Stringer && goHasMethod(c, 'String'))
    return (c as Stringer).string();
  return _gs(goTypeName(c));
}

/// `stringify(v)` (chave e valor do `WithValue` no `String()`).
Golang.String _stringify(Object? v) => switch (v) {
  Stringer s when goHasMethod(s, 'String') => s.string(),
  Golang.String s => s,
  null => _gs('<nil>'),
  _ => _gs(goTypeName(v)),
};

/// `value(c, key)`: anda a cadeia sem recursão pelos tipos conhecidos.
Object? _value(Context c, Object? key) {
  for (;;) {
    switch (c) {
      case _ValueCtx ctx:
        if (ifaceEq(key, ctx.key)) return ctx.val;
        c = ctx.parent;
      case _CancelCtx ctx:
        if (identical(key, _cancelCtxKey)) return ctx;
        c = ctx.parent;
      case _WithoutCancelCtx ctx:
        if (identical(key, _cancelCtxKey)) return null;
        c = ctx.c;
      case _EmptyCtx():
        return null;
      default:
        return c.value$(key);
    }
  }
}

/// `parentCancelCtx(parent)`: o `cancelCtx` do shim por trás de [parent],
/// se o `Done()` dele é mesmo o de [parent] (uma implementação de fora pode
/// embutir um contexto do shim e trocar o canal).
_CancelCtx? _parentCancelCtx(Context parent) {
  final done = parent.done();
  if (done == null || identical(done, _closedchan)) return null;
  final p = parent.value$(_cancelCtxKey);
  if (p is! _CancelCtx) return null;
  if (!identical(p._done, done)) return null;
  return p;
}

/// `removeChild(parent, child)`.
void _removeChild(Context parent, _CancelCtx child) {
  _parentCancelCtx(parent)?._children?.remove(child);
}

abstract class _EmptyCtx implements Context, Stringer, Golang.GoTyped {
  @override
  (time.Time, bool) deadline() => (time.Time(), false);
  @override
  Chan<EmptyStruct>? done() => null;
  @override
  GoError? err() => null;
  @override
  Object? value$(Object? key) => null;
  @override
  List<String> get $methods => _ctxMethods;
}

final class _BackgroundCtx extends _EmptyCtx {
  @override
  Golang.String string() => _gs('context.Background');
  @override
  String get $goType => 'context.backgroundCtx';
}

final class _TodoCtx extends _EmptyCtx {
  @override
  Golang.String string() => _gs('context.TODO');
  @override
  String get $goType => 'context.todoCtx';
}

/// `*cancelCtx`. Também é o `canceler` do Go: `_TimerCtx` e
/// `_AfterFuncCtx` sobrescrevem [cancel].
class _CancelCtx implements Context, Stringer, Golang.GoTyped {
  /// O `Context` embutido (o pai).
  late Context parent;
  Chan<EmptyStruct>? _done;

  /// Filhos a cancelar junto (`map[canceler]struct{}`; identidade).
  Set<_CancelCtx>? _children;
  GoError? _err;
  GoError? _cause;

  @override
  (time.Time, bool) deadline() => parent.deadline();

  @override
  Chan<EmptyStruct>? done() => _done ??= Chan<EmptyStruct>(0, EmptyStruct());

  @override
  GoError? err() => _err;

  @override
  Object? value$(Object? key) =>
      identical(key, _cancelCtxKey) ? this : _value(parent, key);

  @override
  Golang.String string() => _contextName(parent) + _gs('.WithCancel');

  @override
  String get $goType => '*context.cancelCtx';

  @override
  List<String> get $methods => _ctxMethods;

  /// `propagateCancel(parent, child)`: liga [child] ao cancelamento de
  /// [parent].
  void propagateCancel(Context parent, _CancelCtx child) {
    this.parent = parent;
    final done = parent.done();
    if (done == null) return; // o pai nunca é cancelado.
    if (selectNow([RecvCase(done)]).$1 == 0) {
      child.cancel(false, parent.err(), cause(parent));
      return;
    }
    final p = _parentCancelCtx(parent);
    if (p != null) {
      if (p._err != null) {
        child.cancel(false, p._err, p._cause);
      } else {
        (p._children ??= Set.identity()).add(child);
      }
      return;
    }
    // ponytail: o Go ainda tenta `parent.(afterFuncer)` (um `AfterFunc` do
    // próprio pai) antes da goroutine; implementação de fora com esse
    // método cai aqui, com o mesmo efeito observável.
    spawn(() async {
      final (i, _, _) = await select([
        RecvCase(parent.done()),
        RecvCase(child.done()),
      ]);
      if (i == 0) child.cancel(false, parent.err(), cause(parent));
    });
  }

  /// `cancel(removeFromParent, err, cause)`: fecha `done`, cancela os
  /// filhos e (se pedido) sai da lista do pai.
  void cancel(bool removeFromParent, GoError? err, GoError? cause) {
    if (err == null) _panic('context: internal error: missing cancel error');
    cause ??= err;
    if (_err != null) return; // já cancelado.
    _err = err;
    _cause = cause;
    final d = _done;
    if (d == null) {
      _done = _closedchan;
    } else {
      d.close();
    }
    final children = _children;
    _children = null;
    if (children != null) {
      for (final child in children) {
        child.cancel(false, err, cause);
      }
    }
    if (removeFromParent) _removeChild(parent, this);
  }
}

/// `*timerCtx` (`WithDeadline`/`WithTimeout`).
final class _TimerCtx extends _CancelCtx {
  _TimerCtx(this._deadline);

  final time.Time _deadline;
  time.Timer? _timer;

  @override
  (time.Time, bool) deadline() => (_deadline.$copy(), true);

  @override
  Golang.String string() =>
      _contextName(parent) +
      _gs('.WithDeadline(') +
      _deadline.string() +
      _gs(' [') +
      time.until(_deadline).string() +
      _gs('])');

  @override
  String get $goType => '*context.timerCtx';

  @override
  void cancel(bool removeFromParent, GoError? err, GoError? cause) {
    super.cancel(false, err, cause);
    if (removeFromParent) _removeChild(parent, this);
    _timer?.stop();
    _timer = null;
  }
}

/// `*afterFuncCtx` (`AfterFunc`): cancelar roda `f` numa goroutine, uma
/// vez (`once`), a menos que o `stop()` chegue antes.
final class _AfterFuncCtx extends _CancelCtx {
  _AfterFuncCtx(this._f);

  final FutureOr<void> Function() _f;
  bool _once = false;

  @override
  String get $goType => '*context.afterFuncCtx';

  @override
  void cancel(bool removeFromParent, GoError? err, GoError? cause) {
    super.cancel(false, err, cause);
    if (removeFromParent) _removeChild(parent, this);
    if (!_once) {
      _once = true;
      spawn(_f);
    }
  }
}

/// `*valueCtx` (`WithValue`).
final class _ValueCtx implements Context, Stringer, Golang.GoTyped {
  _ValueCtx(this.parent, this.key, this.val);

  final Context parent;
  final Object? key;
  final Object? val;

  @override
  (time.Time, bool) deadline() => parent.deadline();
  @override
  Chan<EmptyStruct>? done() => parent.done();
  @override
  GoError? err() => parent.err();
  @override
  Object? value$(Object? key) =>
      ifaceEq(this.key, key) ? val : _value(parent, key);

  @override
  Golang.String string() =>
      _contextName(parent) +
      _gs('.WithValue(') +
      _stringify(key) +
      _gs(', ') +
      _stringify(val) +
      _gs(')');

  @override
  String get $goType => '*context.valueCtx';
  @override
  List<String> get $methods => _ctxMethods;
}

/// `withoutCancelCtx` (`WithoutCancel`).
final class _WithoutCancelCtx implements Context, Stringer, Golang.GoTyped {
  _WithoutCancelCtx(this.c);

  final Context c;

  @override
  (time.Time, bool) deadline() => (time.Time(), false);
  @override
  Chan<EmptyStruct>? done() => null;
  @override
  GoError? err() => null;
  @override
  Object? value$(Object? key) => _value(this, key);

  @override
  Golang.String string() => _contextName(c) + _gs('.WithoutCancel');

  @override
  String get $goType => 'context.withoutCancelCtx';
  @override
  List<String> get $methods => _ctxMethods;
}
