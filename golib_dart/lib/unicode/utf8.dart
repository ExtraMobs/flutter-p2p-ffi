/// Shim do pacote Go `unicode/utf8` (as constantes vêm dobradas pelo g2d).
/// Decodificação com as regras do Go: byte inválido, sequência curta,
/// overlong, surrogate ou acima de U+10FFFF dão (U+FFFD, 1).
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;

typedef _Bytes = Slice<Golang.Uint8>;

const int _runeError = 0xfffd;
const int _maxRune = 0x10ffff;

// (tamanho, limites do 2º byte) do 1º byte `c0` (a tabela `first` do Go);
// tamanho 0 = byte inválido como início.
(int, int, int) _lead(int c0) {
  if (c0 < 0x80) return (1, 0, 0);
  if (c0 >= 0xc2 && c0 <= 0xdf) return (2, 0x80, 0xbf);
  if (c0 == 0xe0) return (3, 0xa0, 0xbf);
  if (c0 == 0xed) return (3, 0x80, 0x9f);
  if (c0 >= 0xe1 && c0 <= 0xef) return (3, 0x80, 0xbf);
  if (c0 == 0xf0) return (4, 0x90, 0xbf);
  if (c0 >= 0xf1 && c0 <= 0xf3) return (4, 0x80, 0xbf);
  if (c0 == 0xf4) return (4, 0x80, 0x8f);
  return (0, 0, 0);
}

// DecodeRune sobre bytes at(0..n-1); n > 0.
(int, int) _decode(int Function(int) at, int n) {
  final c0 = at(0);
  final (size, lo, hi) = _lead(c0);
  if (size == 1) return (c0, 1);
  if (size == 0 || n < size) return (_runeError, 1);
  final c1 = at(1);
  if (c1 < lo || c1 > hi) return (_runeError, 1);
  var r = (c0 & (0xff >> (size + 1))) << 6 | (c1 & 0x3f);
  for (var k = 2; k < size; k++) {
    final c = at(k);
    if (c & 0xc0 != 0x80) return (_runeError, 1);
    r = r << 6 | (c & 0x3f);
  }
  return (r, size);
}

// DecodeLastRune sobre bytes at(0..n-1).
(int, int) _decodeLast(int Function(int) at, int n) {
  if (n == 0) return (_runeError, 0);
  var start = n - 1;
  final r = at(start);
  if (r < 0x80) return (r, 1);
  final lim = n - 4 < 0 ? 0 : n - 4;
  for (start--; start >= lim; start--) {
    if (at(start) & 0xc0 != 0x80) break;
  }
  if (start < 0) start = 0;
  final s = start;
  final (rr, size) = _decode((i) => at(s + i), n - s);
  if (s + size != n) return (_runeError, 1);
  return (rr, size);
}

int Function(int) _ofBytes(_Bytes p) =>
    (i) => p[i].toInt();

(Golang.Int32, Golang.Int) _pair((int, int) v) =>
    (Golang.Int32(v.$1), Golang.Int(v.$2));

/// `utf8.DecodeRune(p)`: (U+FFFD, 0) se vazio.
(Golang.Int32, Golang.Int) decodeRune(_Bytes p) => p.length == 0
    ? (Golang.Int32(_runeError), Golang.Int(0))
    : _pair(_decode(_ofBytes(p), p.length));

/// `utf8.DecodeRuneInString(s)`.
(Golang.Int32, Golang.Int) decodeRuneInString(Golang.String s) => s.length == 0
    ? (Golang.Int32(_runeError), Golang.Int(0))
    : _pair(s.decodeRune(0));

/// `utf8.DecodeLastRune(p)`.
(Golang.Int32, Golang.Int) decodeLastRune(_Bytes p) =>
    _pair(_decodeLast(_ofBytes(p), p.length));

/// `utf8.DecodeLastRuneInString(s)`.
(Golang.Int32, Golang.Int) decodeLastRuneInString(Golang.String s) =>
    _pair(_decodeLast((i) => s[i], s.length));

