/// Decodificação UTF-8 do Go que falta no `Golang.String` (lado do fim).
// ignore_for_file: library_prefixes
library;

import '../../fixed_types/golang.dart' as Golang;

/// `utf8.DecodeLastRuneInString(s[:end])`: (rune, largura), como o Go.
(int, int) decodeLastRune(Golang.String s, int end) {
  var start = end - 1;
  if (s[start] < 0x80) return (s[start], 1);
  final lim = end - 4 < 0 ? 0 : end - 4;
  for (start--; start >= lim; start--) {
    if (s[start] & 0xc0 != 0x80) break;
  }
  if (start < 0) start = 0;
  final (r, size) = s.slice(0, end).decodeRune(start);
  return start + size != end ? (0xfffd, 1) : (r, size);
}
