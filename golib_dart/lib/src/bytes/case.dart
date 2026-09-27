part of '../../bytes.dart';

// asciiSpace do Go: espaço em branco ASCII de 1 byte.
bool _asciiSpace(int c) =>
    c == 0x09 || c == 0x0a || c == 0x0b || c == 0x0c || c == 0x0d || c == 0x20;

// `bytes.isSeparator` (Title): alfanuméricos ASCII e `_` não separam
// palavras; fora do ASCII, letra/dígito não separam, o resto é espaço ou não.
bool _isSeparator(int r) {
  if (r <= 0x7f) {
    if (r >= 0x30 && r <= 0x39) return false; // 0-9
    if (r >= 0x61 && r <= 0x7a) return false; // a-z
    if (r >= 0x41 && r <= 0x5a) return false; // A-Z
    if (r == 0x5f) return false; // _
    return true;
  }
  final rr = Golang.Rune(r);
  if (unicode.isLetter(rr) || unicode.isDigit(rr)) return false;
  return unicode.isSpace(rr);
}

/// Mapeia s (interpretado como UTF-8) runa a runa, como `bytes.Map`;
/// `mapping` negativo descarta a runa.
_Bytes _mapRunes(int Function(int) mapping, _Bytes s) {
  final str = _str(s);
  final buf = StringBuffer();
  for (var i = 0; i < str.length;) {
    final (r0, w) = str.decodeRune(i);
    i += w;
    final r = mapping(r0);
    if (r >= 0) buf.writeCharCode(r);
  }
  return _bytesOf(Golang.String.fromDart(buf.toString()));
}

/// `bytes.ToUpper(s)`: atalho ASCII do Go, senão `unicode.ToUpper` runa a
/// runa.
_Bytes toUpper(_Bytes s) {
  var isASCII = true, hasLower = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i].toInt();
    if (c >= 0x80) {
      isASCII = false;
      break;
    }
    hasLower = hasLower || (c >= 0x61 && c <= 0x7a);
  }
  if (isASCII) {
    if (!hasLower) return Slice.of(s.items.toList(), _byteElem);
    return Slice.of([
      for (var i = 0; i < s.length; i++) Golang.Uint8(_upperByte(s[i].toInt())),
    ], _byteElem);
  }
  return _mapRunes((r) => unicode.toUpper(Golang.Rune(r)).toInt(), s);
}

int _upperByte(int c) => (c >= 0x61 && c <= 0x7a) ? c - 0x20 : c;

/// `bytes.ToLower(s)`: como [toUpper], para minúsculas.
_Bytes toLower(_Bytes s) {
  var isASCII = true, hasUpper = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i].toInt();
    if (c >= 0x80) {
      isASCII = false;
      break;
    }
    hasUpper = hasUpper || (c >= 0x41 && c <= 0x5a);
  }
  if (isASCII) {
    if (!hasUpper) return Slice.of(s.items.toList(), _byteElem);
    return Slice.of([
      for (var i = 0; i < s.length; i++) Golang.Uint8(_lowerByte(s[i].toInt())),
    ], _byteElem);
  }
  return _mapRunes((r) => unicode.toLower(Golang.Rune(r)).toInt(), s);
}

int _lowerByte(int c) => (c >= 0x41 && c <= 0x5a) ? c + 0x20 : c;

/// `bytes.Title(s)` (deprecated no Go, mantido por fidelidade): maiusculiza
/// a runa que começa uma palavra (a anterior é separadora).
_Bytes title(_Bytes s) {
  var prev = 0x20; // ' ': início de s conta como início de palavra.
  return _mapRunes((r) {
    final mapped = _isSeparator(prev)
        ? unicode.toTitle(Golang.Rune(r)).toInt()
        : r;
    prev = r;
    return mapped;
  }, s);
}

