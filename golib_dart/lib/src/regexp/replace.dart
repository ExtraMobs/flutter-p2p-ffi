part of '../../regexp.dart';

typedef _Repl = void Function(List<int> dst, List<int> m, Uint8List src);

/// `replaceAll` do Go: `repl` anexa a substituição de cada casamento (os
/// vazios colados ao fim do anterior não substituem).
List<int> _replaceAllList(Regexp re, Uint8List src, int ncap, _Repl repl) {
  final buf = <int>[];
  final mach = _Machine(re._prog, src);
  var lastMatchEnd = 0, searchPos = 0;
  while (searchPos <= src.length) {
    final a = mach.exec(searchPos, ncap);
    if (a == null) break;
    buf.addAll(src.sublist(lastMatchEnd, a[0]));
    if (a[1] > lastMatchEnd || a[0] == 0) repl(buf, a, src);
    lastMatchEnd = a[1];
    final width = searchPos < src.length ? _decodeRune(src, searchPos).$2 : 0;
    if (searchPos + width > a[1]) {
      searchPos += width;
    } else if (searchPos + 1 > a[1]) {
      searchPos++;
    } else {
      searchPos = a[1];
    }
  }
  buf.addAll(src.sublist(lastMatchEnd));
  return buf;
}

Golang.String _replaceAll(Regexp re, Uint8List src, int ncap, _Repl repl) =>
    Golang.String.fromBytes(
      Uint8List.fromList(_replaceAllList(re, src, ncap, repl)),
    );

List<int> _replaceAllBytes(Regexp re, Uint8List src, int ncap, _Repl repl) =>
    _replaceAllList(re, src, ncap, repl);

bool _isLetterOrDigit(int r) {
  if (r < 0x80) return _isAlnum(r);
  return _Prop.lookup('L')!.test(r) || _Prop.lookup('Nd')!.test(r);
}

/// `extract` do Go: nome de `$name`/`${name}` (e o número, se só dígitos).
({String name, int num, int rest})? _extract(Uint8List t, int i) {
  if (i >= t.length) return null;
  var brace = false;
  if (t[i] == 0x7b) {
    brace = true;
    i++;
  }
  var j = i;
  while (j < t.length) {
    final (r, w) = _decodeRune(t, j);
    if (!_isLetterOrDigit(r) && r != 0x5f) break;
    j += w;
  }
  if (j == i) return null;
  final name = String.fromCharCodes(t.sublist(i, j));
  if (brace) {
    if (j >= t.length || t[j] != 0x7d) return null;
    j++;
  }
  var num = 0;
  for (var k = i; k < i + name.length; k++) {
    final c = t[k];
    if (c < 0x30 || c > 0x39 || num >= 100000000) {
      num = -1;
      break;
    }
    num = num * 10 + c - 0x30;
  }
  if (name.length > 1 && name.codeUnitAt(0) == 0x30) num = -1;
  return (name: name, num: num, rest: j);
}

/// `expand` do Go: anexa `template` a `dst` trocando `$1`, `${name}`, `$$`.
void _expand(
  Regexp re,
  List<int> dst,
  Uint8List template,
  Uint8List src,
  List<int> match,
) {
  var i = 0;
  while (i < template.length) {
    final d = template.indexOf(0x24, i);
    if (d < 0) break;
    dst.addAll(template.sublist(i, d));
    i = d + 1;
    if (i < template.length && template[i] == 0x24) {
      dst.add(0x24);
      i++;
      continue;
    }
    final x = _extract(template, i);
    if (x == null) {
      // `$` malformado: fica literal.
      dst.add(0x24);
      continue;
    }
    i = x.rest;
    if (x.num >= 0) {
      if (2 * x.num + 1 < match.length && match[2 * x.num] >= 0) {
        dst.addAll(src.sublist(match[2 * x.num], match[2 * x.num + 1]));
      }
    } else {
      for (var k = 0; k < re._names.length; k++) {
        if (re._names[k] == x.name && 2 * k + 1 < match.length) {
          if (match[2 * k] >= 0) {
            dst.addAll(src.sublist(match[2 * k], match[2 * k + 1]));
          }
          break;
        }
      }
    }
  }
  dst.addAll(template.sublist(i));
}

/// `Expand`/`ExpandString`: acrescenta a `dst` (que pode crescer).
Slice<Golang.Uint8> _expandInto(
  Regexp re,
  Slice<Golang.Uint8> dst,
  Uint8List template,
  Uint8List src,
  Slice<Golang.Int> match,
) {
  final m = [for (final x in match.items) x.toInt()];
  final out = <int>[];
  _expand(re, out, template, src, m);
  return dst.append([for (final x in out) Golang.Uint8(x)]);
}
