/// Shim do pacote Go `sync/atomic`.
///
/// Num isolate só (sem goroutines, M4) as operações atômicas são leituras e
/// escritas simples; o que importa é a semântica Go: os tipos (`Int64`,
/// `Bool`, `Value`, `Pointer[T]`...) são structs de shim por valor
/// (`go.GoStruct`, impressos como o Go: `{{} {} 5}`), e as funções operam
/// sobre `*T` (`go.Ptr`). As variantes com `unsafe.Pointer` ficam de fora
/// (`unsafe:Pointer`).
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;

/// Campo `_ noCopy` / `_ align64` do Go: struct vazia (`{}` no `%v`).
final class _Empty extends GoStruct<_Empty> {
  @override
  String get $goType => 'atomic.noCopy';
  @override
  _Empty $copy() => _Empty();
  @override
  void $set(_Empty o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
}

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

/// `atomic.Bool` (guarda um `uint32`, como o Go: `{{} 1}`).
final class Bool extends GoStruct<Bool> {
  Bool([this._v = false]);

  bool _v;

  @override
  String get $goType => 'atomic.Bool';
  @override
  List<String> get $ptrMethods => const [
    'And',
    'CompareAndSwap',
    'Load',
    'Or',
    'Store',
    'Swap',
  ];
  @override
  Bool $copy() => Bool(_v);
  @override
  void $set(Bool o) => _v = o._v;
  @override
  List<Object?> get $fields => [_Empty(), Golang.Uint32(_v ? 1 : 0)];
  @override
  List<String> get $fieldNames => const ['_', 'v'];

  /// `Load()`.
  bool load() => _v;

  /// `Store(v)`.
  void store(bool v) => _v = v;

  /// `Swap(new)`.
  bool swap(bool n) {
    final old = _v;
    _v = n;
    return old;
  }

  /// `CompareAndSwap(old, new)`.
  bool compareAndSwap(bool old, bool n) {
    if (_v != old) return false;
    _v = n;
    return true;
  }
}

Never _panic(String s) => throw Panic(Golang.String.fromDart(s));

/// `atomic.Value`: o tipo do primeiro valor guardado fixa os seguintes.
final class Value extends GoStruct<Value> {
  Value();

  Object? _v;

  @override
  String get $goType => 'atomic.Value';
  @override
  List<String> get $ptrMethods => const [
    'CompareAndSwap',
    'Load',
    'Store',
    'Swap',
  ];
  @override
  Value $copy() => Value().._v = _v;
  @override
  void $set(Value o) => _v = o._v;
  @override
  List<Object?> get $fields => [_v];
  @override
  List<String> get $fieldNames => const ['v'];

  /// `Load()`: nil antes do primeiro Store.
  Object? load() => _v;

  /// `Store(v)`.
  void store(Object? v) {
    if (v == null) _panic('sync/atomic: store of nil value into Value');
    if (_v != null && goTypeName(_v) != goTypeName(v)) {
      _panic('sync/atomic: store of inconsistently typed value into Value');
    }
    _v = v;
  }

  /// `Swap(new)`.
  Object? swap(Object? n) {
    if (n == null) _panic('sync/atomic: swap of nil value into Value');
    if (_v != null && goTypeName(_v) != goTypeName(n)) {
      _panic('sync/atomic: swap of inconsistently typed value into Value');
    }
    final old = _v;
    _v = n;
    return old;
  }

  /// `CompareAndSwap(old, new)`.
  bool compareAndSwap(Object? old, Object? n) {
    if (n == null) {
      _panic('sync/atomic: compare and swap of nil value into Value');
    }
    if (old != null && goTypeName(old) != goTypeName(n)) {
      _panic('sync/atomic: compare and swap of inconsistently typed values');
    }
    if (_v == null) {
      if (old != null) return false;
      _v = n;
      return true;
    }
    if (goTypeName(_v) != goTypeName(n)) {
      _panic(
        'sync/atomic: compare and swap of inconsistently typed value into Value',
      );
    }
    if (!ifaceEq(_v, old)) return false;
    _v = n;
    return true;
  }
}

const _anyElem = Elem<Object?>(8, zeroNull, pointers: true);

/// `atomic.Pointer[T]` para `T` struct (`*T` é o próprio objeto, `T?`).
final class Pointer<T extends Object> extends GoStruct<Pointer<T>> {
  Pointer(this.$T);

  /// Dicionário do parâmetro de tipo (o g2d passa ao construir).
  final Elem<T> $T;

  T? _v;

