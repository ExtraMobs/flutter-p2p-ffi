part of '../../strings.dart';

// asciiSpace do Go: espaço em branco ASCII de 1 byte.
bool _asciiSpace(int c) =>
    c == 0x09 || c == 0x0a || c == 0x0b || c == 0x0c || c == 0x0d || c == 0x20;

// `strings.isSeparator` (Title): alfanuméricos ASCII e `_` não separam
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

/// Mapeia s runa a runa (decodificação do Go, `unicode.DecodeRuneInString`);
/// `mapping` negativo descarta a runa. Porta de `strings.Map` sem o atalho
/// de alocação "entrada inalterada" do Go (não observável: mesmo número e
/// ordem de chamadas a `mapping`, único efeito que poderia importar).
Golang.String _mapRunes(int Function(int) mapping, Golang.String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length;) {
    final (r0, w) = s.decodeRune(i);
    i += w;
    final r = mapping(r0);
    if (r >= 0) buf.writeCharCode(r);
  }
  return Golang.String.fromDart(buf.toString());
}

/// `strings.ToUpper(s)`: atalho ASCII do Go (só escreve o que muda), senão
/// `unicode.ToUpper` runa a runa.
Golang.String toUpper(Golang.String s) {
  var isASCII = true, hasLower = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c >= 0x80) {
      isASCII = false;
      break;
    }
    hasLower = hasLower || (c >= 0x61 && c <= 0x7a);
  }
  if (isASCII) {
    if (!hasLower) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      var c = s[i];
      if (c >= 0x61 && c <= 0x7a) c -= 0x20;
      buf.writeCharCode(c);
    }
    return Golang.String.fromDart(buf.toString());
  }
  return _mapRunes((r) => unicode.toUpper(Golang.Rune(r)).toInt(), s);
}

/// `strings.ToLower(s)`: como [toUpper], para minúsculas.
Golang.String toLower(Golang.String s) {
  var isASCII = true, hasUpper = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c >= 0x80) {
      isASCII = false;
      break;
    }
    hasUpper = hasUpper || (c >= 0x41 && c <= 0x5a);
  }
  if (isASCII) {
    if (!hasUpper) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      var c = s[i];
      if (c >= 0x41 && c <= 0x5a) c += 0x20;
      buf.writeCharCode(c);
    }
    return Golang.String.fromDart(buf.toString());
  }
  return _mapRunes((r) => unicode.toLower(Golang.Rune(r)).toInt(), s);
}

/// `strings.ToTitle(s)`: sem atalho ASCII no Go (sempre mapeia).
Golang.String toTitle(Golang.String s) =>
    _mapRunes((r) => unicode.toTitle(Golang.Rune(r)).toInt(), s);

/// `strings.Title(s)` (deprecated no Go: não trata pontuação Unicode
/// direito; mantido por fidelidade). Maiusculiza a runa que começa uma
/// palavra (a anterior é separadora).
Golang.String title(Golang.String s) {
  var prev = 0x20; // ' ': início de s conta como início de palavra.
  return _mapRunes((r) {
    final mapped = _isSeparator(prev)
        ? unicode.toTitle(Golang.Rune(r)).toInt()
        : r;
    prev = r;
    return mapped;
  }, s);
}

/// `strings.EqualFold(s, t)`: iguais por *simple case folding* Unicode.
bool equalFold(Golang.String s, Golang.String t) {
  var i = 0;
  while (i < s.length && i < t.length) {
    var sr = s[i], tr = t[i];
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

bool _equalFoldUnicode(Golang.String s, Golang.String t) {
  var i = 0;
  while (i < s.length) {
    if (t.length == 0) return false;
    final (srDecoded, sw) = s.decodeRune(i);
    var sr = srDecoded;
    i += sw;
    int tr;
    if (t[0] < 0x80) {
      tr = t[0];
      t = t.slice(1);
    } else {
      final (r, w) = t.decodeRune(0);
      tr = r;
      t = t.slice(w);
    }
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

/// `strings.TrimSpace(s)`: atalho ASCII, senão `TrimFunc`/`TrimRightFunc`
/// com `unicode.IsSpace` a partir do primeiro byte não-ASCII.
Golang.String trimSpace(Golang.String s) {
  var start = 0;
  while (start < s.length) {
    final c = s[start];
    if (c >= 0x80) {
      return trimFunc(s.slice(start), (r) => unicode.isSpace(r));
    }
    if (!_asciiSpace(c)) break;
    start++;
  }
  var stop = s.length;
  while (stop > start) {
    final c = s[stop - 1];
    if (c >= 0x80) {
      return trimRightFunc(s.slice(start, stop), (r) => unicode.isSpace(r));
    }
    if (!_asciiSpace(c)) break;
    stop--;
  }
  return s.slice(start, stop);
}

/// `strings.Fields(s)`: atalho ASCII (conta e fatia direto pelos bytes),
/// senão `FieldsFunc` com `unicode.IsSpace`.
Slice<Golang.String> fields(Golang.String s) {
  var n = 0, wasSpace = true, hasNonAscii = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c >= 0x80) hasNonAscii = true;
    final isSp = _asciiSpace(c);
    if (wasSpace && !isSp) n++;
    wasSpace = isSp;
  }
  if (hasNonAscii) return fieldsFunc(s, (r) => unicode.isSpace(r));
  final a = Slice<Golang.String>.make(n, n, _strElem);
  var na = 0, i = 0;
  while (i < s.length && _asciiSpace(s[i])) {
    i++;
  }
  var fieldStart = i;
  while (i < s.length) {
    if (!_asciiSpace(s[i])) {
      i++;
      continue;
    }
    a[na] = s.slice(fieldStart, i);
    na++;
    i++;
    while (i < s.length && _asciiSpace(s[i])) {
      i++;
    }
    fieldStart = i;
  }
  if (fieldStart < s.length) a[na] = s.slice(fieldStart);
  return a;
}

/// `strings.ToValidUTF8(s, replacement)`: cada sequência UTF-8 inválida
/// (bytes exatos, não a runa decodificada) vira uma cópia de `replacement`;
/// o resto passa pelos bytes originais, sem recodificar.
Golang.String toValidUTF8(Golang.String s, Golang.String replacement) {
  final out = BytesBuilder(copy: false);
  var invalid = false;
  var i = 0;
  while (i < s.length) {
    final b0 = s[i];
    if (b0 < 0x80) {
      out.addByte(b0);
      i++;
      invalid = false;
      continue;
    }
    final (r, w) = s.decodeRune(i);
    if (r == 0xfffd && w == 1) {
      if (!invalid) {
        invalid = true;
        out.add(replacement.toBytes());
      }
      i++;
      continue;
    }
    invalid = false;
    out.add(s.slice(i, i + w).toBytes());
    i += w;
  }
  return Golang.String.fromBytes(out.toBytes());
}