/// `utf8.FullRune(p)`: o início de p é uma runa completa (válida ou não:
/// inválida conta como runa de 1 byte).
bool fullRune(_Bytes p) => _full(_ofBytes(p), p.length);

/// `utf8.FullRuneInString(s)`.
bool fullRuneInString(Golang.String s) => _full((i) => s[i], s.length);

bool _full(int Function(int) at, int n) {
  if (n == 0) return false;
  final (size, lo, hi) = _lead(at(0));
  if (size <= 1 || n >= size) return true;
  if (n > 1 && (at(1) < lo || hi < at(1))) return true;
  if (n > 2 && (at(2) < 0x80 || 0xbf < at(2))) return true;
  return false;
}

/// `utf8.RuneLen(r)`: -1 se r não pode ser codificado.
Golang.Int runeLen(Golang.Int32 r) {
  final v = r.toInt();
  if (v < 0) return Golang.Int(-1);
  if (v < 0x80) return Golang.Int(1);
  if (v < 0x800) return Golang.Int(2);
  if (v >= 0xd800 && v <= 0xdfff) return Golang.Int(-1);
  if (v < 0x10000) return Golang.Int(3);
  if (v <= _maxRune) return Golang.Int(4);
  return Golang.Int(-1);
}

// Os bytes UTF-8 de r (U+FFFD se inválido).
List<int> _encode(int r) {
  if (r >= 0 && r < 0x80) return [r];
  if (r >= 0x80 && r < 0x800) return [0xc0 | r >> 6, 0x80 | r & 0x3f];
  if (r < 0 || r > _maxRune || (r >= 0xd800 && r <= 0xdfff)) r = _runeError;
  if (r < 0x10000) {
    return [0xe0 | r >> 12, 0x80 | (r >> 6) & 0x3f, 0x80 | r & 0x3f];
  }
  return [
    0xf0 | r >> 18,
    0x80 | (r >> 12) & 0x3f,
    0x80 | (r >> 6) & 0x3f,
    0x80 | r & 0x3f,
  ];
}

/// `utf8.EncodeRune(p, r)`: bytes escritos; p curto dá o pânico de índice
/// do último byte, como a dica de bounds check do Go.
Golang.Int encodeRune(_Bytes p, Golang.Int32 r) {
  final bs = _encode(r.toInt());
  p[bs.length - 1];
  for (var i = 0; i < bs.length; i++) {
    p[i] = Golang.Uint8(bs[i]);
  }
  return Golang.Int(bs.length);
}

/// `utf8.AppendRune(p, r)`.
_Bytes appendRune(_Bytes p, Golang.Int32 r) =>
    p.append([for (final b in _encode(r.toInt())) Golang.Uint8(b)]);

int _count(int Function(int) at, int n) {
  var runes = 0;
  for (var i = 0; i < n; runes++) {
    final (_, size) = _decode((k) => at(i + k), n - i);
    i += size;
  }
  return runes;
}

/// `utf8.RuneCount(p)`: bytes inválidos contam como uma runa cada.
Golang.Int runeCount(_Bytes p) => Golang.Int(_count(_ofBytes(p), p.length));

/// `utf8.RuneCountInString(s)`.
Golang.Int runeCountInString(Golang.String s) =>
    Golang.Int(_count((i) => s[i], s.length));

/// `utf8.RuneStart(b)`: b pode iniciar uma runa (não é continuação).
bool runeStart(Golang.Uint8 b) => b.toInt() & 0xc0 != 0x80;

bool _valid(int Function(int) at, int n) {
  for (var i = 0; i < n;) {
    final (r, size) = _decode((k) => at(i + k), n - i);
    if (r == _runeError && size == 1) return false;
    i += size;
  }
  return true;
}

/// `utf8.Valid(p)`.
bool valid(_Bytes p) => _valid(_ofBytes(p), p.length);

/// `utf8.ValidString(s)`.
bool validString(Golang.String s) => _valid((i) => s[i], s.length);

/// `utf8.ValidRune(r)`.
bool validRune(Golang.Int32 r) {
  final v = r.toInt();
  return (v >= 0 && v < 0xd800) || (v > 0xdfff && v <= _maxRune);
}
