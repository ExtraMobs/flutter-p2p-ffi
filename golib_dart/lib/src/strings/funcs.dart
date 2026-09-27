part of '../../strings.dart';

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);

/// `strings.Index(s, substr)`: primeiro índice (em bytes) de substr, ou -1.
// ponytail: busca ingênua O(n·m); Rabin-Karp/IndexByte do Go se pesar.
Golang.Int index(Golang.String s, Golang.String substr) {
  final n = s.length, m = substr.length;
  outer:
  for (var i = 0; i + m <= n; i++) {
    for (var j = 0; j < m; j++) {
      if (s[i + j] != substr[j]) continue outer;
    }
    return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.Contains(s, substr)`.
bool contains(Golang.String s, Golang.String substr) =>
    index(s, substr) >= Golang.Int(0);

/// `strings.HasPrefix(s, prefix)`.
bool hasPrefix(Golang.String s, Golang.String prefix) =>
    s.length >= prefix.length && s.slice(0, prefix.length) == prefix;

/// `strings.HasSuffix(s, suffix)`.
bool hasSuffix(Golang.String s, Golang.String suffix) =>
    s.length >= suffix.length && s.slice(s.length - suffix.length) == suffix;

/// `strings.IndexByte(s, c)`: primeiro índice do byte c, ou -1.
Golang.Int indexByte(Golang.String s, Golang.Uint8 c) {
  final b = c.toInt();
  for (var i = 0; i < s.length; i++) {
    if (s[i] == b) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.LastIndex(s, substr)`: último índice (em bytes), ou -1.
Golang.Int lastIndex(Golang.String s, Golang.String substr) {
  final n = s.length, m = substr.length;
  outer:
  for (var i = n - m; i >= 0; i--) {
    for (var j = 0; j < m; j++) {
      if (s[i + j] != substr[j]) continue outer;
    }
    return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.Count(s, substr)`: ocorrências sem sobreposição; substr vazio
/// conta runas + 1.
Golang.Int count(Golang.String s, Golang.String substr) {
  if (substr.length == 0) return Golang.Int(s.runes().length + 1);
  var n = 0;
  for (var rest = s; ;) {
    final i = index(rest, substr).toInt();
    if (i < 0) return Golang.Int(n);
    n++;
    rest = rest.slice(i + substr.length);
  }
}

/// `strings.ContainsRune(s, r)`: rune inválida nunca está; `RuneError`
/// casa também bytes UTF-8 inválidos (como o range do Go).
bool containsRune(Golang.String s, Golang.Rune r) {
  final v = r.toInt();
  if (v == 0xfffd) {
    for (var i = 0; i < s.length;) {
      final (c, n) = s.decodeRune(i);
      if (c == 0xfffd) return true;
      i += n;
    }
    return false;
  }
  if (v < 0 || v > 0x10ffff || (v >= 0xd800 && v <= 0xdfff)) return false;
  return index(s, Golang.String.fromCodePoint(v)) >= Golang.Int(0);
}

/// `strings.TrimPrefix(s, prefix)`.
Golang.String trimPrefix(Golang.String s, Golang.String prefix) =>
    hasPrefix(s, prefix) ? s.slice(prefix.length) : s;

/// `strings.TrimSuffix(s, suffix)`.
Golang.String trimSuffix(Golang.String s, Golang.String suffix) =>
    hasSuffix(s, suffix) ? s.slice(0, s.length - suffix.length) : s;

/// `strings.TrimLeftFunc(s, f)`.
Golang.String trimLeftFunc(Golang.String s, bool Function(Golang.Rune)? f) {
  for (var i = 0; i < s.length;) {
    final (r, n) = s.decodeRune(i);
    if (!f!(Golang.Rune(r))) return s.slice(i);
    i += n;
  }
  return Golang.String();
}

/// `strings.TrimRightFunc(s, f)`: decodifica de trás para frente
/// (`utf8.DecodeLastRuneInString`).
Golang.String trimRightFunc(Golang.String s, bool Function(Golang.Rune)? f) {
  for (var i = s.length; i > 0;) {
    final (r, n) = decodeLastRune(s, i);
    i -= n;
    if (!f!(Golang.Rune(r))) return s.slice(0, i + s.decodeRune(i).$2);
  }
  return s.slice(0, 0);
}

/// `strings.TrimFunc(s, f)`.
Golang.String trimFunc(Golang.String s, bool Function(Golang.Rune)? f) =>
    trimRightFunc(trimLeftFunc(s, f), f);

/// `strings.Join(elems, sep)`.
// ponytail: concatenação repetida O(n²) em bytes; buffer único se pesar.
Golang.String join(Slice<Golang.String> elems, Golang.String sep) {
  if (elems.length == 0) return Golang.String();
  var out = elems[0];
  for (var i = 1; i < elems.length; i++) {
    out = out + sep + elems[i];
  }
  return out;
}

/// `strings.Split(s, sep)`.
Slice<Golang.String> split(Golang.String s, Golang.String sep) =>
    _genSplit(s, sep, 0, -1);

/// `strings.SplitN(s, sep, n)`.
Slice<Golang.String> splitN(Golang.String s, Golang.String sep, Golang.Int n) =>
    _genSplit(s, sep, 0, n.toInt());

Slice<Golang.String> _genSplit(
  Golang.String s,
  Golang.String sep,
  int sepSave,
  int n,
) {
  if (n == 0) return Slice.nil(_strElem);
  if (sep.length == 0) return _explode(s, n);
  if (n < 0) n = count(s, sep).toInt() + 1;
  if (n > s.length + 1) n = s.length + 1;
  // make([]string, n) e a[:i+1]: o cap do resultado é o do Go.
  final a = Slice<Golang.String>.make(n, n, _strElem);
  var i = 0;
  for (; i < n - 1; i++) {
    final m = index(s, sep).toInt();
    if (m < 0) break;
    a[i] = s.slice(0, m + sepSave);
    s = s.slice(m + sep.length);
  }
  a[i] = s;
  return a.slice(0, i + 1);
}

Slice<Golang.String> _explode(Golang.String s, int n) {
  final l = s.runes().length;
  if (n < 0 || n > l) n = l;
  final a = Slice<Golang.String>.make(n, n, _strElem);
  for (var i = 0; i < n - 1; i++) {
    final size = s.decodeRune(0).$2;
    a[i] = s.slice(0, size);
    s = s.slice(size);
  }
  if (n > 0) a[n - 1] = s;
  return a;
}
