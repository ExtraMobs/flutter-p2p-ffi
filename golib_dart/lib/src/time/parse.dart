part of '../../time.dart';

// Porta de `Parse`/`ParseInLocation`/`parse`/`parseTimeZone` e auxiliares
// de `time/format.go` e de `parseRFC3339`/`parseStrictRFC3339` de
// `time/format_rfc3339.go` do Go 1.26.5. Tudo sobre strings de bytes
// ([_bytesOf]), como em `layout.dart`.
//
// ⚠️ `Local` é UTC (`location.dart`): um offset/nome de zona do valor só
// "casa" com o `Local` quando é offset 0 com o nome `UTC`, como no Go com
// `TZ=UTC`.

/// `*time.ParseError`.
final class ParseError extends GoStruct<ParseError> implements GoError {
  ParseError({
    Golang.String? layout,
    Golang.String? value$,
    Golang.String? layoutElem,
    Golang.String? valueElem,
    Golang.String? message,
  }) : layout = layout ?? Golang.String(),
       value$ = value$ ?? Golang.String(),
       layoutElem = layoutElem ?? Golang.String(),
       valueElem = valueElem ?? Golang.String(),
       message = message ?? Golang.String();

  /// `(*ParseError)(nil)` dentro de uma interface.
  static final ParseError $nil = ParseError()..$nilPtr = true;

  Golang.String layout;
  Golang.String value$;
  Golang.String layoutElem;
  Golang.String valueElem;
  Golang.String message;

  @override
  String get $goType => 'time.ParseError';
  @override
  List<String> get $ptrMethods => const ['Error'];
  @override
  ParseError $copy() => ParseError(
    layout: layout,
    value$: value$,
    layoutElem: layoutElem,
    valueElem: valueElem,
    message: message,
  );
  @override
  void $set(ParseError o) {
    layout = o.layout;
    value$ = o.value$;
    layoutElem = o.layoutElem;
    valueElem = o.valueElem;
    message = o.message;
  }

  @override
  List<Object?> get $fields => [layout, value$, layoutElem, valueElem, message];
  @override
  List<String> get $fieldNames => const [
    'Layout',
    'Value',
    'LayoutElem',
    'ValueElem',
    'Message',
  ];

  /// `Error()`.
  @override
  Golang.String error() {
    final v = _quote(_bytesOf(value$));
    final m = _bytesOf(message);
    if (m.isEmpty) {
      return _fromByteString(
        'parsing time $v as ${_quote(_bytesOf(layout))}: cannot parse '
        '${_quote(_bytesOf(valueElem))} as ${_quote(_bytesOf(layoutElem))}',
      );
    }
    return _fromByteString('parsing time $v$m');
  }
}

ParseError _newParseError(
  String layout,
  String value,
  String layoutElem,
  String valueElem,
  String message,
) => ParseError(
  layout: _fromByteString(layout),
  value$: _fromByteString(value),
  layoutElem: _fromByteString(layoutElem),
  valueElem: _fromByteString(valueElem),
  message: _fromByteString(message),
);

/// `match(s1, s2)`: iguais ignorando caixa (ASCII), mesmo comprimento.
bool _matchFold(String s1, String s2) {
  for (var i = 0; i < s1.length; i++) {
    var c1 = s1.codeUnitAt(i), c2 = s2.codeUnitAt(i);
    if (c1 != c2) {
      c1 |= 0x20;
      c2 |= 0x20;
      if (c1 != c2 || c1 < 0x61 || c1 > 0x7a) return false;
    }
  }
  return true;
}

/// `lookup(tab, val)`: (índice, resto); índice -1 = `errBad`.
(int, String) _lookupName(List<String> tab, String val) {
  for (var i = 0; i < tab.length; i++) {
    final v = tab[i];
    if (val.length >= v.length && _matchFold(val.substring(0, v.length), v)) {
      return (i, val.substring(v.length));
    }
  }
  return (-1, val);
}

