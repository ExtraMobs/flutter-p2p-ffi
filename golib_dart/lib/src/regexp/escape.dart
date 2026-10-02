part of '../../regexp.dart';

/// Cursor sobre as runas do padrão (já validado como UTF-8).
class _Cur {
  _Cur(this.s);

  final List<int> s;
  int i = 0;

  bool get eof => i >= s.length;
  int get peek => s[i];
  bool at(int k, int c) => i + k < s.length && s[i + k] == c;
  int get left => s.length - i;

  String text(int from, [int? to]) =>
      String.fromCharCodes(s.sublist(from, to ?? i));
}

bool _isAlnum(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a);

int _unhex(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  return -1;
}

/// `parseEscape` do Go: `cur.i` está na `\`; devolve a runa e avança.
int _parseEscape(_Cur cur) {
  final start = cur.i;
  Never bad() => throw _SyntaxError('invalid escape sequence', cur.text(start));
  cur.i++;
  if (cur.eof)
    throw _SyntaxError('trailing backslash at end of expression', '');
  final c = cur.s[cur.i++];
  bool octal() => !cur.eof && cur.peek >= 0x30 && cur.peek <= 0x37;
  switch (c) {
    case >= 0x31 && <= 0x37 when octal():
    case 0x30:
      var r = c - 0x30;
      for (var k = 1; k < 3; k++) {
        if (!octal()) break;
        r = r * 8 + cur.s[cur.i++] - 0x30;
      }
      return r;
    case 0x78: // \x
      if (cur.eof) bad();
      var d = cur.s[cur.i++];
      if (d == 0x7b) {
        var nhex = 0, r = 0;
        while (true) {
          if (cur.eof) bad();
          d = cur.s[cur.i++];
          if (d == 0x7d) break;
          final v = _unhex(d);
          if (v < 0) bad();
          r = r * 16 + v;
          if (r > _maxRune) bad();
          nhex++;
        }
        if (nhex == 0) bad();
        return r;
      }
      final x = _unhex(d);
      if (cur.eof) bad();
      final y = _unhex(cur.s[cur.i++]);
      if (x < 0 || y < 0) bad();
      return x * 16 + y;
    case 0x61:
      return 7;
    case 0x66:
      return 12;
    case 0x6e:
      return 10;
    case 0x72:
      return 13;
    case 0x74:
      return 9;
    case 0x76:
      return 11;
  }
  if (c < 0x80 && !_isAlnum(c)) return c;
  bad();
}
