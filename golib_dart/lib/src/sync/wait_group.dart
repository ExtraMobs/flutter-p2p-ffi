part of '../../sync.dart';

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
