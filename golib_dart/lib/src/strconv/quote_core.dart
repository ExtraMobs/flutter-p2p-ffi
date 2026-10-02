/// Núcleo de `strconv.Quote`/`CanBackquote` e da decodificação de runas do
/// Go; compartilhado por `fmt` (`%q`) e `strconv`.
library;

import 'dart:convert';

import '../unicode/isprint.dart';

const _hexLower = '0123456789abcdef';

List<int> _ascii(String s) => s.codeUnits;

int validRune(int r) =>
    r < 0 || r > 0x10ffff || (r >= 0xd800 && r <= 0xdfff) ? 0xfffd : r;

/// Runa UTF-8 em `s[i]`: (runa, largura); inválida → (U+FFFD, 1).
(int, int) decodeRune(List<int> s, int i) {
  final c = s[i];
  if (c < 0x80) return (c, 1);
  final int need, min;
  var r = 0;
  if (c >= 0xc2 && c <= 0xdf) {
    need = 1;
    min = 0x80;
    r = c & 0x1f;
  } else if (c >= 0xe0 && c <= 0xef) {
    need = 2;
    min = 0x800;
    r = c & 0x0f;
  } else if (c >= 0xf0 && c <= 0xf4) {
    need = 3;
    min = 0x10000;
    r = c & 0x07;
  } else {
    return (0xfffd, 1);
  }
  if (i + need >= s.length) return (0xfffd, 1);
  for (var k = 1; k <= need; k++) {
    final b = s[i + k];
    if (b & 0xc0 != 0x80) return (0xfffd, 1);
    r = (r << 6) | (b & 0x3f);
  }
  if (r < min || r > 0x10ffff || (r >= 0xd800 && r <= 0xdfff)) {
    return (0xfffd, 1);
  }
  return (r, need + 1);
}

int runeCount(List<int> s) {
  var n = 0;
  for (var i = 0; i < s.length; i += decodeRune(s, i).$2) {
    n++;
  }
  return n;
}

/// `strconv.Quote` (`quote` = `"`) / `QuoteRune` (`'`); `ascii`: as versões
/// `...ToASCII`. Byte inválido vira `\xNN`.
List<int> quoteBytes(List<int> s, int quote, bool ascii) {
  final out = <int>[quote];
  for (var i = 0; i < s.length;) {
    final (r, w) = decodeRune(s, i);
    if (w == 1 && s[i] >= 0x80) {
      out.addAll(_ascii('\\x'));
      out.add(_hexLower.codeUnitAt(s[i] >> 4));
      out.add(_hexLower.codeUnitAt(s[i] & 0xf));
      i++;
      continue;
    }
    i += w;
    if (r == quote || r == 0x5c) {
      out.addAll([0x5c, r]);
    } else if (ascii ? r < 0x80 && isPrint(r) : isPrint(r)) {
      out.addAll(utf8.encode(String.fromCharCode(r)));
    } else {
      switch (r) {
        case 0x07:
          out.addAll(_ascii(r'\a'));
        case 0x08:
          out.addAll(_ascii(r'\b'));
        case 0x0c:
          out.addAll(_ascii(r'\f'));
        case 0x0a:
          out.addAll(_ascii(r'\n'));
        case 0x0d:
          out.addAll(_ascii(r'\r'));
        case 0x09:
          out.addAll(_ascii(r'\t'));
        case 0x0b:
          out.addAll(_ascii(r'\v'));
        default:
          if (r < 0x20 || r == 0x7f) {
            out.addAll(_ascii('\\x${r.toRadixString(16).padLeft(2, '0')}'));
          } else if (r < 0x10000) {
            out.addAll(_ascii('\\u${r.toRadixString(16).padLeft(4, '0')}'));
          } else {
            out.addAll(_ascii('\\U${r.toRadixString(16).padLeft(8, '0')}'));
          }
      }
    }
  }
  out.add(quote);
  return out;
}

/// `strconv.CanBackquote`.
bool canBackquote(List<int> s) {
  for (var i = 0; i < s.length;) {
    final (r, w) = decodeRune(s, i);
    if (w == 1 && s[i] >= 0x80) return false;
    i += w;
    if (r == 0xfeff || r == 0x60 || (r < 0x20 && r != 0x09) || r == 0x7f) {
      return false;
    }
  }
  return true;
}
