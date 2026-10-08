/// Shim do pacote Go `slices` (porta de `slices/slices.go` e `sort.go` do Go
/// 1.26.5), na forma das genéricas que o g2d gera: um descritor `go.Elem`
/// por parâmetro de tipo antes dos argumentos (`contains<S, E>($S, $E, s,
/// v)`), `S extends Slice<E>` (core type `~[]E`) reembrulhado por
/// `$S.rewrapOf` (slice nomeado), `cmp.Ordered` como `Golang.GoOrdered`.
///
/// ❌ As funções sobre `iter.Seq` (`All`, `Values`, `Backward`, `Collect`,
/// `AppendSeq`, `Sorted*`, `Chunk`) esperam o shim `iter`
/// (TODO/P1-shim-iter.md): `Unsupported shim-simbolo`.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'src/sort/pdqsort.dart';

part 'src/slices/sort.dart';

Never _panic(String s) => throw Panic(Golang.String.fromDart(s));

final _zero = Golang.Int(0);

/// Cópia dos elementos (struct/array por valor copiados): o valor que o Go
/// leria antes de escrever por cima, quando dois argumentos dividem o array.
Slice<E> _snapshot<E>(Slice<E> s, Elem<E> e) =>
    Slice.of([for (final x in s.items) e.copyOf(x)], e);

/// `slices.Equal(s1, s2)`.
bool equal<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s1, S s2) {
  if (s1.length != s2.length) return false;
  for (var i = 0; i < s1.length; i++) {
    if (s1[i] != s2[i]) return false;
  }
  return true;
}

/// `slices.EqualFunc(s1, s2, eq)`.
bool equalFunc<S1 extends Slice<E1>, S2 extends Slice<E2>, E1, E2>(
  Elem<S1> $S1,
  Elem<S2> $S2,
  Elem<E1> $E1,
  Elem<E2> $E2,
  S1 s1,
  S2 s2,
  bool Function(E1, E2)? eq,
) {
  if (s1.length != s2.length) return false;
  for (var i = 0; i < s1.length; i++) {
    if (!eq!($E1.copyOf(s1[i]), $E2.copyOf(s2[i]))) return false;
  }
  return true;
}

/// `slices.Compare(s1, s2)` (`cmp.Compare`: NaN antes de tudo).
Golang.Int compare<S extends Slice<E>, E extends Golang.GoOrdered<E>>(
  Elem<S> $S,
  Elem<E> $E,
  S s1,
  S s2,
) {
  for (var i = 0; i < s1.length; i++) {
    if (i >= s2.length) return Golang.Int(1);
    final c = _cmpCompare(s1[i], s2[i]);
    if (c != 0) return Golang.Int(c);
  }
  return Golang.Int(s1.length < s2.length ? -1 : 0);
}

/// `slices.CompareFunc(s1, s2, cmp)`.
Golang.Int compareFunc<S1 extends Slice<E1>, S2 extends Slice<E2>, E1, E2>(
  Elem<S1> $S1,
  Elem<S2> $S2,
  Elem<E1> $E1,
  Elem<E2> $E2,
  S1 s1,
  S2 s2,
  Golang.Int Function(E1, E2)? cmp,
) {
  for (var i = 0; i < s1.length; i++) {
    if (i >= s2.length) return Golang.Int(1);
    final c = cmp!($E1.copyOf(s1[i]), $E2.copyOf(s2[i]));
    if (c != _zero) return c;
  }
  return Golang.Int(s1.length < s2.length ? -1 : 0);
}

/// `slices.Index(s, v)`.
Golang.Int index<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s, E v) {
  for (var i = 0; i < s.length; i++) {
    if (v == s[i]) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `slices.IndexFunc(s, f)`.
Golang.Int indexFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  bool Function(E)? f,
) {
  for (var i = 0; i < s.length; i++) {
    if (f!($E.copyOf(s[i]))) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `slices.Contains(s, v)`.
bool contains<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s, E v) =>
    index($S, $E, s, v) >= _zero;

/// `slices.ContainsFunc(s, f)`.
bool containsFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  bool Function(E)? f,
) => indexFunc($S, $E, s, f) >= _zero;

/// `slices.Insert(s, i, v...)`: v é lido antes de qualquer escrita (o Go
/// trata a sobreposição com `s`; aqui, uma cópia).
S insert<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  Golang.Int i$,
  Slice<E> v,
) {
  final i = i$.toIndex();
  s.slice(i); // checagem de limites
  final m = v.length, n = s.length;
  if (m == 0) return s;
  if (i == n) return $S.rewrapOf(s.appendSlice(v));
  if (n + m > s.capacity) {
    final s2 = s.slice(0, i).appendSlice(Slice.make(n + m - i, n + m - i, $E));
    s2.slice(i).copyFrom(v);
    s2.slice(i + m).copyFrom(s.slice(i));
    return $S.rewrapOf(s2);
  }
  final vv = _snapshot(v, $E);
  final r = s.slice(0, n + m);
  r.slice(i + m).copyFrom(r.slice(i, n));
  r.slice(i).copyFrom(vv);
  return $S.rewrapOf(r);
}

