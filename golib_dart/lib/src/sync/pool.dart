part of '../../sync.dart';

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
