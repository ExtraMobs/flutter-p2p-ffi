part of '../../reflect.dart';

/// `reflect.DeepEqual(x, y)`: igualdade profunda do Go (mesmo tipo
/// dinâmico; slices e maps nil × vazios diferem; ponteiros iguais ou com
/// apontados profundamente iguais; funcs só iguais se ambas nil; NaN nunca
/// é igual a si mesmo).
bool deepEqual(Object? x, Object? y) {
  if (x == null || y == null) return x == null && y == null;
  final v1 = valueOf(x), v2 = valueOf(y);
  if (!identical(v1._t, v2._t)) return false;
  return _deepValueEqual(v1._t!, v1.$rep, v2.$rep, {});
}

bool _deepValueEqual(
  RType t,
  Object? a,
  Object? b,
  Set<(Object, Object, RType)> visited,
) {
  switch (t.$kind) {
    case kArray:
      final x = a as GoArray, y = b as GoArray;
      final e = t.$elem!;
      for (var i = 0; i < x.length; i++) {
        if (!_deepValueEqual(e, x[i], y[i], visited)) return false;
      }
      return true;
    case kSlice:
      final x = a as Slice, y = b as Slice;
      if (x.isNil != y.isNil) return false;
      if (x.length != y.length) return false;
      if (x.length == 0) return true;
      if (!visited.add((x, y, t))) return true;
      final e = t.$elem!;
      for (var i = 0; i < x.length; i++) {
        if (!_deepValueEqual(e, x[i], y[i], visited)) return false;
      }
      return true;
    case kInterface:
      if (a == null || b == null) return a == null && b == null;
      final ta = rtypeOf(a), tb = rtypeOf(b);
      if (!identical(ta, tb)) return false;
      return _deepValueEqual(ta!, $repOf(a), $repOf(b), visited);
    case kPointer:
      if (identical(a, b) || a == b) return true;
      if (a == null || b == null) return false;
      if (!visited.add((a, b, t))) return true;
      final e = t.$elem!;
      if (e.$isValueKind) return _deepValueEqual(e, a, b, visited);
      return _deepValueEqual(e, (a as Ptr).value, (b as Ptr).value, visited);
    case kStruct:
      if (t.$opaque) return a == b;
      for (final f in t.$fields) {
        if (!_deepValueEqual(
          f.type,
          f.get!(a as Object),
          f.get!(b as Object),
          visited,
        ))
          return false;
      }
      return true;
    case kMap:
      final x = a as GoMap, y = b as GoMap;
      if (x.isNil != y.isNil) return false;
      if (x.length != y.length) return false;
      if (identical(x, y)) return true;
      if (!visited.add((x, y, t))) return true;
      final e = t.$elem!;
      for (final k in x.keysSnapshot()) {
        final (v2, ok) = y.lookup(k);
        if (!ok || !_deepValueEqual(e, x[k], v2, visited)) return false;
      }
      return true;
    case kFunc:
      return a == null && b == null;
    case kFloat32 || kFloat64:
      return (a as Golang.FloatBase).toDouble() ==
          (b as Golang.FloatBase).toDouble();
  }
  return a == b;
}
