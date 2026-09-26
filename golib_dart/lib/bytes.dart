/// Shim do pacote Go `bytes` (só as funções que o grafo pede primeiro;
/// o resto em `TODO/P0-shim-bytes.md`).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

typedef _Bytes = Slice<Golang.Uint8>;

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);
_Bytes _nilBytes() => Slice.nil(_byteElem);
const _bytesElem = Elem<_Bytes>(24, _nilBytes, pointers: true);

// Os bytes da janela como string Go (para decodificar UTF-8 como o Go).
Golang.String _str(_Bytes b) => Golang.String.fromBytes(
  Uint8List.fromList([for (var i = 0; i < b.length; i++) b[i].toInt()]),
);

/// `bytes.Equal(a, b)`: mesmo tamanho e bytes (nil e vazio são iguais).
bool equal(_Bytes a, _Bytes b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// `bytes.Compare(a, b)`: -1, 0 ou +1 pela ordem lexicográfica dos bytes.
Golang.Int compare(_Bytes a, _Bytes b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final c = a[i].toInt() - b[i].toInt();
    if (c != 0) return Golang.Int(c < 0 ? -1 : 1);
  }
  return Golang.Int(a.length.compareTo(b.length));
}

/// `bytes.IndexByte(b, c)`: primeiro índice de c em b, ou -1.
Golang.Int indexByte(_Bytes b, Golang.Uint8 c) {
  for (var i = 0; i < b.length; i++) {
    if (b[i] == c) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `bytes.HasPrefix(s, prefix)`.
bool hasPrefix(_Bytes s, _Bytes prefix) =>
    s.length >= prefix.length && equal(s.slice(0, prefix.length), prefix);

/// `bytes.HasSuffix(s, suffix)`.
bool hasSuffix(_Bytes s, _Bytes suffix) =>
    s.length >= suffix.length &&
    equal(s.slice(s.length - suffix.length), suffix);

/// `bytes.Index(s, sep)`: primeiro índice de sep em s, ou -1.
// ponytail: busca ingênua O(n·m); Rabin-Karp do Go se pesar.
Golang.Int index(_Bytes s, _Bytes sep) {
  final n = s.length, m = sep.length;
  outer:
  for (var i = 0; i + m <= n; i++) {
    for (var j = 0; j < m; j++) {
      if (s[i + j] != sep[j]) continue outer;
    }
    return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `bytes.Count(s, sep)`: ocorrências sem sobreposição; sep vazio conta
/// runas + 1.
Golang.Int count(_Bytes s, _Bytes sep) {
  if (sep.length == 0) return Golang.Int(_str(s).runes().length + 1);
  var n = 0;
  for (var rest = s; ;) {
    final i = index(rest, sep).toInt();
    if (i < 0) return Golang.Int(n);
    n++;
    rest = rest.slice(i + sep.length);
  }
}

/// `bytes.Split(s, sep)`: subslices de s com cap limitado ao pedaço
/// (`s[:m:m]`), como no Go.
Slice<_Bytes> split(_Bytes s, _Bytes sep) {
  var n = -1;
  if (sep.length == 0) return _explode(s, n);
  n = count(s, sep).toInt() + 1;
  if (n > s.length + 1) n = s.length + 1;
  final a = Slice<_Bytes>.make(n, n, _bytesElem);
  var i = 0;
  for (; i < n - 1; i++) {
    final m = index(s, sep).toInt();
    if (m < 0) break;
    a[i] = s.slice(0, m, m);
    s = s.slice(m + sep.length);
  }
  a[i] = s;
  return a.slice(0, i + 1);
}

Slice<_Bytes> _explode(_Bytes s, int n) {
  if (n <= 0 || n > s.length) n = s.length;
  final a = Slice<_Bytes>.make(n, n, _bytesElem);
  var na = 0;
  while (s.length > 0) {
    if (na + 1 >= n) {
      a[na++] = s;
      break;
    }
    final size = _str(s).decodeRune(0).$2;
    a[na++] = s.slice(0, size, size);
    s = s.slice(size);
  }
  return a.slice(0, na);
}

/// `bytes.TrimLeft(s, cutset)`: tira do início os bytes (cutset ASCII) ou
/// runas (senão) de cutset; resultado vazio é nil, como no Go.
_Bytes trimLeft(_Bytes s, Golang.String cutset) {
  if (s.length == 0) return _nilBytes();
  if (cutset.length == 0) return s;
  var ascii = true;
  for (var i = 0; i < cutset.length; i++) {
    if (cutset[i] >= 0x80) ascii = false;
  }
  final set = cutset.runes().toSet();
  if (ascii) {
    while (s.length > 0 && set.contains(s[0].toInt())) {
      s = s.slice(1);
    }
  } else {
    while (s.length > 0) {
      final (r, n) = _str(s).decodeRune(0);
      if (!set.contains(r)) break;
      s = s.slice(n);
    }
  }
  return s.length == 0 ? _nilBytes() : s;
}
