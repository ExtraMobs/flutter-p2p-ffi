part of '../../../encoding/json.dart';

// `appendString` de `encode.go` e a decodificação UTF-8 do Go que ele e o
// `unquote` usam (byte inválido, curto, overlong, surrogate ou acima de
// U+10FFFF → (U+FFFD, 1)).

const _runeError = 0xfffd;

/// `utf8.DecodeRune(s[i:end])`: (runa, largura).
(int, int) _decodeRune(List<int> s, int i, [int? end]) {
  final n = (end ?? s.length) - i;
  if (n < 1) return (_runeError, 0);
  final c0 = s[i];
  if (c0 < 0x80) return (c0, 1);
  int need, lo = 0x80, hi = 0xbf, r;
  if (c0 >= 0xc2 && c0 <= 0xdf) {
    need = 1;
    r = c0 & 0x1f;
  } else if (c0 >= 0xe0 && c0 <= 0xef) {
    need = 2;
    r = c0 & 0x0f;
    if (c0 == 0xe0) lo = 0xa0;
    if (c0 == 0xed) hi = 0x9f;
  } else if (c0 >= 0xf0 && c0 <= 0xf4) {
    need = 3;
    r = c0 & 0x07;
    if (c0 == 0xf0) lo = 0x90;
    if (c0 == 0xf4) hi = 0x8f;
  } else {
    return (_runeError, 1);
  }
  if (n < need + 1) {
    // Curto: só é inválido de 1 byte (o Go devolve (RuneError, 1)).
    return (_runeError, 1);
  }
  final c1 = s[i + 1];
  if (c1 < lo || c1 > hi) return (_runeError, 1);
  r = (r << 6) | (c1 & 0x3f);
  for (var k = 2; k <= need; k++) {
    final c = s[i + k];
    if (c < 0x80 || c > 0xbf) return (_runeError, 1);
    r = (r << 6) | (c & 0x3f);
  }
  return (r, need + 1);
}

/// `utf8.AppendRune` (surrogate ou fora do intervalo → U+FFFD).
void _appendRune(List<int> dst, int r) {
  if (r < 0 || r > 0x10ffff || (r >= 0xd800 && r <= 0xdfff)) r = _runeError;
  if (r < 0x80) {
    dst.add(r);
  } else if (r < 0x800) {
    dst.add(0xc0 | (r >> 6));
    dst.add(0x80 | (r & 0x3f));
  } else if (r < 0x10000) {
    dst.add(0xe0 | (r >> 12));
    dst.add(0x80 | ((r >> 6) & 0x3f));
    dst.add(0x80 | (r & 0x3f));
  } else {
    dst.add(0xf0 | (r >> 18));
    dst.add(0x80 | ((r >> 12) & 0x3f));
    dst.add(0x80 | ((r >> 6) & 0x3f));
    dst.add(0x80 | (r & 0x3f));
  }
}

/// ASCII que sai sem escape: `safeSet` (de 0x20 a 0x7f menos `"` e `\`) e,
/// com escape HTML, `htmlSafeSet` (também sem `<`, `>` e `&`).
bool _safe(int b, bool escapeHTML) {
  if (b < 0x20 || b == 0x22 || b == 0x5c) return false;
  if (escapeHTML && (b == 0x3c || b == 0x3e || b == 0x26)) return false;
  return true;
}

/// `appendString`: [src] entre aspas, com os escapes do Go.
void _appendString(List<int> dst, List<int> src, bool escapeHTML) {
  dst.add(0x22);
  var start = 0;
  var i = 0;
  while (i < src.length) {
    final b = src[i];
    if (b < 0x80) {
      if (_safe(b, escapeHTML)) {
        i++;
        continue;
      }
      dst.addAll(src.sublist(start, i));
      switch (b) {
        case 0x5c || 0x22:
          dst.addAll([0x5c, b]);
        case 0x08:
          dst.addAll([0x5c, 0x62]);
        case 0x0c:
          dst.addAll([0x5c, 0x66]);
        case 0x0a:
          dst.addAll([0x5c, 0x6e]);
        case 0x0d:
          dst.addAll([0x5c, 0x72]);
        case 0x09:
          dst.addAll([0x5c, 0x74]);
        default:
          _escapeHTMLByte(dst, b);
      }
      i++;
      start = i;
      continue;
    }
    final (c, size) = _decodeRune(
      src,
      i,
      i + 4 > src.length ? src.length : i + 4,
    );
    if (c == _runeError && size == 1) {
      dst.addAll(src.sublist(start, i));
      dst.addAll(const [0x5c, 0x75, 0x66, 0x66, 0x66, 0x64]); // `\ufffd`
      i += size;
      start = i;
      continue;
    }
    if (c == 0x2028 || c == 0x2029) {
      dst.addAll(src.sublist(start, i));
      dst.addAll([0x5c, 0x75, 0x32, 0x30, 0x32]);
      dst.add(_hex.codeUnitAt(c & 0xf));
      i += size;
      start = i;
      continue;
    }
    i += size;
  }
  dst.addAll(src.sublist(start));
  dst.add(0x22);
}
