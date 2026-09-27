part of '../../sync.dart';

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
