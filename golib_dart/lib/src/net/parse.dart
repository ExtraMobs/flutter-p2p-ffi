part of '../../net.dart';

// Auxiliares de `parse.go` e `ip.go`.

const _hexDigit = '0123456789abcdef';

/// `big`: limite de `dtoi`/`xtoi`.
const _big = 0xFFFFFF;

/// `dtoi(s)`: (número, bytes consumidos, ok).
(int, int, bool) _dtoi(Golang.String s) {
  var n = 0, i = 0;
  for (; i < s.length && 0x30 <= s[i] && s[i] <= 0x39; i++) {
    n = n * 10 + s[i] - 0x30;
    if (n >= _big) return (_big, i, false);
  }
  if (i == 0) return (0, 0, false);
  return (n, i, true);
}

/// `xtoi(s)`: (número, bytes consumidos, ok).
(int, int, bool) _xtoi(Golang.String s) {
  var n = 0, i = 0;
  for (; i < s.length; i++) {
    final c = s[i];
    if (0x30 <= c && c <= 0x39) {
      n = n * 16 + c - 0x30;
    } else if (0x61 <= c && c <= 0x66) {
      n = n * 16 + c - 0x61 + 10;
    } else if (0x41 <= c && c <= 0x46) {
      n = n * 16 + c - 0x41 + 10;
    } else {
      break;
    }
    if (n >= _big) return (0, i, false);
  }
  if (i == 0) return (0, i, false);
  return (n, i, true);
}

/// `xtoi2(s, e)`: dois dígitos hex seguidos de `e` (ou do fim).
(int, bool) _xtoi2(Golang.String s, int e) {
  if (s.length > 2 && s[2] != e) return (0, false);
  final (n, ei, ok) = _xtoi(s.slice(0, 2));
  return (n & 0xff, ok && ei == 2);
}

/// `hexString(b)`.
Golang.String _hexString(_Bytes b) {
  final s = <int>[];
  for (var i = 0; i < b.length; i++) {
    final tn = b[i].toInt();
    s
      ..add(_hexDigit.codeUnitAt(tn >> 4))
      ..add(_hexDigit.codeUnitAt(tn & 0xf));
  }
  return _str(s);
}

/// `ipEmptyString(ip)`: vazio para o IP sem bytes.
Golang.String _ipEmptyString(IP ip) =>
    ip.length == 0 ? Golang.String() : ip.string();
