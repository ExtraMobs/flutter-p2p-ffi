part of '../../sync.dart';

/// `sync.Once`.
final class Once extends GoStruct<Once> {
  Once();

  static final Once $nil = Once()..$nilPtr = true;

  bool _done = false;
  bool _running = false;

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
  /// marca `done` num defer). `Do` dentro de f é deadlock, como no Go.
  void do$(void Function()? f) {
    if (_done) return;
    if (_running) fatal(_deadlock);
    _running = true;
    try {
      f!();
    } finally {
      _running = false;
      _done = true;
    }
  }
}

/// `sync.OnceFunc(f)`: f roda na primeira chamada; se entrar em panic, toda
/// chamada repete o panic com o mesmo valor.
void Function() onceFunc(void Function()? f) {
  var done = false, valid = false;
  Object? p;
  return () {
    if (!done) {
      done = true;
      try {
        f!();
        valid = true;
      } catch (e) {
        p = panicValue(e);
      }
    }
    if (!valid) throw Panic(p);
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
