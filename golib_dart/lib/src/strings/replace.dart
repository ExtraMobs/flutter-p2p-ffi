part of '../../strings.dart';

/// `strings.TrimLeft(s, cutset)`: tira do início as runas presentes em
/// cutset; sem os atalhos ASCII/byte único do Go (só desempenho).
Golang.String trimLeft(Golang.String s, Golang.String cutset) {
  if (s.length == 0 || cutset.length == 0) return s;
  while (s.length > 0) {
    final (r, n) = s.decodeRune(0);
    if (!containsRune(cutset, Golang.Rune(r))) break;
    s = s.slice(n);
  }
  return s;
}

/// `strings.TrimRight(s, cutset)`.
Golang.String trimRight(Golang.String s, Golang.String cutset) {
  if (s.length == 0 || cutset.length == 0) return s;
  while (s.length > 0) {
    final (r, n) = decodeLastRune(s, s.length);
    if (!containsRune(cutset, Golang.Rune(r))) break;
    s = s.slice(0, s.length - n);
  }
  return s;
}

/// `strings.Trim(s, cutset)`.
Golang.String trim(Golang.String s, Golang.String cutset) =>
    trimLeft(trimRight(s, cutset), cutset);

/// `strings.LastIndexByte(s, c)`: último índice do byte c, ou -1.
Golang.Int lastIndexByte(Golang.String s, Golang.Uint8 c) {
  final b = c.toInt();
  for (var i = s.length - 1; i >= 0; i--) {
    if (s[i] == b) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.IndexRune(s, r)`: -1 se ausente; `RuneError` casa também bytes
/// UTF-8 inválidos (como o range do Go).
Golang.Int indexRune(Golang.String s, Golang.Rune r) {
  final v = r.toInt();
  if (v == 0xfffd) {
    for (var i = 0; i < s.length;) {
      final (c, n) = s.decodeRune(i);
      if (c == 0xfffd) return Golang.Int(i);
      i += n;
    }
    return Golang.Int(-1);
  }
  if (v < 0 || v > 0x10ffff || (v >= 0xd800 && v <= 0xdfff)) {
    return Golang.Int(-1);
  }
  return index(s, Golang.String.fromCodePoint(v));
}

/// `strings.IndexAny(s, chars)`: primeiro índice de qualquer code point de
/// chars em s, ou -1; chars vazio nunca casa.
// ponytail: sem os atalhos ASCII/1-byte do Go, só desempenho.
Golang.Int indexAny(Golang.String s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  final set = chars.runes().toSet();
  for (var i = 0; i < s.length;) {
    final (r, n) = s.decodeRune(i);
    if (set.contains(r)) return Golang.Int(i);
    i += n;
  }
  return Golang.Int(-1);
}

/// `strings.LastIndexAny(s, chars)`.
Golang.Int lastIndexAny(Golang.String s, Golang.String chars) {
  if (chars.length == 0) return Golang.Int(-1);
  final set = chars.runes().toSet();
  for (var i = s.length; i > 0;) {
    final (r, n) = decodeLastRune(s, i);
    i -= n;
    if (set.contains(r)) return Golang.Int(i);
  }
  return Golang.Int(-1);
}

/// `strings.ContainsAny(s, chars)`.
bool containsAny(Golang.String s, Golang.String chars) =>
    indexAny(s, chars) >= Golang.Int(0);

/// `strings.Compare(a, b)`: -1, 0 ou +1 (nunca a diferença crua de bytes).
Golang.Int compare(Golang.String a, Golang.String b) {
  final c = a.compareTo(b);
  return Golang.Int(c < 0 ? -1 : (c > 0 ? 1 : 0));
}

/// `strings.Clone(s)`: cópia independente dos bytes (`String.slice` é uma
/// view sobre o array do pai; ver `fixed_types/golang/string.dart`).
Golang.String clone(Golang.String s) => Golang.String.fromBytes(s.toBytes());

/// `strings.SplitAfter(s, sep)`.
Slice<Golang.String> splitAfter(Golang.String s, Golang.String sep) =>
    _genSplit(s, sep, sep.length, -1);

/// `strings.SplitAfterN(s, sep, n)`.
Slice<Golang.String> splitAfterN(
  Golang.String s,
  Golang.String sep,
  Golang.Int n,
) => _genSplit(s, sep, sep.length, n.toInt());

/// `strings.Cut(s, sep)`.
(Golang.String, Golang.String, bool) cut(Golang.String s, Golang.String sep) {
  final i = index(s, sep).toInt();
  if (i >= 0) return (s.slice(0, i), s.slice(i + sep.length), true);
  return (s, Golang.String(), false);
}

/// `strings.CutPrefix(s, prefix)`.
(Golang.String, bool) cutPrefix(Golang.String s, Golang.String prefix) =>
    hasPrefix(s, prefix) ? (s.slice(prefix.length), true) : (s, false);

/// `strings.CutSuffix(s, suffix)`.
(Golang.String, bool) cutSuffix(Golang.String s, Golang.String suffix) =>
    hasSuffix(s, suffix)
    ? (s.slice(0, s.length - suffix.length), true)
    : (s, false);

/// `strings.Repeat(s, count)`: pânico com contagem negativa, como o Go;
/// sem o cache de blocos de 8KB (só desempenho).
Golang.String repeat(Golang.String s, Golang.Int countArg) {
  final n = countArg.toInt();
  if (n == 0) return Golang.String();
  if (n == 1) return s;
  if (n < 0) {
    throw Panic(Golang.String.fromDart('strings: negative Repeat count'));
  }
  if (s.length == 0) return Golang.String();
  final sb = s.toBytes();
  final out = Uint8List(sb.length * n);
  for (var i = 0; i < n; i++) {
    out.setRange(i * sb.length, (i + 1) * sb.length, sb);
  }
  return Golang.String.fromBytes(out);
}

/// `strings.Replace(s, old, new, n)`.
Golang.String replace(
  Golang.String s,
  Golang.String old,
  Golang.String new_,
  Golang.Int nArg,
) {
  var n = nArg.toInt();
  if (old == new_ || n == 0) return s;
  final m = count(s, old).toInt();
  if (m == 0) return s;
  if (n < 0 || m < n) n = m;
  final b = Builder();
  b.grow(Golang.Int(s.length + n * (new_.length - old.length)));
  var start = 0;
  for (var i = 0; i < n; i++) {
    var j = start;
    if (old.length == 0) {
      if (i > 0) {
        final (_, wid) = s.decodeRune(start);
        j += wid;
      }
    } else {
      j += index(s.slice(start), old).toInt();
    }
    b.writeString(s.slice(start, j));
    b.writeString(new_);
    start = j + old.length;
  }
  b.writeString(s.slice(start));
  return b.string();
}

/// `strings.ReplaceAll(s, old, new)`.
Golang.String replaceAll(
  Golang.String s,
  Golang.String old,
  Golang.String new_,
) => replace(s, old, new_, Golang.Int(-1));

/// `strings.Map(mapping, s)`: porta fiel de `strings.Map` do Go 1.26,
/// inclusive a normalização de bytes UTF-8 inválidos para U+FFFD (3 bytes)
/// depois da primeira mudança — comportamento real do Go, não só do shim.
Golang.String map(Golang.Rune Function(Golang.Rune) mapping, Golang.String s) {
  final b = Builder();
  var i = 0;
  var changed = false;
  while (i < s.length) {
    final (c0, w0) = s.decodeRune(i);
    final r = mapping(Golang.Rune(c0)).toInt();
    if (r == c0 && c0 != 0xfffd) {
      i += w0;
      continue;
    }
    if (c0 == 0xfffd && w0 != 1 && r == c0) {
      // U+FFFD codificado de verdade (3 bytes) mapeado nele mesmo: sem
      // mudança real, como no Go.
      i += w0;
      continue;
    }
    b.grow(Golang.Int(s.length + 4)); // utf8.UTFMax
    b.writeString(s.slice(0, i));
    if (r >= 0) b.writeRune(Golang.Rune(r));
    s = s.slice(i + w0);
    changed = true;
    break;
  }
  if (!changed) return s;
  for (var j = 0; j < s.length;) {
    final (c, w) = s.decodeRune(j);
    final r = mapping(Golang.Rune(c)).toInt();
    if (r >= 0) {
      if (r < 0x80) {
        b.writeByte(Golang.Uint8(r));
      } else {
        b.writeRune(Golang.Rune(r));
      }
    }
    j += w;
  }
  return b.string();
}