/// `bytes.EqualFold(s, t)`: iguais por *simple case folding* Unicode. O
/// atalho ASCII usa o mesmo índice `i` para s e t (como o Go: só avança
/// juntos enquanto os dois lados forem ASCII).
bool equalFold(_Bytes s, _Bytes t) {
  var i = 0;
  while (i < s.length && i < t.length) {
    var sr = s[i].toInt(), tr = t[i].toInt();
    if (sr >= 0x80 || tr >= 0x80) {
      return _equalFoldUnicode(s.slice(i), t.slice(i));
    }
    if (tr == sr) {
      i++;
      continue;
    }
    if (tr < sr) {
      final tmp = tr;
      tr = sr;
      sr = tmp;
    }
    if (sr >= 0x41 && sr <= 0x5a && tr == sr + 0x20) {
      i++;
      continue;
    }
    return false;
  }
  return s.length == t.length;
}

bool _equalFoldUnicode(_Bytes s, _Bytes t) {
  final str = _str(s);
  var i = 0;
  while (i < s.length) {
    if (t.length == 0) return false;
    final (srDecoded, sw) = str.decodeRune(i);
    var sr = srDecoded;
    i += sw;
    int tr, tw;
    final t0 = t[0].toInt();
    if (t0 < 0x80) {
      tr = t0;
      tw = 1;
    } else {
      final (r, w) = _str(t).decodeRune(0);
      tr = r;
      tw = w;
    }
    t = t.slice(tw);
    if (tr == sr) continue;
    if (tr < sr) {
      final tmp = tr;
      tr = sr;
      sr = tmp;
    }
    if (tr < 0x80) {
      if (sr >= 0x41 && sr <= 0x5a && tr == sr + 0x20) continue;
      return false;
    }
    var r = unicode.simpleFold(Golang.Rune(sr)).toInt();
    while (r != sr && r < tr) {
      r = unicode.simpleFold(Golang.Rune(r)).toInt();
    }
    if (r == tr) continue;
    return false;
  }
  return t.length == 0;
}

// `bytes.TrimLeftFunc`/`TrimRightFunc` com `unicode.IsSpace`, privadas: o
// shim `bytes` ainda não tem a família `Trim*Func` pública (fica para quem
// mexe em `TODO/P0-shim-bytes.md`); `trimSpace` só precisa da lógica.
_Bytes _trimLeftFunc(_Bytes s, bool Function(Golang.Rune) f) {
  final i = _scanIndexFunc(s, f, false);
  return i == -1 ? _nilBytes() : s.slice(i);
}

_Bytes _trimRightFunc(_Bytes s, bool Function(Golang.Rune) f) {
  var i = _scanLastIndexFunc(s, f, false);
  if (i >= 0 && s[i].toInt() >= 0x80) {
    final (_, w) = _str(s.slice(i)).decodeRune(0);
    i += w;
  } else {
    i++;
  }
  return s.slice(0, i);
}

/// `bytes.TrimSpace(s)`: atalho ASCII, senão `TrimFunc`/`TrimRightFunc` com
/// `unicode.IsSpace` a partir do primeiro byte não-ASCII; tudo espaço vira
/// nil (como no Go, ao contrário de `strings.TrimSpace`).
_Bytes trimSpace(_Bytes s) {
  var start = 0;
  while (start < s.length) {
    final c = s[start].toInt();
    if (c >= 0x80) {
      final left = _trimLeftFunc(s.slice(start), (r) => unicode.isSpace(r));
      return _trimRightFunc(left, (r) => unicode.isSpace(r));
    }
    if (!_asciiSpace(c)) break;
    start++;
  }
  var stop = s.length;
  while (stop > start) {
    final c = s[stop - 1].toInt();
    if (c >= 0x80) {
      return _trimRightFunc(s.slice(start, stop), (r) => unicode.isSpace(r));
    }
    if (!_asciiSpace(c)) break;
    stop--;
  }
  if (start == stop) return _nilBytes();
  return s.slice(start, stop);
}

