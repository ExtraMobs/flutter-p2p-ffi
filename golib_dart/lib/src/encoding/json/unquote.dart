part of '../../../encoding/json.dart';

// `decode.go` (`unquote`): o conteúdo das strings JSON sem os escapes.

bool _eq(List<int> b, String s) {
  if (b.length != s.length) return false;
  for (var i = 0; i < b.length; i++) {
    if (b[i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

/// `getu4`: o `\uXXXX` em s[i:], ou -1.
int _getu4(List<int> s, int i) {
  if (s.length - i < 6 || s[i] != 0x5c || s[i + 1] != 0x75) return -1;
  var r = 0;
  for (var k = i + 2; k < i + 6; k++) {
    var c = s[k];
    if (_isDigit(c)) {
      c -= 0x30;
    } else if (c >= 0x61 && c <= 0x66) {
      c = c - 0x61 + 10;
    } else if (c >= 0x41 && c <= 0x46) {
      c = c - 0x41 + 10;
    } else {
      return -1;
    }
    r = r * 16 + c;
  }
  return r;
}

/// `unquoteBytes`: o conteúdo da string JSON entre aspas, sem os escapes
/// (surrogates em par viram a runa; soltos e UTF-8 inválido, U+FFFD); null
/// se não é uma string JSON válida.
Uint8List? _unquoteBytes(Uint8List s0) {
  if (s0.length < 2 || s0[0] != 0x22 || s0[s0.length - 1] != 0x22) {
    return null;
  }
  final s = Uint8List.sublistView(s0, 1, s0.length - 1);

  var r = 0;
  while (r < s.length) {
    final c = s[r];
    if (c == 0x5c || c == 0x22 || c < 0x20) break;
    if (c < 0x80) {
      r++;
      continue;
    }
    final (rr, size) = _decodeRune(s, r);
    if (rr == _runeError && size == 1) break;
    r += size;
  }
  if (r == s.length) return s;

  final b = <int>[...s.sublist(0, r)];
  while (r < s.length) {
    final c = s[r];
    if (c == 0x5c) {
      r++;
      if (r >= s.length) return null;
      switch (s[r]) {
        case 0x22 || 0x5c || 0x2f || 0x27:
          b.add(s[r]);
          r++;
        case 0x62:
          b.add(0x08);
          r++;
        case 0x66:
          b.add(0x0c);
          r++;
        case 0x6e:
          b.add(0x0a);
          r++;
        case 0x72:
          b.add(0x0d);
          r++;
        case 0x74:
          b.add(0x09);
          r++;
        case 0x75:
          r--;
          var rr = _getu4(s, r);
          if (rr < 0) return null;
          r += 6;
          if (rr >= 0xd800 && rr < 0xe000) {
            final rr1 = _getu4(s, r);
            if (rr < 0xdc00 && rr1 >= 0xdc00 && rr1 < 0xe000) {
              r += 6;
              _appendRune(b, ((rr - 0xd800) << 10 | (rr1 - 0xdc00)) + 0x10000);
              break;
            }
            rr = _runeError;
          }
          _appendRune(b, rr);
        default:
          return null;
      }
    } else if (c == 0x22 || c < 0x20) {
      return null;
    } else if (c < 0x80) {
      b.add(c);
      r++;
    } else {
      final (rr, size) = _decodeRune(s, r);
      r += size;
      _appendRune(b, rr);
    }
  }
  return Uint8List.fromList(b);
}
