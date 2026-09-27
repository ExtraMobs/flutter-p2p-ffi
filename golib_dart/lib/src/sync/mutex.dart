part of '../../sync.dart';

/// `sync.Locker`.
abstract interface class Locker {
  void lock();
  void unlock();
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