/// `bytes.Fields(s)`: atalho ASCII, senão `FieldsFunc` com `unicode.IsSpace`.
Slice<_Bytes> fields(_Bytes s) {
  var n = 0, wasSpace = true, hasNonAscii = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i].toInt();
    if (c >= 0x80) hasNonAscii = true;
    final isSp = _asciiSpace(c);
    if (wasSpace && !isSp) n++;
    wasSpace = isSp;
  }
  if (hasNonAscii) return fieldsFunc(s, (r) => unicode.isSpace(r));
  final a = Slice<_Bytes>.make(n, n, _bytesElem);
  var na = 0, i = 0;
  while (i < s.length && _asciiSpace(s[i].toInt())) {
    i++;
  }
  var fieldStart = i;
  while (i < s.length) {
    if (!_asciiSpace(s[i].toInt())) {
      i++;
      continue;
    }
    a[na] = s.slice(fieldStart, i, i);
    na++;
    i++;
    while (i < s.length && _asciiSpace(s[i].toInt())) {
      i++;
    }
    fieldStart = i;
  }
  if (fieldStart < s.length) a[na] = s.slice(fieldStart, s.length, s.length);
  return a;
}

/// `bytes.FieldsFunc(s, f)`.
Slice<_Bytes> fieldsFunc(_Bytes s, bool Function(Golang.Rune)? f) {
  final spanStarts = <int>[], spanEnds = <int>[];
  var start = -1, i = 0;
  while (i < s.length) {
    var w = 1;
    var r = s[i].toInt();
    if (r >= 0x80) {
      final (rr, ww) = _str(s.slice(i)).decodeRune(0);
      r = rr;
      w = ww;
    }
    if (f!(Golang.Rune(r))) {
      if (start >= 0) {
        spanStarts.add(start);
        spanEnds.add(i);
        start = -1;
      }
    } else if (start < 0) {
      start = i;
    }
    i += w;
  }
  if (start >= 0) {
    spanStarts.add(start);
    spanEnds.add(s.length);
  }
  final a = Slice<_Bytes>.make(
    spanStarts.length,
    spanStarts.length,
    _bytesElem,
  );
  for (var k = 0; k < spanStarts.length; k++) {
    a[k] = s.slice(spanStarts[k], spanEnds[k], spanEnds[k]);
  }
  return a;
}

int _scanIndexFunc(_Bytes s, bool Function(Golang.Rune)? f, bool truth) {
  var i = 0;
  while (i < s.length) {
    var w = 1;
    var r = s[i].toInt();
    if (r >= 0x80) {
      final (rr, ww) = _str(s.slice(i)).decodeRune(0);
      r = rr;
      w = ww;
    }
    if (f!(Golang.Rune(r)) == truth) return i;
    i += w;
  }
  return -1;
}

int _scanLastIndexFunc(_Bytes s, bool Function(Golang.Rune)? f, bool truth) {
  for (var i = s.length; i > 0;) {
    final (r, w) = decodeLastRune(_str(s), i);
    i -= w;
    if (f!(Golang.Rune(r)) == truth) return i;
  }
  return -1;
}

/// `bytes.IndexFunc(s, f)`.
Golang.Int indexFunc(_Bytes s, bool Function(Golang.Rune)? f) =>
    Golang.Int(_scanIndexFunc(s, f, true));

/// `bytes.LastIndexFunc(s, f)`.
Golang.Int lastIndexFunc(_Bytes s, bool Function(Golang.Rune)? f) =>
    Golang.Int(_scanLastIndexFunc(s, f, true));

/// `bytes.ContainsFunc(s, f)`.
bool containsFunc(_Bytes s, bool Function(Golang.Rune)? f) =>
    _scanIndexFunc(s, f, true) >= 0;

/// `bytes.Runes(s)`: os pontos de código decodificados como UTF-8, como
/// `[]rune(string(s))`.
Slice<Golang.Rune> runes(_Bytes s) {
  final str = _str(s);
  final out = <Golang.Rune>[];
  for (var i = 0; i < str.length;) {
    final (r, w) = str.decodeRune(i);
    out.add(Golang.Rune(r));
    i += w;
  }
  return Slice.of(out, _runeElem);
}

const _runeElem = Elem<Golang.Rune>(4, Golang.Rune.new);
