part of '../../strings.dart';

bool _validRune(int r) =>
    (r >= 0 && r < 0xd800) || (r > 0xdfff && r <= 0x10ffff);

/// `strings.IndexRune(s, r)`: `RuneError` casa o primeiro UTF-8 inválido
/// (ou U+FFFD); runa inválida nunca está.
Golang.Int indexRune(Golang.String s, Golang.Rune r) {
  final v = r.toInt();
  if (v >= 0 && v < 0x80) return indexByte(s, Golang.Uint8(v));
  if (v == 0xfffd) {
    for (var i = 0; i < s.length;) {
      final (c, n) = s.decodeRune(i);
      if (c == 0xfffd) return Golang.Int(i);
      i += n;
    }
    return Golang.Int(-1);
  }
  if (!_validRune(v)) return Golang.Int(-1);
  return index(s, Golang.String.fromCodePoint(v));
}

/// `strings.IndexAny(s, chars)`: índice da primeira runa de s que está em
/// chars, ou -1.
Golang.Int indexAny(Golang.String s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  for (var i = 0; i < s.length;) {
    final (c, n) = s.decodeRune(i);
    if (indexRune(chars, Golang.Rune(c)).toInt() >= 0) return Golang.Int(i);
    i += n;
  }
  return Golang.Int(-1);
}

/// `strings.LastIndexAny(s, chars)`.
Golang.Int lastIndexAny(Golang.String s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  for (var i = s.length; i > 0;) {
    final (c, n) = decodeLastRune(s, i);
    i -= n;
    if (indexRune(chars, Golang.Rune(c)).toInt() >= 0) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.ContainsAny(s, chars)`.
bool containsAny(Golang.String s, Golang.String chars) =>
    indexAny(s, chars).toInt() >= 0;

/// `strings.ContainsFunc(s, f)`.
bool containsFunc(Golang.String s, bool Function(Golang.Rune)? f) =>
    indexFunc(s, f).toInt() >= 0;

/// `strings.IndexFunc(s, f)`.
Golang.Int indexFunc(Golang.String s, bool Function(Golang.Rune)? f) {
  for (var i = 0; i < s.length;) {
    final (r, n) = s.decodeRune(i);
    if (f!(Golang.Rune(r))) return Golang.Int(i);
    i += n;
  }
  return Golang.Int(-1);
}

/// `strings.LastIndexFunc(s, f)`.
Golang.Int lastIndexFunc(Golang.String s, bool Function(Golang.Rune)? f) {
  for (var i = s.length; i > 0;) {
    final (r, n) = decodeLastRune(s, i);
    i -= n;
    if (f!(Golang.Rune(r))) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.LastIndexByte(s, c)`.
Golang.Int lastIndexByte(Golang.String s, Golang.Uint8 c) {
  final b = c.toInt();
  for (var i = s.length - 1; i >= 0; i--) {
    if (s[i] == b) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.TrimLeft(s, cutset)`: tira do início as runas de cutset.
Golang.String trimLeft(Golang.String s, Golang.String cutset) {
  if (s.length == 0 || cutset.length == 0) return s;
  var i = 0;
  while (i < s.length) {
    final (r, n) = s.decodeRune(i);
    if (!containsRune(cutset, Golang.Rune(r))) break;
    i += n;
  }
  return s.slice(i);
}

/// `strings.TrimRight(s, cutset)`: tira do fim as runas de cutset.
Golang.String trimRight(Golang.String s, Golang.String cutset) {
  if (s.length == 0 || cutset.length == 0) return s;
  var end = s.length;
  while (end > 0) {
    final (r, n) = decodeLastRune(s, end);
    if (!containsRune(cutset, Golang.Rune(r))) break;
    end -= n;
  }
  return s.slice(0, end);
}

/// `strings.Trim(s, cutset)`.
Golang.String trim(Golang.String s, Golang.String cutset) {
  if (s.length == 0 || cutset.length == 0) return s;
  return trimLeft(trimRight(s, cutset), cutset);
}
