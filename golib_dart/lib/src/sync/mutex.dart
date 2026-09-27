part of '../../sync.dart';

/// `sync.Locker`.
abstract interface class Locker {
  void lock();
  void unlock();
}

/// [Locker] que também sabe travar de forma suspensiva. Usado por
/// [Cond.wait$async] para retravar `L` sem cair no limite síncrono do g2d
/// quando `L` está contendido. Um `Locker` Go arbitrário (implementado só
/// com `Lock`/`Unlock`, sem versão async) não implementa isto — `wait$async`
/// então cai para `lock()` síncrono nele.
abstract interface class AsyncLocker implements Locker {
  Future<void> lock$async();
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
final class Mutex extends GoStruct<Mutex> implements AsyncLocker {
  Mutex();

  /// `(*Mutex)(nil)` dentro de uma interface.
  static final Mutex $nil = Mutex()..$nilPtr = true;

  bool _locked = false;
  final _waiters = Queue<Completer<void>>();

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

  /// `Lock()`: já travado, sem outra goroutine viva → deadlock (ninguém mais
  /// destravaria); com outras vivas → limite do g2d (só `lock$async`
  /// esperaria por elas de verdade).
  @override
  void lock() {
    if (!_locked) {
      _locked = true;
      return;
    }
    if (aliveGoroutines <= 1) fatal(_deadlock);
    fatal(
      'g2d: Lock síncrono com mutex já travado por outra goroutine '
      '(contexto que não pode suspender); era preciso lock\$async aqui',
    );
  }

  /// `Lock()` suspensivo: entra na fila (FIFO) se já travado.
  Future<void> lock$async() async {
    if (!_locked) {
      _locked = true;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    goroutineBlocked();
    try {
      await c.future;
    } finally {
      goroutineUnblocked();
    }
  }

  /// `TryLock()`.
  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  /// `Unlock()`: com alguém na fila, a posse passa direto a ele (handoff,
  /// sem destravar de verdade); senão destrava.
  @override
  void unlock() {
    if (!_locked) fatal('sync: unlock of unlocked mutex');
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _locked = false;
  }
}

/// `sync.RWMutex`.
final class RWMutex extends GoStruct<RWMutex> implements AsyncLocker {
  RWMutex();

  /// `(*RWMutex)(nil)` dentro de uma interface.
  static final RWMutex $nil = RWMutex()..$nilPtr = true;

  bool _w = false;
  int _readers = 0;

  /// Escritores esperando a trava ficar livre (nenhum leitor, nenhum
  /// escritor). Não vazio ⟹ preferência de escritor: leitor novo (síncrono
  /// ou não) também espera, em vez de furar a fila.
  final _writerQ = Queue<Completer<void>>();

  /// Leitores esperando por causa de um escritor ativo ou preferido.
  final _readerQ = Queue<Completer<void>>();

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
    if (!_w && _readers == 0) {
      _w = true;
      return;
    }
    if (aliveGoroutines <= 1) fatal(_deadlock);
    fatal(
      'g2d: Lock síncrono com RWMutex contendido (contexto que não pode '
      'suspender); era preciso lock\$async aqui',
    );
  }

  /// `Lock()` suspensivo: preferência de escritor (some com leitores novos
  /// enquanto um escritor espera).
  Future<void> lock$async() async {
    if (!_w && _readers == 0 && _writerQ.isEmpty) {
      _w = true;
      return;
    }
    final c = Completer<void>();
    _writerQ.add(c);
    goroutineBlocked();
    try {
      await c.future;
    } finally {
      goroutineUnblocked();
    }
  }

  /// `TryLock()`.
  bool tryLock() {
    if (_w || _readers > 0) return false;
    _w = true;
    return true;
  }

  /// `Unlock()`: passa a posse a um escritor esperando; senão libera todos
  /// os leitores esperando.
  @override
  void unlock() {
    if (!_w) fatal('sync: Unlock of unlocked RWMutex');
    if (_writerQ.isNotEmpty) {
      _writerQ.removeFirst().complete();
      return;
    }
    _w = false;
    while (_readerQ.isNotEmpty) {
      _readers++;
      _readerQ.removeFirst().complete();
    }
  }

  /// `RLock()`.
  void rLock() {
    if (!_w && _writerQ.isEmpty) {
      _readers++;
      return;
    }
    if (aliveGoroutines <= 1) fatal(_deadlock);
    fatal(
      'g2d: RLock síncrono bloqueado por escritor (contexto que não pode '
      'suspender); era preciso rLock\$async aqui',
    );
  }

  /// `RLock()` suspensivo.
  Future<void> rLock$async() async {
    if (!_w && _writerQ.isEmpty) {
      _readers++;
      return;
    }
    final c = Completer<void>();
    _readerQ.add(c);
    goroutineBlocked();
    try {
      await c.future;
    } finally {
      goroutineUnblocked();
    }
  }

  /// `TryRLock()`.
  bool tryRLock() {
    if (_w || _writerQ.isNotEmpty) return false;
    _readers++;
    return true;
  }

  /// `RUnlock()`: último leitor libera um escritor esperando, se houver.
  void rUnlock() {
    if (_readers == 0) fatal('sync: RUnlock of unlocked RWMutex');
    _readers--;
    if (_readers == 0 && _writerQ.isNotEmpty) {
      _w = true;
      _writerQ.removeFirst().complete();
    }
  }

  /// `RLocker()`: Locker que chama RLock/RUnlock.
  Locker? rLocker() => _RLocker(this);
}

final class _RLocker implements AsyncLocker {
  _RLocker(this._rw);
  final RWMutex _rw;
  @override
  void lock() => _rw.rLock();
  @override
  void unlock() => _rw.rUnlock();
  @override
  Future<void> lock$async() => _rw.rLock$async();
}
