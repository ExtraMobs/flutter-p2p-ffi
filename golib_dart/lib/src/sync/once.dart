part of '../../sync.dart';

/// `sync.Once`.
final class Once extends GoStruct<Once> {
  Once();

  static final Once $nil = Once()..$nilPtr = true;

  bool _done = false;
  bool _running = false;
  final _waiters = Queue<Completer<void>>();

  @override
  String get $goType => 'sync.Once';
  @override
  List<String> get $ptrMethods => const ['Do'];
  @override
  Once $copy() => Once()
    .._done = _done
    .._running = _running;
  @override
  void $set(Once o) {
    _done = o._done;
    _running = o._running;
  }

  @override
  List<Object?> get $fields => [
    _NoCopy(),
    atomic.Uint32(Golang.Uint32(_done ? 1 : 0)),
    Mutex().._locked = _running,
  ];
  @override
  List<String> get $fieldNames => const ['_', 'done', 'm'];

  /// `Do(f)`: f roda uma vez; se f entrar em panic, conta como feito (o Go
  /// marca `done` num defer). `Do` concorrente dentro de f, sem outra
  /// goroutine viva, é deadlock; com outras vivas, limite do g2d (só
  /// `do$async` de fato espera a primeira chamada terminar).
  void do$(void Function()? f) {
    if (_done) return;
    if (_running) {
      if (aliveGoroutines <= 1) fatal(_deadlock);
      fatal(
        'g2d: Once.Do síncrono concorrente com outra chamada em andamento '
        '(contexto que não pode suspender); era preciso do\$async aqui',
      );
    }
    _running = true;
    try {
      f!();
    } finally {
      _running = false;
      _done = true;
      _wakeWaiters();
    }
  }

  /// `Do(f)` suspensivo: chamadas concorrentes esperam a primeira terminar
  /// (mesmo que ela entre em panic — o Go marca `done` num defer, então elas
  /// só voltam a rodar `f`, nunca; ficam sem panic, como no Go).
  Future<void> do$async(FutureOr<void> Function()? f) async {
    if (_done) return;
    if (_running) {
      final c = Completer<void>();
      _waiters.add(c);
      goroutineBlocked();
      try {
        await c.future;
      } finally {
        goroutineUnblocked();
      }
      return;
    }
    _running = true;
    try {
      final r = f!();
      if (r is Future) await r;
    } finally {
      _running = false;
      _done = true;
      _wakeWaiters();
    }
  }

  void _wakeWaiters() {
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }
}

/// `sync.OnceFunc(f)`: f roda na primeira chamada; se entrar em panic, toda
/// chamada repete o panic com o mesmo valor.
R Function() onceFunc<R>(R Function()? f) {
  // R é `void` ou, numa classe de func `async`, `Future<void>`: as chamadas
  // seguintes devolvem o mesmo Future (esperam a primeira terminar e repetem
  // o panic dela, como o Go).
  var done = false, valid = false;
  Object? p;
  late R result;
  return () {
    if (!done) {
      done = true;
      try {
        result = f!();
        valid = true;
      } catch (e) {
        p = panicValue(e);
      }
    }
    if (!valid) throw Panic(p);
    return result;
  };
}

/// `sync.OnceValue[T](f)`.
T Function() onceValue<T>(Elem<T> $T, T Function()? f) {
  var done = false, valid = false;
  Object? p;
  late T result;
  return () {
    if (!done) {
      done = true;
      try {
        result = f!();
        valid = true;
      } catch (e) {
        p = panicValue(e);
      }
    }
    if (!valid) throw Panic(p);
    return result;
  };
}

/// `sync.OnceValues[T1, T2](f)`.
(T1, T2) Function() onceValues<T1, T2>(
  Elem<T1> $T1,
  Elem<T2> $T2,
  (T1, T2) Function()? f,
) {
  var done = false, valid = false;
  Object? p;
  late (T1, T2) result;
  return () {
    if (!done) {
      done = true;
      try {
        result = f!();
        valid = true;
      } catch (e) {
        p = panicValue(e);
      }
    }
    if (!valid) throw Panic(p);
    return result;
  };
}
