part of '../../../sync/atomic.dart';

const _methods = [
  'Add',
  'And',
  'CompareAndSwap',
  'Load',
  'Or',
  'Store',
  'Swap',
];

/// Base dos inteiros atômicos (`Int32`, `Int64`, `Uint32`, `Uint64`,
/// `Uintptr`): o valor `v` e os métodos do Go.
abstract base class _AtomicInt<
  S extends _AtomicInt<S, V>,
  V extends Golang.IntBase<V>
>
    extends GoStruct<S> {
  _AtomicInt(this._v);

  V _v;

  /// Campos `_` antes de `v` (64 bits: `noCopy` e `align64`).
  int get _pads;

  S _make(V v);

  @override
  List<String> get $ptrMethods => _methods;

  @override
  S $copy() => _make(_v);

  @override
  void $set(S o) => _v = o._v;

  @override
  List<Object?> get $fields => [for (var i = 0; i < _pads; i++) _Empty(), _v];

  @override
  List<String> get $fieldNames => [for (var i = 0; i < _pads; i++) '_', 'v'];

  /// `Load()`.
  V load() => _v;

  /// `Store(v)`.
  void store(V v) => _v = v;

  /// `Add(delta)`: o novo valor.
  V add(V delta) => _v = _v + delta;

  /// `Swap(new)`: o valor antigo.
  V swap(V n) {
    final old = _v;
    _v = n;
    return old;
  }

  /// `CompareAndSwap(old, new)`.
  bool compareAndSwap(V old, V n) {
    if (_v != old) return false;
    _v = n;
    return true;
  }

  /// `And(mask)`: o valor antigo.
  V and(V mask) => swap(_v & mask);

  /// `Or(mask)`: o valor antigo.
  V or(V mask) => swap(_v | mask);
}

/// `atomic.Int32`.
final class Int32 extends _AtomicInt<Int32, Golang.Int32> {
  Int32([Golang.Int32? v]) : super(v ?? Golang.Int32());
  @override
  int get _pads => 1;
  @override
  Int32 _make(Golang.Int32 v) => Int32(v);
  @override
  String get $goType => 'atomic.Int32';
}

/// `atomic.Int64`.
final class Int64 extends _AtomicInt<Int64, Golang.Int64> {
  Int64([Golang.Int64? v]) : super(v ?? Golang.Int64());
  @override
  int get _pads => 2;
  @override
  Int64 _make(Golang.Int64 v) => Int64(v);
  @override
  String get $goType => 'atomic.Int64';
}

/// `atomic.Uint32`.
final class Uint32 extends _AtomicInt<Uint32, Golang.Uint32> {
  Uint32([Golang.Uint32? v]) : super(v ?? Golang.Uint32());
  @override
  int get _pads => 1;
  @override
  Uint32 _make(Golang.Uint32 v) => Uint32(v);
  @override
  String get $goType => 'atomic.Uint32';
}

/// `atomic.Uint64`.
final class Uint64 extends _AtomicInt<Uint64, Golang.Uint64> {
  Uint64([Golang.Uint64? v]) : super(v ?? Golang.Uint64());
  @override
  int get _pads => 2;
  @override
  Uint64 _make(Golang.Uint64 v) => Uint64(v);
  @override
  String get $goType => 'atomic.Uint64';
}

/// `atomic.Uintptr`.
final class Uintptr extends _AtomicInt<Uintptr, Golang.Uintptr> {
  Uintptr([Golang.Uintptr? v]) : super(v ?? Golang.Uintptr());
  @override
  int get _pads => 1;
  @override
  Uintptr _make(Golang.Uintptr v) => Uintptr(v);
  @override
  String get $goType => 'atomic.Uintptr';
}
