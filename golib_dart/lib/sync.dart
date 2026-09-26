/// Shim do pacote Go `sync`.
///
/// Sem goroutines (M4, `TODO/P0-design-m4-concorrencia.md`) só existe a
/// goroutine do `main`: a semântica Go fica determinística. Esperar por algo
/// que só outra goroutine faria (Lock de mutex travado, `Wait` com contador
/// positivo, `Cond.Wait`) é o deadlock do Go (`fatal error: all goroutines
/// are asleep - deadlock!`); unlock de destravado é o fatal error do Go.
/// `WaitGroup.Go` (cria goroutine) fica de fora.
// ignore_for_file: library_prefixes
library;

import 'dart:collection';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'sync/atomic.dart' as atomic;

const _deadlock = 'all goroutines are asleep - deadlock!';

/// `sync.Locker`.
abstract interface class Locker {
  void lock();
  void unlock();
}

/// Campo `noCopy` do Go (`{}` no `%v`).
final class _NoCopy extends GoStruct<_NoCopy> {
  @override
  String get $goType => 'sync.noCopy';
  @override
  _NoCopy $copy() => _NoCopy();
  @override
  void $set(_NoCopy o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
}

/// `internal/sync.Mutex` (`{state sema}` no `%v`).
final class _MuState extends GoStruct<_MuState> {
  _MuState(this.state);
  final int state;
  @override
  String get $goType => 'sync.Mutex';
  @override
  _MuState $copy() => _MuState(state);
  @override
  void $set(_MuState o) {}
  @override
  List<Object?> get $fields => [Golang.Int32(state), Golang.Uint32()];
  @override
  List<String> get $fieldNames => const ['state', 'sema'];
}

/// `sync.Mutex`.
final class Mutex extends GoStruct<Mutex> implements Locker {
  Mutex();

  /// `(*Mutex)(nil)` dentro de uma interface.
  static final Mutex $nil = Mutex()..$nilPtr = true;

  bool _locked = false;

  @override
  String get $goType => 'sync.Mutex';
  @override
  List<String> get $ptrMethods => const ['Lock', 'TryLock', 'Unlock'];
  @override
  Mutex $copy() => Mutex().._locked = _locked;
  @override
  void $set(Mutex o) => _locked = o._locked;
  @override
  List<Object?> get $fields => [_NoCopy(), _MuState(_locked ? 1 : 0)];
  @override
  List<String> get $fieldNames => const ['_', 'mu'];

  /// `Lock()`: já travado → deadlock (ninguém mais pode destravar).
  @override
  void lock() {
    if (_locked) fatal(_deadlock);
    _locked = true;
  }

  /// `TryLock()`.
  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  /// `Unlock()`.
  @override
  void unlock() {
    if (!_locked) fatal('sync: unlock of unlocked mutex');
    _locked = false;
  }
}

/// `sync.RWMutex`.
final class RWMutex extends GoStruct<RWMutex> implements Locker {
  RWMutex();

  /// `(*RWMutex)(nil)` dentro de uma interface.
  static final RWMutex $nil = RWMutex()..$nilPtr = true;

  bool _w = false;
  int _readers = 0;

  static const _maxReaders = 1 << 30;

  @override
  String get $goType => 'sync.RWMutex';
  @override
  List<String> get $ptrMethods => const [
    'Lock',
    'RLock',
    'RLocker',
    'RUnlock',
    'TryLock',
    'TryRLock',
    'Unlock',
  ];
  @override
  RWMutex $copy() => RWMutex()
    .._w = _w
    .._readers = _readers;
  @override
  void $set(RWMutex o) {
    _w = o._w;
    _readers = o._readers;
  }

  @override
  List<Object?> get $fields => [
    Mutex().._locked = _w,
    Golang.Uint32(),
    Golang.Uint32(),
    atomic.Int32(Golang.Int32(_readers - (_w ? _maxReaders : 0))),
    atomic.Int32(),
  ];
  @override
  List<String> get $fieldNames => const [
    'w',
    'writerSem',
    'readerSem',
    'readerCount',
    'readerWait',
  ];

