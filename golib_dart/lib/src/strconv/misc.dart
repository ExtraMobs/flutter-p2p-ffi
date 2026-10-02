part of '../../strconv.dart';

/// `append(dst, bytes...)`.
Slice<Golang.Uint8> _appendBytes(Slice<Golang.Uint8> dst, List<int> bytes) =>
    dst.append([for (final b in bytes) Golang.Uint8(b)]);

// ------------------------------------------------------------------- bool

/// `strconv.ParseBool`.
(bool, GoError?) parseBool(Golang.String str) {
  switch (String.fromCharCodes(str.toBytes())) {
    case '1' || 't' || 'T' || 'true' || 'TRUE' || 'True':
      return (true, null);
    case '0' || 'f' || 'F' || 'false' || 'FALSE' || 'False':
      return (false, null);
  }
  return (false, _NumError('ParseBool', str, errSyntax));
}

/// `strconv.FormatBool`.
Golang.String formatBool(bool b) =>
    Golang.String.fromDart(b ? 'true' : 'false');

/// `strconv.AppendBool`.
Slice<Golang.Uint8> appendBool(Slice<Golang.Uint8> dst, bool b) =>
    _appendBytes(dst, (b ? 'true' : 'false').codeUnits);

// ----------------------------------------------------------- AppendInt/Uint

/// `strconv.AppendInt(dst, i, base)`.
Slice<Golang.Uint8> appendInt(
  Slice<Golang.Uint8> dst,
  Golang.Int64 i,
  Golang.Int base,
) => _appendBytes(dst, formatInt(i, base).toBytes());

/// `strconv.AppendUint(dst, i, base)`.
Slice<Golang.Uint8> appendUint(
  Slice<Golang.Uint8> dst,
  Golang.Uint64 i,
  Golang.Int base,
) => _appendBytes(dst, formatUint(i, base).toBytes());

// ------------------------------------------------------------------- quote

Golang.String _qs(List<int> b) =>
    Golang.String.fromBytes(Uint8List.fromList(b));

List<int> _runeBytes(Golang.Rune r) =>
    utf8.encode(String.fromCharCode(qc.validRune(r.toInt())));

/// `strconv.Quote`.
Golang.String quote(Golang.String s) =>
    _qs(qc.quoteBytes(s.toBytes(), 0x22, false));

/// `strconv.QuoteToASCII`.
Golang.String quoteToASCII(Golang.String s) =>
    _qs(qc.quoteBytes(s.toBytes(), 0x22, true));

/// `strconv.QuoteRune`.
Golang.String quoteRune(Golang.Rune r) =>
    _qs(qc.quoteBytes(_runeBytes(r), 0x27, false));

/// `strconv.QuoteRuneToASCII`.
Golang.String quoteRuneToASCII(Golang.Rune r) =>
    _qs(qc.quoteBytes(_runeBytes(r), 0x27, true));

/// `strconv.AppendQuote`.
Slice<Golang.Uint8> appendQuote(Slice<Golang.Uint8> dst, Golang.String s) =>
    _appendBytes(dst, qc.quoteBytes(s.toBytes(), 0x22, false));

/// `strconv.AppendQuoteToASCII`.
Slice<Golang.Uint8> appendQuoteToASCII(
  Slice<Golang.Uint8> dst,
  Golang.String s,
) => _appendBytes(dst, qc.quoteBytes(s.toBytes(), 0x22, true));

/// `strconv.AppendQuoteRune`.
Slice<Golang.Uint8> appendQuoteRune(Slice<Golang.Uint8> dst, Golang.Rune r) =>
    _appendBytes(dst, qc.quoteBytes(_runeBytes(r), 0x27, false));

/// `strconv.AppendQuoteRuneToASCII`.
Slice<Golang.Uint8> appendQuoteRuneToASCII(
  Slice<Golang.Uint8> dst,
  Golang.Rune r,
) => _appendBytes(dst, qc.quoteBytes(_runeBytes(r), 0x27, true));

/// `strconv.CanBackquote`.
bool canBackquote(Golang.String s) => qc.canBackquote(s.toBytes());

/// `strconv.IsPrint`.
bool isPrint(Golang.Rune r) => ip.isPrint(r.toInt());

// ----------------------------------------------------------------- unquote

int _unhex(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  return -1;
}

