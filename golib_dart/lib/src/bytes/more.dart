part of '../../bytes.dart';

/// `bytes.TrimPrefix(s, prefix)`.
_Bytes trimPrefix(_Bytes s, _Bytes prefix) =>
    hasPrefix(s, prefix) ? s.slice(prefix.length) : s;

/// `bytes.TrimSuffix(s, suffix)`.
_Bytes trimSuffix(_Bytes s, _Bytes suffix) =>
    hasSuffix(s, suffix) ? s.slice(0, s.length - suffix.length) : s;

/// `bytes.Trim(s, cutset)`.
_Bytes trim(_Bytes s, Golang.String cutset) =>
    trimLeft(trimRight(s, cutset), cutset);

/// `bytes.LastIndex(s, sep)`: último índice de sep em s, ou -1; sep vazio
/// casa no fim de s.
// ponytail: busca ingênua O(n·m); Rabin-Karp do Go se pesar.
Golang.Int lastIndex(_Bytes s, _Bytes sep) {
  final n = s.length, m = sep.length;
  outer:
  for (var i = n - m; i >= 0; i--) {
    for (var j = 0; j < m; j++) {
      if (s[i + j] != sep[j]) continue outer;
    }
    return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `bytes.Contains(b, subslice)`.
bool contains(_Bytes b, _Bytes subslice) => index(b, subslice) >= Golang.Int(0);

/// `bytes.IndexAny(s, chars)`: primeiro índice de qualquer code point de
/// chars em s (interpretado como UTF-8), ou -1; chars vazio nunca casa.
// ponytail: sem os atalhos ASCII/1-byte do Go, só desempenho.
Golang.Int indexAny(_Bytes s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  final set = chars.runes().toSet();
  final str = _str(s);
  var i = 0;
  while (i < s.length) {
    final (r, n) = str.decodeRune(i);
    if (set.contains(r)) return Golang.Int(i);
    i += n;
  }
  return Golang.Int(-1);
}

/// `bytes.ContainsAny(b, chars)`.
bool containsAny(_Bytes b, Golang.String chars) =>
    indexAny(b, chars) >= Golang.Int(0);

/// `bytes.ContainsRune(b, r)`: rune inválida nunca está; `RuneError` casa
/// também bytes UTF-8 inválidos (como o range do Go).
bool containsRune(_Bytes b, Golang.Rune r) {
  final v = r.toInt();
  if (v == 0xfffd) {
    final str = _str(b);
    for (var i = 0; i < b.length;) {
      final (c, n) = str.decodeRune(i);
      if (c == 0xfffd) return true;
      i += n;
    }
    return false;
  }
  if (v < 0 || v > 0x10ffff || (v >= 0xd800 && v <= 0xdfff)) return false;
  return index(b, _bytesOf(Golang.String.fromCodePoint(v))) >= Golang.Int(0);
}

/// `bytes.Clone(b)`: `nil` continua `nil`; senão, cópia independente.
_Bytes clone(_Bytes b) => b.isNil
    ? _nilBytes()
    : Slice.of(<Golang.Uint8>[], _byteElem).appendSlice(b);

/// `bytes.Cut(s, sep)`: `after` é `nil` (não vazio) quando sep não aparece.
(_Bytes, _Bytes, bool) cut(_Bytes s, _Bytes sep) {
  final i = index(s, sep).toInt();
  if (i >= 0) return (s.slice(0, i), s.slice(i + sep.length), true);
  return (s, _nilBytes(), false);
}

/// `bytes.CutPrefix(s, prefix)`.
(_Bytes, bool) cutPrefix(_Bytes s, _Bytes prefix) =>
    hasPrefix(s, prefix) ? (s.slice(prefix.length), true) : (s, false);

/// `bytes.CutSuffix(s, suffix)`.
(_Bytes, bool) cutSuffix(_Bytes s, _Bytes suffix) => hasSuffix(s, suffix)
    ? (s.slice(0, s.length - suffix.length), true)
    : (s, false);

/// `bytes.Join(s, sep)`: `s` vazio dá `[]byte{}` (não nil); um elemento é
/// cópia dele.
_Bytes join(Slice<_Bytes> s, _Bytes sep) {
  if (s.length == 0) return Slice.of(<Golang.Uint8>[], _byteElem);
  if (s.length == 1) return _nilBytes().appendSlice(s[0]);
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    n += s[i].length;
  }
  n += sep.length * (s.length - 1);
  final b = Slice<Golang.Uint8>.make(n, n, _byteElem);
  var bp = b.slice(0, s[0].length).copyFrom(s[0]);
  for (var i = 1; i < s.length; i++) {
    bp += b.slice(bp, bp + sep.length).copyFrom(sep);
    bp += b.slice(bp, bp + s[i].length).copyFrom(s[i]);
  }
  return b;
}

/// `bytes.Repeat(b, count)`: pânico com contagem negativa, como o Go; sem
/// o cache de blocos de 8KB (só desempenho). `count == 0` dá `[]byte{}`.
_Bytes repeat(_Bytes b, Golang.Int countArg) {
  final n = countArg.toInt();
  if (n == 0) return Slice.of(<Golang.Uint8>[], _byteElem);
  if (n < 0) {
    throw Panic(Golang.String.fromDart('bytes: negative Repeat count'));
  }
  if (b.length == 0) return Slice.of(<Golang.Uint8>[], _byteElem);
  final total = b.length * n;
  final out = Slice<Golang.Uint8>.make(total, total, _byteElem);
  for (var i = 0; i < n; i++) {
    out.slice(i * b.length, (i + 1) * b.length).copyFrom(b);
  }
  return out;
}

/// `bytes.SplitN(s, sep, n)`.
Slice<_Bytes> splitN(_Bytes s, _Bytes sep, Golang.Int nArg) {
  var n = nArg.toInt();
  if (n == 0) return Slice.nil(_bytesElem);
  if (sep.length == 0) return _explode(s, n);
  if (n < 0) n = count(s, sep).toInt() + 1;
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

/// `bytes.Replace(s, old, new, n)`.
_Bytes replace(_Bytes s, _Bytes old, _Bytes new_, Golang.Int nArg) {
  var n = nArg.toInt();
  var m = 0;
  if (n != 0) m = count(s, old).toInt();
  if (m == 0) return _nilBytes().appendSlice(s);
  if (n < 0 || m < n) n = m;
  final total = s.length + n * (new_.length - old.length);
  final t = Slice<Golang.Uint8>.make(total, total, _byteElem);
  var w = 0, start = 0;
  for (var i = 0; i < n; i++) {
    var j = start;
    if (old.length == 0) {
      if (i > 0) {
        final (_, wid) = _str(s.slice(start)).decodeRune(0);
        j += wid;
      }
    } else {
      j += index(s.slice(start), old).toInt();
    }
    w += t.slice(w).copyFrom(s.slice(start, j));
    w += t.slice(w).copyFrom(new_);
    start = j + old.length;
  }
  w += t.slice(w).copyFrom(s.slice(start));
  return t.slice(0, w);
}

/// `bytes.ReplaceAll(s, old, new)`.
_Bytes replaceAll(_Bytes s, _Bytes old, _Bytes new_) =>
    replace(s, old, new_, Golang.Int(-1));

/// `bytes.Map(mapping, s)`: porta de `bytes.Map` do Go 1.26 (bem mais
/// simples que `strings.Map`: sempre reconstrói, sem preservar bytes
/// inválidos que a função mantém idênticos — vira U+FFFD de 3 bytes).
_Bytes map(Golang.Rune Function(Golang.Rune) mapping, _Bytes s) {
  var out = Slice<Golang.Uint8>.make(0, s.length, _byteElem);
  final str = _str(s);
  var i = 0;
  while (i < s.length) {
    final (r0, wid) = str.decodeRune(i);
    final r = mapping(Golang.Rune(r0)).toInt();
    if (r >= 0) {
      final enc = Golang.String.fromCodePoint(r).toBytes();
      out = out.append([for (final b in enc) Golang.Uint8(b)]);
    }
    i += wid;
  }
  return out;
}