  /// `Lock()`.
  @override
  void lock() {
    if (_w || _readers > 0) fatal(_deadlock);
    _w = true;
  }

  /// `TryLock()`.
  bool tryLock() {
    if (_w || _readers > 0) return false;
    _w = true;
    return true;
  }

  /// `Unlock()`.
  @override
  void unlock() {
    if (!_w) fatal('sync: Unlock of unlocked RWMutex');
    _w = false;
  }

  /// `RLock()`.
  void rLock() {
    if (_w) fatal(_deadlock);
    _readers++;
  }

  /// `TryRLock()`.
  bool tryRLock() {
    if (_w) return false;
    _readers++;
    return true;
  }

  /// `RUnlock()`.
  void rUnlock() {
    if (_readers == 0) fatal('sync: RUnlock of unlocked RWMutex');
    _readers--;
  }

  /// `RLocker()`: Locker que chama RLock/RUnlock.
  Locker? rLocker() => _RLocker(this);
}

final class _RLocker implements Locker {
  _RLocker(this._rw);
  final RWMutex _rw;
  @override
  void lock() => _rw.rLock();
  @override
  void unlock() => _rw.rUnlock();
}

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

/// `sync.WaitGroup` (sem `Go`, que cria goroutine).
final class WaitGroup extends GoStruct<WaitGroup> {
  WaitGroup();

  static final WaitGroup $nil = WaitGroup()..$nilPtr = true;

  int _n = 0;

  @override
  String get $goType => 'sync.WaitGroup';
  @override
  List<String> get $ptrMethods => const ['Add', 'Done', 'Go', 'Wait'];
  @override
  WaitGroup $copy() => WaitGroup().._n = _n;
  @override
  void $set(WaitGroup o) => _n = o._n;
  @override
  List<Object?> get $fields => [
    _NoCopy(),
    atomic.Uint64(Golang.Uint64(_n) << 32),
    Golang.Uint32(),
  ];
  @override
  List<String> get $fieldNames => const ['noCopy', 'state', 'sema'];

  /// `Add(delta)`.
  void add(Golang.Int delta) {
    _n += delta.toInt();
    if (_n < 0) {
      throw Panic(Golang.String.fromDart('sync: negative WaitGroup counter'));
    }
  }

  /// `Done()`.
  void done() => add(Golang.Int(-1));

  /// `Wait()`: contador positivo → deadlock (só outra goroutine o zeraria).
  void wait() {
    if (_n > 0) fatal(_deadlock);
  }
}

Never _noFmt(String t) =>
    throw UnimplementedError('fmt/== de $t (estrutura interna do Go)');

/// `sync.Pool`: pilha (o último `Put` volta primeiro, como o slot privado do
/// P no Go).
// ponytail: o Go pode esvaziar o Pool a cada GC; aqui nunca esvazia.
final class Pool extends GoStruct<Pool> {
  Pool({this.new$});

  static final Pool $nil = Pool()..$nilPtr = true;

  /// Campo `New` (`func() any`).
  Object? Function()? new$;

  List<Object?> _items = [];

  @override
  String get $goType => 'sync.Pool';
  @override
  List<String> get $ptrMethods => const ['Get', 'Put'];
  @override
  Pool $copy() => Pool(new$: new$).._items = _items;
  @override
  void $set(Pool o) {
    new$ = o.new$;
    _items = o._items;
  }

  @override
  List<Object?> get $fields => _noFmt('sync.Pool');
  @override
  List<String> get $fieldNames => _noFmt('sync.Pool');

  /// `Get()`.
  Object? get() {
    if (_items.isNotEmpty) return _items.removeLast();
    return new$?.call();
  }

  /// `Put(x)` (nil é ignorado, como no Go).
  void put(Object? x) {
    if (x != null) _items.add(x);
  }
}

// Chave `any` com a igualdade de interface do Go: ponteiro para struct por
// identidade, valores por `==`.
int _ifaceHash(Object? k) =>
    k is GoValue && !k.$isValue ? identityHashCode(k) : k.hashCode;

/// `sync.Map` (`Map$`: não sombreia o `Map` do dart:core, como o g2d nomeia).
// ponytail: Range em ordem de inserção (o Go não garante ordem).
final class Map$ extends GoStruct<Map$> {
  Map$();

