part of '../../sync.dart';

/// `sync.Cond`.
final class Cond extends GoStruct<Cond> {
  Cond({this.l});

  static final Cond $nil = Cond()..$nilPtr = true;

  /// Campo `L`.
  Locker? l;

  final _waiters = Queue<Completer<void>>();

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

  /// `Wait()`: destrava `L` (como no Go, sempre) e precisa suspender até
  /// `Signal`/`Broadcast`; sem outra goroutine viva → deadlock (ninguém
  /// acordaria); com outras vivas → limite do g2d (só `wait$async` de fato
  /// suspende).
  void wait() {
    l!.unlock();
    if (aliveGoroutines <= 1) fatal(_deadlock);
    fatal(
      'g2d: Cond.Wait síncrono não pode suspender (contexto que não pode '
      'suspender); era preciso wait\$async aqui',
    );
  }

  /// `Wait()` suspensivo: destrava `L`, espera `Signal`/`Broadcast`, retrava
  /// (com `lock$async` se `L` suportar; senão o `lock()` síncrono dele).
  Future<void> wait$async() async {
    final c = Completer<void>();
    _waiters.add(c);
    l!.unlock();
    goroutineBlocked();
    try {
      await c.future;
    } finally {
      goroutineUnblocked();
    }
    final locker = l;
    if (locker is AsyncLocker) {
      await locker.lock$async();
    } else {
      locker!.lock();
    }
  }

  /// `Signal()`: acorda um esperando (FIFO), se houver.
  void signal() {
    if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
  }

  /// `Broadcast()`: acorda todos os esperando.
  void broadcast() {
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }
}

/// `sync.NewCond(l)`.
Cond? newCond(Locker? l) => Cond(l: l);
