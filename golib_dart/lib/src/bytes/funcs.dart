part of '../../bytes.dart';

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

/// `bytes.TrimRight(s, cutset)`: tira do fim os bytes (cutset ASCII) ou
/// runas de cutset; ao contrário do `TrimLeft`, vazio não vira nil.
_Bytes trimRight(_Bytes s, Golang.String cutset) {
  if (s.length == 0 || cutset.length == 0) return s;
  final set = cutset.runes().toSet();
  var ascii = true;
  for (var i = 0; i < cutset.length; i++) {
    if (cutset[i] >= 0x80) ascii = false;
  }
  while (s.length > 0) {
    var (r, n) = (s[s.length - 1].toInt(), 1);
    if (r >= 0x80) {
      if (ascii) break;
      (r, n) = decodeLastRune(_str(s), s.length);
    }
    if (!set.contains(r)) break;
    s = s.slice(0, s.length - n);
  }
  return s;
}

/// `bytes.LastIndexByte(s, c)`: último índice de c em s, ou -1.
Golang.Int lastIndexByte(_Bytes s, Golang.Uint8 c) {
  for (var i = s.length - 1; i >= 0; i--) {
    if (s[i] == c) return Golang.Int(i);
  }
  return Golang.Int(-1);
}
