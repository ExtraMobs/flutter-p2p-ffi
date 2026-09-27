part of '../../sync.dart';

/// `sync.WaitGroup`.
final class WaitGroup extends GoStruct<WaitGroup> {
  WaitGroup();

  static final WaitGroup $nil = WaitGroup()..$nilPtr = true;

  int _n = 0;
  final _waiters = Queue<Completer<void>>();

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

  /// `Add(delta)`: contador chegou a zero → libera quem estiver em `Wait`.
  void add(Golang.Int delta) {
    _n += delta.toInt();
    if (_n < 0) {
      throw Panic(Golang.String.fromDart('sync: negative WaitGroup counter'));
    }
    if (_n == 0) {
      while (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }

  /// `Done()`.
  void done() => add(Golang.Int(-1));

  /// `Wait()`: contador positivo, sem outra goroutine viva → deadlock
  /// (ninguém mais chamaria `Done`); com outras vivas → limite do g2d (só
  /// `wait$async` esperaria por elas de verdade).
  void wait() {
    if (_n <= 0) return;
    if (aliveGoroutines <= 1) fatal(_deadlock);
    fatal(
      'g2d: Wait síncrono com contador positivo (contexto que não pode '
      'suspender); era preciso wait\$async aqui',
    );
  }

  /// `Wait()` suspensivo.
  Future<void> wait$async() async {
    if (_n <= 0) return;
    final c = Completer<void>();
    _waiters.add(c);
    goroutineBlocked();
    try {
      await c.future;
    } finally {
      goroutineUnblocked();
    }
  }

  /// `Go(f)` (Go 1.25): `Add(1)`, roda `f` numa goroutine nova, `Done()` ao
  /// final dela (mesmo em panic — `Done` corre num `finally`, como o `defer`
  /// do Go).
  void go(FutureOr<void> Function() f) {
    add(Golang.Int(1));
    spawn(() async {
      try {
        final r = f();
        if (r is Future) await r;
      } finally {
        done();
      }
    });
  }
}
