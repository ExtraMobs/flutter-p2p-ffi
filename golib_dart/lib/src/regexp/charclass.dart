part of '../../regexp.dart';

const _perlDigit = [0x30, 0x39];
const _perlSpace = [9, 10, 12, 13, 13, 13, 32, 32];
const _perlWord = [0x30, 0x39, 0x41, 0x5a, 0x5f, 0x5f, 0x61, 0x7a];

const _posix = <String, List<int>>{
  'alnum': [0x30, 0x39, 0x41, 0x5a, 0x61, 0x7a],
  'alpha': [0x41, 0x5a, 0x61, 0x7a],
  'ascii': [0, 0x7f],
  'blank': [9, 9, 32, 32],
  'cntrl': [0, 0x1f, 0x7f, 0x7f],
  'digit': [0x30, 0x39],
  'graph': [0x21, 0x7e],
  'lower': [0x61, 0x7a],
  'print': [0x20, 0x7e],
  'punct': [0x21, 0x2f, 0x3a, 0x40, 0x5b, 0x60, 0x7b, 0x7e],
  'space': [9, 13, 32, 32],
  'upper': [0x41, 0x5a],
  'word': [0x30, 0x39, 0x41, 0x5a, 0x5f, 0x5f, 0x61, 0x7a],
  'xdigit': [0x30, 0x39, 0x41, 0x46, 0x61, 0x66],
};

/// `\d \D \s \S \w \W` em `cur.i` (que está na `\`); `false` se não for.
bool _parsePerlClass(_Cur cur, _Class into) {
  if (cur.left < 2 || cur.peek != 0x5c) return false;
  final c = cur.s[cur.i + 1];
  final lower = c | 0x20;
  final List<int> g;
  switch (lower) {
    case 0x64:
      g = _perlDigit;
    case 0x73:
      g = _perlSpace;
    case 0x77:
      g = _perlWord;
    default:
      return false;
  }
  if (c != lower && c != 0x44 && c != 0x53 && c != 0x57) return false;
  cur.i += 2;
  into.addGroup(g, negate: c != lower);
  return true;
}

/// `[:alpha:]` / `[:^alpha:]` em `cur.i` (que está em `[`): `false` se não
/// há `:]` adiante (o `[` é então um literal da classe).
bool _parseNamedClass(_Cur cur, _Class into) {
  var j = -1;
  for (var k = cur.i + 2; k + 1 < cur.s.length; k++) {
    if (cur.s[k] == 0x3a && cur.s[k + 1] == 0x5d) {
      j = k;
      break;
    }
  }
  if (j < 0) return false;
  final name = cur.text(cur.i, j + 2);
  var n = name.substring(2, name.length - 2);
  final neg = n.startsWith('^');
  if (neg) n = n.substring(1);
  final g = _posix[n];
  if (g == null) throw _SyntaxError('invalid character class range', name);
  cur.i = j + 2;
  into.addGroup(g, negate: neg);
  return true;
}

/// `\pL`, `\p{Greek}`, `\P{^Han}` em `cur.i` (na `\`); `false` se não for
/// `\p`/`\P`.
bool _parseUnicodeClass(_Cur cur, _Class into) {
  if (cur.left < 2 || cur.peek != 0x5c) return false;
  final p = cur.s[cur.i + 1];
  if (p != 0x70 && p != 0x50) return false;
  final start = cur.i;
  var neg = p == 0x50;
  cur.i += 2;
  if (cur.eof)
    throw _SyntaxError('invalid character class range', cur.text(start));
  String name, seq;
  final c = cur.s[cur.i++];
  if (c != 0x7b) {
    seq = cur.text(start);
    name = String.fromCharCode(c);
  } else {
    var end = -1;
    for (var k = start; k < cur.s.length; k++) {
      if (cur.s[k] == 0x7d) {
        end = k;
        break;
      }
    }
    if (end < 0) {
      cur.i = start;
      throw _SyntaxError(
        'invalid character class range',
        cur.text(start, cur.s.length),
      );
    }
    seq = cur.text(start, end + 1);
    name = cur.text(start + 3, end);
    cur.i = end + 1;
  }
  if (name.startsWith('^')) {
    neg = !neg;
    name = name.substring(1);
  }
  final prop = _Prop.lookup(name);
  if (prop == null) throw _SyntaxError('invalid character class range', seq);
  into.props.add((prop, neg));
  return true;
}

int _classChar(_Cur cur, int whole) {
  if (cur.eof) throw _SyntaxError('missing closing ]', cur.text(whole));
  if (cur.peek == 0x5c) return _parseEscape(cur);
  return cur.s[cur.i++];
}

/// `parseClass` do Go: `cur.i` está em `[`.
_Node _parseClass(_Cur cur, int flags) {
  final whole = cur.i;
  cur.i++;
  final cls = _Class()..fold = flags & _fFold != 0;
  if (!cur.eof && cur.peek == 0x5e) {
    cls.neg = true;
    cur.i++;
  }
  var first = true;
  while (cur.eof || cur.peek != 0x5d || first) {
    first = false;
    if (cur.left > 2 && cur.peek == 0x5b && cur.at(1, 0x3a)) {
      if (_parseNamedClass(cur, cls)) continue;
    }
    if (cur.left > 2 &&
        cur.peek == 0x5c &&
        (cur.at(1, 0x70) || cur.at(1, 0x50))) {
      if (_parseUnicodeClass(cur, cls)) continue;
    }
    if (_parsePerlClass(cur, cls)) continue;
    final rng = cur.i;
    final lo = _classChar(cur, whole);
    var hi = lo;
    if (cur.left >= 2 && cur.peek == 0x2d && !cur.at(1, 0x5d)) {
      cur.i++;
      hi = _classChar(cur, whole);
      if (hi < lo) {
        throw _SyntaxError('invalid character class range', cur.text(rng));
      }
    }
    cls.addRange(lo, hi);
  }
  cur.i++;
  return _Node(_K.cls)..cls = cls;
}