  static final Map$ $nil = Map$()..$nilPtr = true;

  LinkedHashMap<Object?, Object?> _m = LinkedHashMap(
    equals: ifaceEq,
    hashCode: _ifaceHash,
  );

  @override
  String get $goType => 'sync.Map';
  @override
  List<String> get $ptrMethods => const [
    'Clear',
    'CompareAndDelete',
    'CompareAndSwap',
    'Delete',
    'Load',
    'LoadAndDelete',
    'LoadOrStore',
    'Range',
    'Store',
    'Swap',
  ];
  @override
  Map$ $copy() => Map$().._m = _m;
  @override
  void $set(Map$ o) => _m = o._m;
  @override
  List<Object?> get $fields => _noFmt('sync.Map');
  @override
  List<String> get $fieldNames => _noFmt('sync.Map');

  /// `Load(key)`.
  (Object?, bool) load(Object? key) =>
      _m.containsKey(key) ? (_m[key], true) : (null, false);

  /// `Store(key, value)`.
  void store(Object? key, Object? value) => _m[key] = value;

  /// `LoadOrStore(key, value)`.
  (Object?, bool) loadOrStore(Object? key, Object? value) {
    if (_m.containsKey(key)) return (_m[key], true);
    _m[key] = value;
    return (value, false);
  }

  /// `LoadAndDelete(key)`.
  (Object?, bool) loadAndDelete(Object? key) {
    if (!_m.containsKey(key)) return (null, false);
    return (_m.remove(key), true);
  }

  /// `Delete(key)`.
  void delete$(Object? key) => _m.remove(key);

  /// `Swap(key, value)`: (anterior, existia).
  (Object?, bool) swap(Object? key, Object? value) {
    final loaded = _m.containsKey(key);
    final previous = _m[key];
    _m[key] = value;
    return (previous, loaded);
  }

  /// `CompareAndSwap(key, old, new)`.
  bool compareAndSwap(Object? key, Object? old, Object? n) {
    if (!_m.containsKey(key) || !ifaceEq(_m[key], old)) return false;
    _m[key] = n;
    return true;
  }

  /// `CompareAndDelete(key, old)`.
  bool compareAndDelete(Object? key, Object? old) {
    if (!_m.containsKey(key) || !ifaceEq(_m[key], old)) return false;
    _m.remove(key);
    return true;
  }

  /// `Range(f)`: sobre um retrato das entradas (f pode alterar o Map).
  void range(bool Function(Object?, Object?)? f) {
    for (final e in _m.entries.toList()) {
      if (!_m.containsKey(e.key)) continue;
      if (!f!(e.key, _m[e.key])) return;
    }
  }

  /// `Clear()`.
  void clear() => _m.clear();
}

/// `sync.Cond`: sem outra goroutine, `Wait` nunca é acordado (deadlock);
/// `Signal`/`Broadcast` sem ninguém esperando não fazem nada.
final class Cond extends GoStruct<Cond> {
  Cond({this.l});

  static final Cond $nil = Cond()..$nilPtr = true;

  /// Campo `L`.
  Locker? l;

  @override
  String get $goType => 'sync.Cond';
  @override
  List<String> get $ptrMethods => const ['Broadcast', 'Signal', 'Wait'];
  @override
  Cond $copy() => Cond(l: l);
  @override
  void $set(Cond o) => l = o.l;
  @override
  List<Object?> get $fields => _noFmt('sync.Cond');
  @override
  List<String> get $fieldNames => _noFmt('sync.Cond');

  /// `Wait()`.
  void wait() {
    l!.unlock();
    fatal(_deadlock);
  }

  /// `Signal()`.
  void signal() {}

  /// `Broadcast()`.
  void broadcast() {}
}

/// `sync.NewCond(l)`.
Cond? newCond(Locker? l) => Cond(l: l);

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
