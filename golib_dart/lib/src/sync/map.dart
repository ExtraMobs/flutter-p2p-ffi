part of '../../sync.dart';

// Chave `any` com a igualdade de interface do Go: ponteiro para struct por
// identidade, valores por `==`.
int _ifaceHash(Object? k) =>
    k is GoValue && !k.$isValue ? identityHashCode(k) : k.hashCode;

/// `sync.Map` (`Map$`: não sombreia o `Map` do dart:core, como o g2d nomeia).
// ponytail: Range em ordem de inserção (o Go não garante ordem).
final class Map$ extends GoStruct<Map$> {
  Map$();

  static final Map$ $nil = Map$()..$nilPtr = true;

  LinkedHashMap<Object?, Object?> _m = LinkedHashMap(
    equals: ifaceEq,
    hashCode: _ifaceHash,
  );

  @override
  String get $goType => 'sync.Map';
  @override
  List<String> get $ptrMethods => const [
    'Clear',
    'CompareAndDelete',
    'CompareAndSwap',
    'Delete',
    'Load',
    'LoadAndDelete',
    'LoadOrStore',
    'Range',
    'Store',
    'Swap',
  ];
  @override
  Map$ $copy() => Map$().._m = _m;
  @override
  void $set(Map$ o) => _m = o._m;
  @override
  List<Object?> get $fields => _noFmt('sync.Map');
  @override
  List<String> get $fieldNames => _noFmt('sync.Map');

  /// `Load(key)`.
  (Object?, bool) load(Object? key) =>
      _m.containsKey(key) ? (_m[key], true) : (null, false);

  /// `Store(key, value)`.
  void store(Object? key, Object? value) => _m[key] = value;

  /// `LoadOrStore(key, value)`.
  (Object?, bool) loadOrStore(Object? key, Object? value) {
    if (_m.containsKey(key)) return (_m[key], true);
    _m[key] = value;
    return (value, false);
  }

  /// `LoadAndDelete(key)`.
  (Object?, bool) loadAndDelete(Object? key) {
    if (!_m.containsKey(key)) return (null, false);
    return (_m.remove(key), true);
  }

  /// `Delete(key)`.
  void delete$(Object? key) => _m.remove(key);

  /// `Swap(key, value)`: (anterior, existia).
  (Object?, bool) swap(Object? key, Object? value) {
    final loaded = _m.containsKey(key);
    final previous = _m[key];
    _m[key] = value;
    return (previous, loaded);
  }

  /// `CompareAndSwap(key, old, new)`.
  bool compareAndSwap(Object? key, Object? old, Object? n) {
    if (!_m.containsKey(key) || !ifaceEq(_m[key], old)) return false;
    _m[key] = n;
    return true;
  }

  /// `CompareAndDelete(key, old)`.
  bool compareAndDelete(Object? key, Object? old) {
    if (!_m.containsKey(key) || !ifaceEq(_m[key], old)) return false;
    _m.remove(key);
    return true;
  }

  /// `Range(f)`: sobre um retrato das entradas (f pode alterar o Map).
  void range(bool Function(Object?, Object?)? f) {
    for (final e in _m.entries.toList()) {
      if (!_m.containsKey(e.key)) continue;
      if (!f!(e.key, _m[e.key])) return;
    }
  }

  /// `Clear()`.
  void clear() => _m.clear();
}