/// `atoi(s)`: null = `errAtoi`.
int? _atoi(String s) {
  var neg = false;
  if (s.isNotEmpty && (s[0] == '-' || s[0] == '+')) {
    neg = s[0] == '-';
    s = s.substring(1);
  }
  final (q, rem, ok) = _leadingInt(s);
  if (!ok || rem.isNotEmpty) return null;
  final x = q.toInt();
  return neg ? -x : x;
}

/// `getnum(s, fixed)`: (n, resto) ou null (`errBad`).
(int, String)? _getnum(String s, bool fixed) {
  if (!_isDigitAt(s, 0)) return null;
  if (!_isDigitAt(s, 1)) {
    if (fixed) return null;
    return (s.codeUnitAt(0) - 0x30, s.substring(1));
  }
  return (
    (s.codeUnitAt(0) - 0x30) * 10 + (s.codeUnitAt(1) - 0x30),
    s.substring(2),
  );
}

/// `getnum3(s, fixed)`.
(int, String)? _getnum3(String s, bool fixed) {
  var n = 0, i = 0;
  for (; i < 3 && _isDigitAt(s, i); i++) {
    n = n * 10 + s.codeUnitAt(i) - 0x30;
  }
  if (i == 0 || fixed && i != 3) return null;
  return (n, s.substring(i));
}

String _cutspace(String s) {
  var i = 0;
  while (i < s.length && s.codeUnitAt(i) == 0x20) {
    i++;
  }
  return s.substring(i);
}

/// `skip(value, prefix)`: o resto, ou null (`errBad`).
String? _skip(String value, String prefix) {
  while (prefix.isNotEmpty) {
    if (prefix.codeUnitAt(0) == 0x20) {
      if (value.isNotEmpty && value.codeUnitAt(0) != 0x20) return null;
      prefix = _cutspace(prefix);
      value = _cutspace(value);
      continue;
    }
    if (value.isEmpty || value.codeUnitAt(0) != prefix.codeUnitAt(0)) {
      return null;
    }
    prefix = prefix.substring(1);
    value = value.substring(1);
  }
  return value;
}

bool _commaOrPeriod(int b) => b == 0x2e || b == 0x2c;

/// `parseNanoseconds(value, nbytes)`: (ns, rangeErrString, ok).
(int, String, bool) _parseNanoseconds(String value, int nbytes) {
  if (!_commaOrPeriod(value.codeUnitAt(0))) return (0, '', false);
  if (nbytes > 10) {
    value = value.substring(0, 10);
    nbytes = 10;
  }
  final n = _atoi(value.substring(1, nbytes));
  if (n == null) return (0, '', false);
  if (n < 0) return (n, 'fractional second', true);
  var ns = n;
  for (var i = 0; i < 10 - nbytes; i++) {
    ns *= 10;
  }
  return (ns, '', true);
}

/// `parseSignedOffset(value)`: comprimento, 0 se inválido.
int _parseSignedOffset(String value) {
  final sign = value.codeUnitAt(0);
  if (sign != 0x2d && sign != 0x2b) return 0;
  final (x, rem, ok) = _leadingInt(value.substring(1));
  if (!ok || value.length - 1 == rem.length) return 0;
  if (x > Golang.Uint64(23)) return 0;
  return value.length - rem.length;
}

/// `parseTimeZone(value)`: comprimento, ou null se não parece zona.
int? _parseTimeZone(String value) {
  if (value.length < 3) return null;
  if (value.length >= 4 &&
      (value.startsWith('ChST') || value.startsWith('MeST'))) {
    return 4;
  }
  if (value.startsWith('GMT')) {
    final rest = value.substring(3);
    return rest.isEmpty ? 3 : 3 + _parseSignedOffset(rest);
  }
  final c0 = value.codeUnitAt(0);
  if (c0 == 0x2b || c0 == 0x2d) {
    final n = _parseSignedOffset(value);
    return n > 0 ? n : null;
  }
  var nUpper = 0;
  for (; nUpper < 6; nUpper++) {
    if (nUpper >= value.length) break;
    final c = value.codeUnitAt(nUpper);
    if (c < 0x41 || 0x5a < c) break;
  }
  switch (nUpper) {
    case 5:
      if (value[4] == 'T') return 5;
    case 4:
      if (value[3] == 'T' || value.startsWith('WITA')) return 4;
    case 3:
      return 3;
  }
  return null;
}

