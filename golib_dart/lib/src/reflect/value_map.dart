part of '../../reflect.dart';

/// `go.Elem` de `reflect.Value` (`[]reflect.Value`).
const $valueElem = Elem<Value>(24, Value.new, pointers: true, value: true);

/// `*reflect.MapIter`.
final class MapIter extends GoStruct<MapIter> {
  MapIter() : _m = Value();
  MapIter._(this._m);

  static final MapIter $nil = MapIter()..$nilPtr = true;

  Value _m;
  List<Object?>? _keys;
  int _i = -1;

  @override
  String get $goType => 'reflect.MapIter';

  @override
  List<String> get $ptrMethods => const ['Key', 'Next', 'Reset', 'Value'];

  @override
  MapIter $copy() => MapIter._(_m)
    .._keys = _keys
    .._i = _i;

  @override
  void $set(MapIter o) {
    _m = o._m;
    _keys = o._keys;
    _i = o._i;
  }

  @override
  List<Object?> get $fields => [_m, _i];

  @override
  List<String> get $fieldNames => const ['m', 'hiter'];

  GoMap get _map => _m.$rep as GoMap;

  /// `MapIter.Next()`: as chaves do início da iteração que ainda estão no map.
  bool next() {
    final keys = _keys ??= _map.keysSnapshot();
    while (++_i < keys.length) {
      if (_map.containsKey(keys[_i])) return true;
    }
    return false;
  }

  Value key() {
    if (_keys == null || _i < 0 || _i >= _keys!.length) {
      throw Panic(Golang.String.fromDart('MapIter.Key called before Next'));
    }
    return Value._of(_m._t!.$key!, _keys![_i], _m._flag & _fRO);
  }

  Value value$() {
    if (_keys == null || _i < 0 || _i >= _keys!.length) {
      throw Panic(Golang.String.fromDart('MapIter.Value called before Next'));
    }
    return Value._of(_m._t!.$elem!, _map[_keys![_i]], _m._flag & _fRO);
  }

  void reset(Value v) {
    _m = v;
    _keys = null;
    _i = -1;
  }
}

/// Valor zero de t? (`Value.IsZero`; -0.0 não é zero, como no Go.)
bool _isZeroRep(RType t, Object? r) {
  switch (t.$kind) {
    case kBool:
      return !(r is GoBool ? r.$b : r as bool);
    case kString:
      return (r as Golang.StringBase).$str.length == 0;
    case kFloat32 || kFloat64:
      final d = (r as Golang.FloatBase).toDouble();
      return d == 0 && !d.isNegative;
    case kComplex64 || kComplex128:
      return r == t.$zero();
    case kArray:
      final a = r as GoArray;
      final e = t.$elem!;
      for (var i = 0; i < a.length; i++) {
        if (!_isZeroRep(e, a[i])) return false;
      }
      return true;
    case kStruct:
      if (t.$opaque) return r == t.$zero();
      for (final f in t.$fields) {
        if (!_isZeroRep(f.type, f.get!(r as Object))) return false;
      }
      return true;
    case kSlice:
      return (r as Slice).isNil;
    case kMap:
      return (r as GoMap).isNil;
    case kPointer || kInterface || kFunc || kChan || kUnsafePointer:
      return r == null;
  }
  if (r is Golang.IntBase) return r.$hi == 0 && r.$lo == 0;
  return false;
}
