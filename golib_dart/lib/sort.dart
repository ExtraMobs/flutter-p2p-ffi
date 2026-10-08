/// Shim do pacote Go `sort`.
///
/// Porta exata do pdqsort e do stable do Go 1.26 (`sort/zsortinterface.go`;
/// `slices/zsortordered.go` e `sort/zsortfunc.go` saem do mesmo gerador):
/// mesmas chamadas a Less/Swap, na mesma ordem, e o mesmo resultado para
/// elementos iguais. Índices em `int` do Dart (tamanhos < 2^53).
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

import 'src/sort/pdqsort.dart';

/// `sort.Interface`.
abstract interface class Interface {
  Golang.Int len();
  bool less(Golang.Int i, Golang.Int j);
  void swap(Golang.Int i, Golang.Int j);
}

/// `sort.Sort(data)`.
void sort(Interface? data) {
  final n = data!.len().toInt();
  if (n <= 1) return;
  Pdq(_iLess(data), _iSwap(data)).pdqsort(0, n, n.bitLength);
}

/// `sort.Stable(data)`.
void stable(Interface? data) =>
    Pdq(_iLess(data!), _iSwap(data)).stable(data.len().toInt());

/// `sort.IsSorted(data)`: compara de trás para frente, como o Go.
bool isSorted(Interface? data) {
  for (var i = data!.len().toInt() - 1; i > 0; i--) {
    if (data.less(Golang.Int(i), Golang.Int(i - 1))) return false;
  }
  return true;
}

/// `sort.Slice(x, less)`: x tem de ser um slice.
void slice$(Object? x, bool Function(Golang.Int, Golang.Int)? less) {
  final s = x as Slice;
  Pdq(_fLess(less!), _sSwap(s)).pdqsort(0, s.length, s.length.bitLength);
}

/// `sort.SliceStable(x, less)`.
void sliceStable(Object? x, bool Function(Golang.Int, Golang.Int)? less) {
  final s = x as Slice;
  Pdq(_fLess(less!), _sSwap(s)).stable(s.length);
}

/// `sort.Ints(x)` (`slices.Sort`).
void ints(Slice<Golang.Int> x) => _ordered(x, (a, b) => a < b);

/// `sort.Strings(x)` (`slices.Sort`).
void strings(Slice<Golang.String> x) => _ordered(x, (a, b) => a < b);

/// `sort.Float64s(x)` (`slices.Sort`): NaN antes de tudo (`cmp.Less`).
void float64s(Slice<Golang.Float64> x) => _ordered(x, (a, b) {
  final da = a.toDouble(), db = b.toDouble();
  return (da.isNaN && !db.isNaN) || da < db;
});

/// `sort.Search(n, f)`: menor i em [0, n) com f(i) verdadeiro (f monótona),
/// ou n. Mesma bisseção do Go: chama f nos mesmos índices, na mesma ordem.
Golang.Int search(Golang.Int n, bool Function(Golang.Int)? f) {
  var i = Golang.Int(), j = n;
  while (i < j) {
    final h = Golang.Int.from(Golang.Uint.from(i + j) >> 1);
    if (!f!(h)) {
      i = h + Golang.Int(1);
    } else {
      j = h;
    }
  }
  return i;
}

typedef _Less = PdqLess;
typedef _Swap = PdqSwap;

_Less _iLess(Interface d) =>
    (i, j) => d.less(Golang.Int(i), Golang.Int(j));
_Swap _iSwap(Interface d) =>
    (i, j) => d.swap(Golang.Int(i), Golang.Int(j));
_Less _fLess(bool Function(Golang.Int, Golang.Int) f) =>
    (i, j) => f(Golang.Int(i), Golang.Int(j));
_Swap _sSwap<T>(Slice<T> s) =>
    (i, j) => swapElems(s, i, j);

void _ordered<T>(Slice<T> x, bool Function(T, T) less) => Pdq(
  (i, j) => less(x[i], x[j]),
  _sSwap(x),
).pdqsort(0, x.length, x.length.bitLength);
