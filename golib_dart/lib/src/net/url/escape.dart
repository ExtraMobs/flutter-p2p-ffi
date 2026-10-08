part of '../../../net/url.dart';

// Modos de codificação (`encoding` de `encoding_table.go`): um bit por modo;
// o bit está ligado na tabela quando o byte NÃO precisa de escape.
const _encodePath = 1,
    _encodePathSegment = 2,
    _encodeHost = 4,
    _encodeZone = 8,
    _encodeUserPassword = 16,
    _encodeQueryComponent = 32,
    _encodeFragment = 64,
    _hexChar = 128;

/// `table` de `encoding_table.go` (Go 1.26.5); só ASCII tem bits.
const _table = <int>[
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x4c, 0x0c, 0x00, 0x5f, 0x00, 0x5f, 0x0c,
  0x4c, 0x4c, 0x4c, 0x5f, 0x5d, 0x7f, 0x7f, 0x41,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0x4f, 0x5d, 0x0c, 0x5f, 0x0c, 0x40,
  0x43, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f,
  0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
  0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
  0x7f, 0x7f, 0x7f, 0x0c, 0x00, 0x0c, 0x00, 0x7f,
  0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f,
  0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
  0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
  0x7f, 0x7f, 0x7f, 0x00, 0x00, 0x00, 0x7f, 0x00,
];

int _tbl(int c) => c < 0x80 ? _table[c] : 0;

bool _ishex(int c) => _tbl(c) & _hexChar != 0;

int _unhex(int c) => 9 * (c >> 6) + (c & 15);

bool _shouldEscape(int c, int mode) => _tbl(c) & mode == 0;

const _upperhex = '0123456789ABCDEF';

/// `url.EscapeError`.
final class EscapeError extends Golang.StringBase<EscapeError>
    implements GoError, Golang.GoTyped {
  EscapeError([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;
  @override
  EscapeError $wrapStr(Golang.String s) => EscapeError(s);
  @override
  String get $goType => 'url.EscapeError';
  @override
  List<String> get $methods => const ['Error'];

  /// `Error()`: `invalid URL escape "%zz"`.
  @override
  Golang.String error() => _gs('invalid URL escape ') + strconv.quote(_v);
}

/// `url.InvalidHostError`.
final class InvalidHostError extends Golang.StringBase<InvalidHostError>
    implements GoError, Golang.GoTyped {
  InvalidHostError([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;
  @override
  InvalidHostError $wrapStr(Golang.String s) => InvalidHostError(s);
  @override
  String get $goType => 'url.InvalidHostError';
  @override
  List<String> get $methods => const ['Error'];

  /// `Error()`: `invalid character " " in host name`.
  @override
  Golang.String error() =>
      _gs('invalid character ') + strconv.quote(_v) + _gs(' in host name');
}

/// `QueryUnescape(s)`: desfaz `%XX` e troca `+` por espaço.
(Golang.String, GoError?) queryUnescape(Golang.String s) =>
    _unescape(s, _encodeQueryComponent);

/// `PathUnescape(s)`: desfaz `%XX`; `+` continua `+`.
(Golang.String, GoError?) pathUnescape(Golang.String s) =>
    _unescape(s, _encodePathSegment);

(Golang.String, GoError?) _unescape(Golang.String s, int mode) {
  var n = 0;
  var hasPlus = false;
  final pct25 = _gs('%25');
  for (var i = 0; i < s.length;) {
    switch (s[i]) {
      case 0x25: // '%'
        n++;
        if (i + 2 >= s.length || !_ishex(s[i + 1]) || !_ishex(s[i + 2])) {
          s = s.slice(i);
          if (s.length > 3) s = s.slice(0, 3);
          return (Golang.String(), EscapeError(s));
        }
        if (mode == _encodeHost &&
            _unhex(s[i + 1]) < 8 &&
            s.slice(i, i + 3) != pct25) {
          return (Golang.String(), EscapeError(s.slice(i, i + 3)));
        }
        if (mode == _encodeZone) {
          final v = (_unhex(s[i + 1]) << 4 | _unhex(s[i + 2])) & 0xff;
          if (s.slice(i, i + 3) != pct25 &&
              v != 0x20 &&
              _shouldEscape(v, _encodeHost)) {
            return (Golang.String(), EscapeError(s.slice(i, i + 3)));
          }
        }
        i += 3;
      case 0x2b: // '+'
        hasPlus = mode == _encodeQueryComponent;
        i++;
      default:
        if ((mode == _encodeHost || mode == _encodeZone) &&
            s[i] < 0x80 &&
            _shouldEscape(s[i], mode)) {
          return (Golang.String(), InvalidHostError(s.slice(i, i + 1)));
        }
        i++;
    }
  }
  if (n == 0 && !hasPlus) return (s, null);
  final plus = mode == _encodeQueryComponent ? 0x20 : 0x2b;
  final t = BytesBuilder(copy: false);
  for (var i = 0; i < s.length; i++) {
    switch (s[i]) {
      case 0x25:
        t.addByte((_unhex(s[i + 1]) << 4 | _unhex(s[i + 2])) & 0xff);
        i += 2;
      case 0x2b:
        t.addByte(plus);
      default:
        t.addByte(s[i]);
    }
  }
  return (Golang.String.fromBytes(t.takeBytes()), null);
}

/// `QueryEscape(s)`: escapa para um componente de query (espaço → `+`).
Golang.String queryEscape(Golang.String s) => _escape(s, _encodeQueryComponent);

/// `PathEscape(s)`: escapa para um segmento de caminho (espaço → `%20`).
Golang.String pathEscape(Golang.String s) => _escape(s, _encodePathSegment);

Golang.String _escape(Golang.String s, int mode) {
  var spaceCount = 0, hexCount = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (_shouldEscape(c, mode)) {
      if (c == 0x20 && mode == _encodeQueryComponent) {
        spaceCount++;
      } else {
        hexCount++;
      }
    }
  }
  if (spaceCount == 0 && hexCount == 0) return s;
  final t = Uint8List(s.length + 2 * hexCount);
  var j = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == 0x20 && mode == _encodeQueryComponent) {
      t[j++] = 0x2b;
    } else if (_shouldEscape(c, mode)) {
      t[j] = 0x25;
      t[j + 1] = _upperhex.codeUnitAt(c >> 4);
      t[j + 2] = _upperhex.codeUnitAt(c & 15);
      j += 3;
    } else {
      t[j++] = c;
    }
  }
  return Golang.String.fromBytes(t);
}

/// `validEncoded(s, mode)`: só bytes que dispensam escape (ou `%`, e os
/// sub-delims do RFC 3986).
bool _validEncoded(Golang.String s, int mode) {
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if ("!\$&'()*+,;=:@[]%".codeUnits.contains(c)) continue;
    if (_shouldEscape(c, mode)) return false;
  }
  return true;
}