/// `slices.Delete(s, i, j)`: zera os `j-i` elementos que sobram no fim.
S delete$<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  Golang.Int i$,
  Golang.Int j$,
) {
  final i = i$.toIndex(), j = j$.toIndex();
  s.slice(i, j, s.length); // checagem de limites
  if (i == j) return s;
  final oldlen = s.length;
  final r = s.slice(0, i).appendSlice(s.slice(j));
  r.slice(r.length, oldlen).clear();
  return $S.rewrapOf(r);
}

/// `slices.DeleteFunc(s, del)`.
S deleteFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  bool Function(E)? del,
) {
  var i = indexFunc($S, $E, s, del).toInt();
  if (i == -1) return s;
  for (var j = i + 1; j < s.length; j++) {
    final v = $E.copyOf(s[j]);
    if (!del!(v)) s[i++] = v;
  }
  s.slice(i).clear();
  return $S.rewrapOf(s.slice(0, i));
}

/// `slices.Replace(s, i, j, v...)`: v e `s[j:]` são lidos antes de qualquer
/// escrita, como o Go garante com a análise de sobreposição.
S replace<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  Golang.Int i$,
  Golang.Int j$,
  Slice<E> v,
) {
  final i = i$.toIndex(), j = j$.toIndex();
  s.slice(i, j); // checagem de limites
  if (i == j) return insert($S, $E, s, i$, v);
  if (j == s.length) {
    final s2 = s.slice(0, i).appendSlice(v);
    if (s2.length < s.length) s.slice(s2.length).clear();
    return $S.rewrapOf(s2);
  }
  final tot = i + v.length + s.length - j;
  if (tot > s.capacity) {
    final s2 = s.slice(0, i).appendSlice(Slice.make(tot - i, tot - i, $E));
    s2.slice(i).copyFrom(v);
    s2.slice(i + v.length).copyFrom(s.slice(j));
    return $S.rewrapOf(s2);
  }
  final vv = _snapshot(v, $E), tail = _snapshot(s.slice(j), $E);
  final r = s.slice(0, tot);
  r.slice(i).copyFrom(vv);
  r.slice(i + vv.length).copyFrom(tail);
  if (tot < s.length) s.slice(tot).clear();
  return $S.rewrapOf(r);
}

/// `slices.Clone(s)`: nil continua nil; o cap é o do `append(S{}, s...)`.
S clone<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s) {
  if (s.isNil) return $S.zero();
  return $S.rewrapOf(Slice.of(<E>[], $E).appendSlice(s));
}

/// `slices.Compact(s)`.
S compact<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s) =>
    _compact<S, E>($S, s, (a, b) => a == b);

/// `slices.CompactFunc(s, eq)`.
S compactFunc<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S s,
  bool Function(E, E)? eq,
) => _compact<S, E>($S, s, (a, b) => eq!($E.copyOf(a), $E.copyOf(b)));

S _compact<S extends Slice<E>, E>(Elem<S> $S, S s, bool Function(E, E) eq) {
  if (s.length < 2) return s;
  for (var k = 1; k < s.length; k++) {
    if (eq(s[k], s[k - 1])) {
      final s2 = s.slice(k);
      for (var k2 = 1; k2 < s2.length; k2++) {
        if (!eq(s2[k2], s2[k2 - 1])) {
          s[k] = s.elem.copyOf(s2[k2]);
          k++;
        }
      }
      s.slice(k).clear();
      return $S.rewrapOf(s.slice(0, k));
    }
  }
  return s;
}

/// `slices.Grow(s, n)`.
S grow<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s, Golang.Int n$) {
  var n = n$.toInt();
  if (n < 0) _panic('cannot be negative');
  n -= s.capacity - s.length;
  if (n > 0) {
    return $S.rewrapOf(
      s
          .slice(0, s.capacity)
          .appendSlice(Slice.make(n, n, $E))
          .slice(0, s.length),
    );
  }
  return s;
}

/// `slices.Clip(s)`.
S clip<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s) =>
    $S.rewrapOf(s.slice(0, s.length, s.length));

/// `slices.Reverse(s)`.
void reverse<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, S s) {
  for (var i = 0, j = s.length - 1; i < j; i++, j--) {
    swapElems(s, i, j);
  }
}

/// `slices.Concat(slices...)`: o cap é o do `Grow[S](nil, size)`.
// ponytail: sem o pânico `len out of range` (soma de len acima de 2^63).
S concat<S extends Slice<E>, E>(Elem<S> $S, Elem<E> $E, Slice<S> slices) {
  var size = 0;
  for (final s in slices.items) {
    size += s.length;
  }
  Slice<E> out = grow($S, $E, $S.zero(), Golang.Int(size));
  for (final s in slices.items) {
    out = out.appendSlice(s);
  }
  return $S.rewrapOf(out);
}

/// `slices.Repeat(x, count)`.
S repeat<S extends Slice<E>, E>(
  Elem<S> $S,
  Elem<E> $E,
  S x,
  Golang.Int count$,
) {
  final count = count$.toInt();
  if (count < 0) _panic('cannot be negative');
  if (BigInt.from(x.length) * BigInt.from(count) >
      BigInt.parse('9223372036854775807')) {
    _panic('the result of (len(x) * count) overflows');
  }
  final total = x.length * count;
  final out = Slice.make(total, total, $E);
  var n = out.copyFrom(x);
  while (n < total) {
    n += out.slice(n).copyFrom(out.slice(0, n));
  }
  return $S.rewrapOf(out);
}