bool _validRuneStrict(int r) =>
    (r >= 0 && r < 0xd800) || (r > 0xdfff && r <= 0x10ffff);

/// `strconv.UnquoteChar`.
(Golang.Rune, bool, Golang.String, GoError?) unquoteChar(
  Golang.String s,
  Golang.Uint8 quote,
) {
  final b = s.toBytes();
  final (v, multi, tail, ok) = _unquoteChar(b, 0, quote.toInt());
  if (!ok) {
    return (Golang.Rune(0), false, Golang.String.fromDart(''), errSyntax);
  }
  return (
    Golang.Rune(v),
    multi,
    Golang.String.fromBytes(Uint8List.sublistView(b, tail)),
    null,
  );
}

/// Decodifica o caractere em `s[at]`: (valor, multibyte, índice do resto, ok).
(int, bool, int, bool) _unquoteChar(Uint8List s, int at, int quote) {
  const bad = (0, false, 0, false);
  if (at >= s.length) return bad;
  final c0 = s[at];
  if (c0 == quote && (quote == 0x27 || quote == 0x22)) return bad;
  if (c0 >= 0x80) {
    final (r, size) = qc.decodeRune(s, at);
    return (r, true, at + size, true);
  }
  if (c0 != 0x5c) return (c0, false, at + 1, true);
  if (s.length - at <= 1) return bad;
  final c = s[at + 1];
  var i = at + 2;
  switch (c) {
    case 0x61:
      return (7, false, i, true);
    case 0x62:
      return (8, false, i, true);
    case 0x66:
      return (12, false, i, true);
    case 0x6e:
      return (10, false, i, true);
    case 0x72:
      return (13, false, i, true);
    case 0x74:
      return (9, false, i, true);
    case 0x76:
      return (11, false, i, true);
    case 0x78 || 0x75 || 0x55:
      final n = c == 0x78 ? 2 : (c == 0x75 ? 4 : 8);
      if (s.length - i < n) return bad;
      var v = 0;
      for (var j = 0; j < n; j++) {
        final x = _unhex(s[i + j]);
        if (x < 0) return bad;
        v = (v << 4) | x;
      }
      i += n;
      if (c == 0x78) return (v, false, i, true);
      if (!_validRuneStrict(v)) return bad;
      return (v, true, i, true);
    case >= 0x30 && <= 0x37:
      var v = c - 0x30;
      if (s.length - i < 2) return bad;
      for (var j = 0; j < 2; j++) {
        final x = s[i + j] - 0x30;
        if (x < 0 || x > 7) return bad;
        v = (v << 3) | x;
      }
      i += 2;
      if (v > 255) return bad;
      return (v, false, i, true);
    case 0x5c:
      return (0x5c, false, i, true);
    case 0x27 || 0x22:
      if (c != quote) return bad;
      return (c, false, i, true);
  }
  return bad;
}

/// `strconv.Unquote`.
(Golang.String, GoError?) unquote(Golang.String s) {
  final zero = Golang.String.fromDart('');
  final src = s.toBytes();
  if (src.length < 2) return (zero, errSyntax);
  final quote = src[0];
  final close = src.indexOf(quote, 1);
  if (close < 0) return (zero, errSyntax);
  final end = close + 1; // após a aspa final (errado se houver escapes)
  switch (quote) {
    case 0x60:
      if (end != src.length) return (zero, errSyntax);
      return (
        Golang.String.fromBytes(
          Uint8List.fromList([
            for (var i = 1; i < end - 1; i++)
              if (src[i] != 0x0d) src[i],
          ]),
        ),
        null,
      );
    case 0x22 || 0x27:
      final buf = <int>[];
      var i = 1;
      while (i < src.length && src[i] != quote) {
        final (r, multi, next, ok) = _unquoteChar(src, i, quote);
        if (src[i] == 0x0a || !ok) return (zero, errSyntax);
        i = next;
        if (r < 0x80 || !multi) {
          buf.add(r & 0xff);
        } else {
          buf.addAll(utf8.encode(String.fromCharCode(r)));
        }
        if (quote == 0x27) break;
      }
      if (!(i < src.length && src[i] == quote)) return (zero, errSyntax);
      i++;
      if (i != src.length) return (zero, errSyntax);
      return (Golang.String.fromBytes(Uint8List.fromList(buf)), null);
  }
  return (zero, errSyntax);
}
