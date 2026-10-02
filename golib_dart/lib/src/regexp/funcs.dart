part of '../../regexp.dart';

/// `regexp.Compile(expr)`: erro com a mensagem do Go (`error parsing
/// regexp: ...`).
(Regexp?, GoError?) compile(Golang.String expr) {
  try {
    final p = _Parser.parse(expr);
    return (Regexp._(expr, _Prog.compile(p.root), p.numCap, p.names), null);
  } on _SyntaxError catch (e) {
    return (null, ErrorString(e.message));
  }
}

/// `regexp.MustCompile(str)`: pânico `regexp: Compile(<quoted>): <erro>`.
Regexp? mustCompile(Golang.String str) {
  final (re, err) = compile(str);
  if (err != null) {
    throw Panic(
      Golang.String.fromDart('regexp: Compile(${_quoteRe(str)}): ') +
          err.error(),
    );
  }
  return re;
}

/// `regexp.MatchString(pattern, s)`.
(bool, GoError?) matchString(Golang.String pattern, Golang.String s) {
  final (re, err) = compile(pattern);
  if (err != null) return (false, err);
  return (re!.matchString(s), null);
}

/// `regexp.Match(pattern, b)`.
(bool, GoError?) match(Golang.String pattern, Slice<Golang.Uint8> b) {
  final (re, err) = compile(pattern);
  if (err != null) return (false, err);
  return (re!.match(b), null);
}

/// `regexp.QuoteMeta(s)`: escapa `\.+*?()|[]{}^$`.
Golang.String quoteMeta(Golang.String s) {
  const special = r'\.+*?()|[]{}^$';
  final out = <int>[];
  for (final c in s.toBytes()) {
    if (c < 0x80 && special.codeUnits.contains(c)) out.add(0x5c);
    out.add(c);
  }
  return Golang.String.fromBytes(Uint8List.fromList(out));
}

// strconv.Quote do Go (para a mensagem do pânico de MustCompile).
String _quote(Golang.String s) {
  final b = StringBuffer('"');
  final bytes = s.toBytes();
  for (var i = 0; i < bytes.length;) {
    final (r, w) = _decodeRune(bytes, i);
    if (r == 0xfffd && w == 1) {
      b.write('\\x${bytes[i].toRadixString(16).padLeft(2, '0')}');
      i++;
      continue;
    }
    i += w;
    switch (r) {
      case 0x22:
        b.write('\\"');
      case 0x5c:
        b.write('\\\\');
      case 7:
        b.write('\\a');
      case 8:
        b.write('\\b');
      case 12:
        b.write('\\f');
      case 10:
        b.write('\\n');
      case 13:
        b.write('\\r');
      case 9:
        b.write('\\t');
      case 11:
        b.write('\\v');
      default:
        if (isprint.isPrint(r)) {
          b.writeCharCode(r);
        } else if (r < 0x20 || r == 0x7f) {
          b.write('\\x${r.toRadixString(16).padLeft(2, '0')}');
        } else if (r < 0x10000) {
          b.write('\\u${r.toRadixString(16).padLeft(4, '0')}');
        } else {
          b.write('\\U${r.toRadixString(16).padLeft(8, '0')}');
        }
    }
  }
  return (b..write('"')).toString();
}

// `quote` de regexp.go: crase se possível (strconv.CanBackquote), senão Quote.
String _quoteRe(Golang.String s) {
  final bytes = s.toBytes();
  var can = true;
  for (var i = 0; i < bytes.length && can;) {
    final (r, w) = _decodeRune(bytes, i);
    i += w;
    if (r == 0xfffd && w == 1) {
      can = false;
    } else if (w > 1) {
      if (r == 0xfeff) can = false;
    } else if ((r != 9 && (r < 0x20 || r == 0x7f)) || r == 0x60) {
      can = false;
    }
  }
  return can ? '`${s.toDart()}`' : _quote(s);
}