  @override
  String get $goType => 'atomic.Pointer';
  @override
  List<String> get $ptrMethods => const [
    'CompareAndSwap',
    'Load',
    'Store',
    'Swap',
  ];
  @override
  Pointer<T> $copy() => Pointer<T>($T).._v = _v;
  @override
  void $set(Pointer<T> o) => _v = o._v;
  @override
  List<Object?> get $fields => [
    GoArray<Object?>.zero(0, _anyElem),
    _Empty(),
    Addr(_v),
  ];
  @override
  List<String> get $fieldNames => const ['_', '_', 'v'];

  /// `Load()`.
  T? load() => _v;

  /// `Store(p)`.
  void store(T? p) => _v = p;

  /// `Swap(new)`.
  T? swap(T? n) {
    final old = _v;
    _v = n;
    return old;
  }

  /// `CompareAndSwap(old, new)`: identidade do ponteiro.
  bool compareAndSwap(T? old, T? n) {
    if (!identical(_v, old)) return false;
    _v = n;
    return true;
  }
}

// --- funções sobre *T ---

/// `atomic.AddInt32(addr, delta)`.
Golang.Int32 addInt32(Ptr<Golang.Int32>? addr, Golang.Int32 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.AddInt64(addr, delta)`.
Golang.Int64 addInt64(Ptr<Golang.Int64>? addr, Golang.Int64 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.AddUint32(addr, delta)`.
Golang.Uint32 addUint32(Ptr<Golang.Uint32>? addr, Golang.Uint32 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.AddUint64(addr, delta)`.
Golang.Uint64 addUint64(Ptr<Golang.Uint64>? addr, Golang.Uint64 delta) =>
    addr!.value = addr.value + delta;

/// `atomic.LoadInt32(addr)`.
Golang.Int32 loadInt32(Ptr<Golang.Int32>? addr) => addr!.value;

/// `atomic.LoadInt64(addr)`.
Golang.Int64 loadInt64(Ptr<Golang.Int64>? addr) => addr!.value;

/// `atomic.LoadUint32(addr)`.
Golang.Uint32 loadUint32(Ptr<Golang.Uint32>? addr) => addr!.value;

/// `atomic.LoadUint64(addr)`.
Golang.Uint64 loadUint64(Ptr<Golang.Uint64>? addr) => addr!.value;

/// `atomic.StoreInt32(addr, v)`.
void storeInt32(Ptr<Golang.Int32>? addr, Golang.Int32 v) => addr!.value = v;

/// `atomic.StoreInt64(addr, v)`.
void storeInt64(Ptr<Golang.Int64>? addr, Golang.Int64 v) => addr!.value = v;

/// `atomic.StoreUint32(addr, v)`.
void storeUint32(Ptr<Golang.Uint32>? addr, Golang.Uint32 v) => addr!.value = v;

/// `atomic.StoreUint64(addr, v)`.
void storeUint64(Ptr<Golang.Uint64>? addr, Golang.Uint64 v) => addr!.value = v;

T _swap<T>(Ptr<T>? addr, T n) {
  final old = addr!.value;
  addr.value = n;
  return old;
}

bool _cas<T>(Ptr<T>? addr, T old, T n) {
  if (addr!.value != old) return false;
  addr.value = n;
  return true;
}

/// `atomic.SwapInt32(addr, new)`.
Golang.Int32 swapInt32(Ptr<Golang.Int32>? addr, Golang.Int32 n) =>
    _swap(addr, n);

/// `atomic.SwapInt64(addr, new)`.
Golang.Int64 swapInt64(Ptr<Golang.Int64>? addr, Golang.Int64 n) =>
    _swap(addr, n);

/// `atomic.SwapUint32(addr, new)`.
Golang.Uint32 swapUint32(Ptr<Golang.Uint32>? addr, Golang.Uint32 n) =>
    _swap(addr, n);

/// `atomic.SwapUint64(addr, new)`.
Golang.Uint64 swapUint64(Ptr<Golang.Uint64>? addr, Golang.Uint64 n) =>
    _swap(addr, n);

/// `atomic.CompareAndSwapInt32(addr, old, new)`.
bool compareAndSwapInt32(
  Ptr<Golang.Int32>? addr,
  Golang.Int32 old,
  Golang.Int32 n,
) => _cas(addr, old, n);

/// `atomic.CompareAndSwapInt64(addr, old, new)`.
bool compareAndSwapInt64(
  Ptr<Golang.Int64>? addr,
  Golang.Int64 old,
  Golang.Int64 n,
) => _cas(addr, old, n);

/// `atomic.CompareAndSwapUint32(addr, old, new)`.
bool compareAndSwapUint32(
  Ptr<Golang.Uint32>? addr,
  Golang.Uint32 old,
  Golang.Uint32 n,
) => _cas(addr, old, n);

/// `atomic.CompareAndSwapUint64(addr, old, new)`.
bool compareAndSwapUint64(
  Ptr<Golang.Uint64>? addr,
  Golang.Uint64 old,
  Golang.Uint64 n,
) => _cas(addr, old, n);