bool _isLeap(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

/// `daysBefore(m)`: dias de um ano não bissexto antes do mês m (1..13).
int _daysBefore(int m) => (214 * m - 211) ~/ 7 + (m >= 3 ? -2 : 0);

/// `daysIn(m, year)`.
int _daysIn(int m, int year) {
  if (m == 2) return _isLeap(year) ? 29 : 28;
  return 30 + ((m + (m >> 3)) & 1);
}

/// `parseRFC3339(s, local)`: null = não é RFC 3339 estrito (cai no `parse`).
Time? _parseRFC3339(String s, Location? local) {
  var ok = true;
  int parseUint(String s, int min, int max) {
    var x = 0;
    for (final c in s.codeUnits) {
      if (c < 0x30 || 0x39 < c) {
        ok = false;
        return min;
      }
      x = x * 10 + c - 0x30;
    }
    if (x < min || max < x) {
      ok = false;
      return min;
    }
    return x;
  }

  if (s.length < 19) return null;
  final year = parseUint(s.substring(0, 4), 0, 9999);
  final month = parseUint(s.substring(5, 7), 1, 12);
  final day = parseUint(s.substring(8, 10), 1, _daysIn(month, year));
  final hour = parseUint(s.substring(11, 13), 0, 23);
  final min = parseUint(s.substring(14, 16), 0, 59);
  final sec = parseUint(s.substring(17, 19), 0, 59);
  if (!ok ||
      !(s[4] == '-' &&
          s[7] == '-' &&
          s[10] == 'T' &&
          s[13] == ':' &&
          s[16] == ':')) {
    return null;
  }
  s = s.substring(19);

  var nsec = 0;
  if (s.length >= 2 && s[0] == '.' && _isDigitAt(s, 1)) {
    var n = 2;
    while (n < s.length && _isDigitAt(s, n)) {
      n++;
    }
    (nsec, _, _) = _parseNanoseconds(s, n);
    s = s.substring(n);
  }

  final t = _dateImpl(year, month, day, hour, min, sec, nsec, _utcSentinel);
  if (s.length != 1 || s[0] != 'Z') {
    if (s.length != 6) return null;
    final hr = parseUint(s.substring(1, 3), 0, 23);
    final mm = parseUint(s.substring(4, 6), 0, 59);
    if (!ok || !((s[0] == '-' || s[0] == '+') && s[3] == ':')) return null;
    var zoneOffset = (hr * 60 + mm) * 60;
    if (s[0] == '-') zoneOffset = -zoneOffset;
    t._addSecs(Golang.Int64(-zoneOffset));
    final (_, offset) = (local ?? _utcSentinel)._lookup();
    t._setLocation(offset == zoneOffset ? local : Location._('', zoneOffset));
  }
  return t;
}

/// `parseStrictRFC3339(b)` (a validação estrita extra do Go está
/// desligada no 1.26: só cai no `Parse(RFC3339, ...)`).
(Time, GoError?) _parseStrictRFC3339(String b) {
  final t = _parseRFC3339(b, _localSentinel);
  if (t != null) return (t, null);
  return _parseBytes(_rfc3339, b, _utcSentinel, _localSentinel);
}

/// `time.Parse(layout, value)`.
(Time, GoError?) parse(Golang.String layout, Golang.String value) {
  final l = _bytesOf(layout), v = _bytesOf(value);
  if (l == _rfc3339 || l == _rfc3339Nano) {
    final t = _parseRFC3339(v, _localSentinel);
    if (t != null) return (t, null);
  }
  return _parseBytes(l, v, _utcSentinel, _localSentinel);
}

/// `time.ParseInLocation(layout, value, loc)`.
(Time, GoError?) parseInLocation(
  Golang.String layout,
  Golang.String value,
  Location? loc,
) {
  final l = _bytesOf(layout), v = _bytesOf(value);
  if (l == _rfc3339 || l == _rfc3339Nano) {
    final t = _parseRFC3339(v, loc);
    if (t != null) return (t, null);
  }
  return _parseBytes(l, v, loc, loc);
}
