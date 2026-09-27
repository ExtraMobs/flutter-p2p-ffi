part of '../../../sync/atomic.dart';

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
