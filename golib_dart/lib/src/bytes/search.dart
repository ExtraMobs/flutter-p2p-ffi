part of '../../bytes.dart';

/// `bytes.Contains(b, subslice)`.
bool contains(_Bytes b, _Bytes subslice) => index(b, subslice).toInt() >= 0;

/// `bytes.LastIndex(s, sep)`: último índice de sep em s, ou -1.
Golang.Int lastIndex(_Bytes s, _Bytes sep) {
  final n = sep.length;
  if (n == 0) return Golang.Int(s.length);
  outer:
  for (var i = s.length - n; i >= 0; i--) {
    for (var j = 0; j < n; j++) {
      if (s[i + j] != sep[j]) continue outer;
    }
    return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `bytes.IndexRune(s, r)`: `RuneError` casa o primeiro UTF-8 inválido (ou
/// U+FFFD); runa inválida nunca está.
Golang.Int indexRune(_Bytes s, Golang.Rune r) {
  final v = r.toInt();
  if (v >= 0 && v < 0x80) return indexByte(s, Golang.Uint8(v));
  if (v == 0xfffd) {
    final g = _str(s);
    for (var i = 0; i < s.length;) {
      final (c, n) = g.decodeRune(i);
      if (c == 0xfffd) return Golang.Int(i);
      i += n;
    }
    return Golang.Int(-1);
  }
  if ((v < 0 || v > 0x10ffff) || (v >= 0xd800 && v <= 0xdfff)) {
    return Golang.Int(-1);
  }
  final enc = Golang.String.fromCodePoint(v).toBytes();
  return index(
    s,
    Slice.of([for (final b in enc) Golang.Uint8(b)], _byteElem),
  );
}

/// `bytes.ContainsRune(b, r)`.
bool containsRune(_Bytes b, Golang.Rune r) => indexRune(b, r).toInt() >= 0;

// Índice (em chars) de r em chars como `IndexRune(chars, r)`.
bool _inChars(Golang.String chars, int r) {
  if (r >= 0 && r < 0x80) {
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == r) return true;
    }
    return false;
  }
  for (var i = 0; i < chars.length;) {
    final (c, n) = chars.decodeRune(i);
    if (c == r) return true;
    i += n;
  }
  return false;
}

/// `bytes.IndexAny(s, chars)`.
Golang.Int indexAny(_Bytes s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  final g = _str(s);
  for (var i = 0; i < s.length;) {
    final (c, n) = g.decodeRune(i);
    if (_inChars(chars, c)) return Golang.Int(i);
    i += n;
  }
  return Golang.Int(-1);
}

/// `bytes.LastIndexAny(s, chars)`.
Golang.Int lastIndexAny(_Bytes s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  final g = _str(s);
  for (var i = s.length; i > 0;) {
    final (c, n) = decodeLastRune(g, i);
    i -= n;
    if (_inChars(chars, c)) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `bytes.ContainsAny(b, chars)`.
bool containsAny(_Bytes b, Golang.String chars) =>
    indexAny(b, chars).toInt() >= 0;

/// `bytes.IndexFunc(s, f)`.
Golang.Int indexFunc(_Bytes s, bool Function(Golang.Rune)? f) {
  final g = _str(s);
  for (var i = 0; i < s.length;) {
    final (r, n) = g.decodeRune(i);
    if (f!(Golang.Rune(r))) return Golang.Int(i);
    i += n;
  }
  return Golang.Int(-1);
}

/// `bytes.LastIndexFunc(s, f)`.
Golang.Int lastIndexFunc(_Bytes s, bool Function(Golang.Rune)? f) {
  final g = _str(s);
  for (var i = s.length; i > 0;) {
    final (r, n) = decodeLastRune(g, i);
    i -= n;
    if (f!(Golang.Rune(r))) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `bytes.ContainsFunc(b, f)`.
bool containsFunc(_Bytes b, bool Function(Golang.Rune)? f) =>
    indexFunc(b, f).toInt() >= 0;

/// `bytes.TrimPrefix(s, prefix)`.
_Bytes trimPrefix(_Bytes s, _Bytes prefix) =>
    hasPrefix(s, prefix) ? s.slice(prefix.length) : s;

/// `bytes.TrimSuffix(s, suffix)`.
_Bytes trimSuffix(_Bytes s, _Bytes suffix) =>
    hasSuffix(s, suffix) ? s.slice(0, s.length - suffix.length) : s;

/// `bytes.TrimLeftFunc(s, f)`: tudo aparado vira nil.
_Bytes trimLeftFunc(_Bytes s, bool Function(Golang.Rune)? f) {
  final g = _str(s);
  for (var i = 0; i < s.length;) {
    final (r, n) = g.decodeRune(i);
    if (!f!(Golang.Rune(r))) return s.slice(i);
    i += n;
  }
  return _nilBytes();
}

/// `bytes.TrimRightFunc(s, f)`.
_Bytes trimRightFunc(_Bytes s, bool Function(Golang.Rune)? f) {
  final g = _str(s);
  for (var i = s.length; i > 0;) {
    final (r, n) = decodeLastRune(g, i);
    i -= n;
    if (!f!(Golang.Rune(r))) return s.slice(0, i + g.decodeRune(i).$2);
  }
  return s.slice(0, 0);
}

/// `bytes.TrimFunc(s, f)`.
_Bytes trimFunc(_Bytes s, bool Function(Golang.Rune)? f) =>
    trimRightFunc(trimLeftFunc(s, f), f);

/// `bytes.Trim(s, cutset)`: vazio vira nil.
_Bytes trim(_Bytes s, Golang.String cutset) {
  if (s.length == 0) return _nilBytes();
  if (cutset.length == 0) return s;
  return trimLeft(trimRight(s, cutset), cutset);
}

/// `bytes.Cut(s, sep)`: subslices de s, não cópias.
(_Bytes, _Bytes, bool) cut(_Bytes s, _Bytes sep) {
  final i = index(s, sep).toInt();
  if (i >= 0) return (s.slice(0, i), s.slice(i + sep.length), true);
  return (s, _nilBytes(), false);
}

/// `bytes.CutPrefix(s, prefix)`.
(_Bytes, bool) cutPrefix(_Bytes s, _Bytes prefix) =>
    hasPrefix(s, prefix) ? (s.slice(prefix.length), true) : (s, false);

/// `bytes.CutSuffix(s, suffix)`.
(_Bytes, bool) cutSuffix(_Bytes s, _Bytes suffix) =>
    hasSuffix(s, suffix)
    ? (s.slice(0, s.length - suffix.length), true)
    : (s, false);
