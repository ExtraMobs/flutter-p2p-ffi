part of '../../slices.dart';

// `slices/sort.go`: o pdqsort e o stable dos `zsortordered.go`/
// `zsortanyfunc.go` são o mesmo algoritmo do `sort` (mesmo gerador), então
// as mesmas chamadas a `cmp`, na mesma ordem ([Pdq]).

bool _isNaN<E>(E x) => x != x;

/// `cmp.Less`: NaN antes de qualquer outro valor.
bool _cmpLess<E extends Golang.GoOrdered<E>>(E x, E y) =>
    (_isNaN(x) && !_isNaN(y)) || x < y;

/// `cmp.Compare`.
int _cmpCompare<E extends Golang.GoOrdered<E>>(E x, E y) {
  final xNaN = _isNaN(x), yNaN = _isNaN(y);
  if (xNaN) return yNaN ? 0 : -1;
  if (yNaN) return 1;
  if (x < y) return -1;
  if (x > y) return 1;
  return 0;
}

void _pdq<E>(Slice<E> x, bool Function(E, E) less) => Pdq(
  (i, j) => less(x[i], x[j]),
  (i, j) => swapElems(x, i, j),
).pdqsort(0, x.length, x.length.bitLength);

PdqLess _cmpLessIdx<E>(Slice<E> x, Golang.Int Function(E, E)? cmp) =>
    (i, j) => cmp!(x.elem.copyOf(x[i]), x.elem.copyOf(x[j])) < _zero;

/// `slices.Sort(x)`.
void sort<S extends Slice<E>, E extends Golang.GoOrdered<E>>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
) => _pdq<E>(x, _cmpLess);

/// `slices.SortFunc(x, cmp)`.
void sortFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
  Golang.Int Function(E, E)? cmp,
) => Pdq(
  _cmpLessIdx(x, cmp),
  (i, j) => swapElems(x, i, j),
).pdqsort(0, x.length, x.length.bitLength);

/// `slices.SortStableFunc(x, cmp)`.
void sortStableFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
  Golang.Int Function(E, E)? cmp,
) => Pdq(_cmpLessIdx(x, cmp), (i, j) => swapElems(x, i, j)).stable(x.length);

/// `slices.IsSorted(x)`.
bool isSorted<S extends Slice<E>, E extends Golang.GoOrdered<E>>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
) {
  for (var i = x.length - 1; i > 0; i--) {
    if (_cmpLess(x[i], x[i - 1])) return false;
  }
  return true;
}

/// `slices.IsSortedFunc(x, cmp)`.
bool isSortedFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
  Golang.Int Function(E, E)? cmp,
) {
  final less = _cmpLessIdx(x, cmp);
  for (var i = x.length - 1; i > 0; i--) {
    if (less(i, i - 1)) return false;
  }
  return true;
}

/// `slices.Min(x)`: o `min` do Go (NaN vence; -0 < +0).
E min<S extends Slice<E>, E extends Golang.GoOrdered<E>>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
) {
  if (x.length < 1) _panic('slices.Min: empty list');
  final xs = x.items.toList();
  return xs[0] is Golang.FloatBase
      ? minFloat(xs, (v) => (v as Golang.FloatBase).toDouble())
      : minOf(xs, (a, b) => a < b);
}

/// `slices.Max(x)`.
E max<S extends Slice<E>, E extends Golang.GoOrdered<E>>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
) {
  if (x.length < 1) _panic('slices.Max: empty list');
  final xs = x.items.toList();
  return xs[0] is Golang.FloatBase
      ? maxFloat(xs, (v) => (v as Golang.FloatBase).toDouble())
      : maxOf(xs, (a, b) => a < b);
}

/// `slices.MinFunc(x, cmp)`: o primeiro mínimo.
E minFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
  Golang.Int Function(E, E)? cmp,
) {
  if (x.length < 1) _panic('slices.MinFunc: empty list');
  var m = x[0];
  for (var i = 1; i < x.length; i++) {
    if (cmp!($E.copyOf(x[i]), $E.copyOf(m)) < _zero) m = x[i];
  }
  return $E.copyOf(m);
}

/// `slices.MaxFunc(x, cmp)`: o primeiro máximo.
E maxFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
  Golang.Int Function(E, E)? cmp,
) {
  if (x.length < 1) _panic('slices.MaxFunc: empty list');
  var m = x[0];
  for (var i = 1; i < x.length; i++) {
    if (cmp!($E.copyOf(x[i]), $E.copyOf(m)) > _zero) m = x[i];
  }
  return $E.copyOf(m);
}

/// `slices.BinarySearch(x, target)`.
(Golang.Int, bool) binarySearch<
  S extends Slice<E>,
  E extends Golang.GoOrdered<E>
>(Elem<S> $S, Elem<E> $E, S x, E target) {
  final n = x.length;
  var i = 0, j = n;
  while (i < j) {
    final h = (i + j) ~/ 2;
    if (_cmpLess(x[h], target)) {
      i = h + 1;
    } else {
      j = h;
    }
  }
  return (
    Golang.Int(i),
    i < n && (x[i] == target || (_isNaN(x[i]) && _isNaN(target))),
  );
}

/// `slices.BinarySearchFunc(x, target, cmp)`.
(Golang.Int, bool) binarySearchFunc<S extends Slice<E>, E, T>(
  Elem<S> $S,
  Elem<E> $E,
  Elem<T> $T,
  S x,
  T target,
  Golang.Int Function(E, T)? cmp,
) {
  final n = x.length;
  var i = 0, j = n;
  while (i < j) {
    final h = (i + j) ~/ 2;
    if (cmp!($E.copyOf(x[h]), $T.copyOf(target)) < _zero) {
      i = h + 1;
    } else {
      j = h;
    }
  }
  return (
    Golang.Int(i),
    i < n && cmp!($E.copyOf(x[i]), $T.copyOf(target)) == _zero,
  );
}
