part of '../../time.dart';

const _lowerhex = '0123456789abcdef';

/// `quote(s)` de `time/format.go`: como `strconv.Quote`, mas sem depender de
/// `strconv` — byte a byte para os que não são ASCII imprimível (`>= 0x80`
/// ou controle `< 0x20`), usados nas mensagens de `ParseError` e
/// `ParseDuration`.
String _quote(String s) {
  final buf = StringBuffer()..write('"');
  for (final c in s.runes) {
    if (c >= 0x80 || c < 0x20) {
      for (final b in utf8.encode(String.fromCharCode(c))) {
        buf
          ..write(r'\x')
          ..write(_lowerhex[(b >> 4) & 0xf])
          ..write(_lowerhex[b & 0xf]);
      }
    } else if (c == 0x22 || c == 0x5c) {
      buf
        ..write('\\')
        ..writeCharCode(c);
    } else {
      buf.writeCharCode(c);
    }
  }
  buf.write('"');
  return buf.toString();
}
