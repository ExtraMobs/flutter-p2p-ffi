part of '../../regexp.dart';

Uint8List _toList(Slice<Golang.Uint8> b) =>
    Uint8List.fromList([for (final x in b.items) x.toInt()]);

/// Lista de bytes como `[]byte` (não nil, como o resultado de `ReplaceAll`).
Slice<Golang.Uint8> _fromList(List<int> b) =>
    Slice.of([for (final x in b) Golang.Uint8(x)], _byteElem);

Slice<Golang.Int> _ints(List<int> a) =>
    Slice.of([for (final x in a) Golang.Int(x)], _intElem);

Slice<Golang.String> _strSubs(Golang.String s, List<int> a) => Slice.of([
  for (var k = 0; k < a.length; k += 2)
    a[k] >= 0 ? s.slice(a[k], a[k + 1]) : Golang.String(),
], _strElem);

Slice<Slice<Golang.Uint8>> _byteSubs(Slice<Golang.Uint8> b, List<int> a) =>
    Slice.of([
      for (var k = 0; k < a.length; k += 2)
        a[k] >= 0 ? b.slice(a[k], a[k + 1], a[k + 1]) : _nilBytes(),
    ], _bytesElem);

/// `allMatches` do Go: até `n` casamentos sucessivos sem sobreposição
/// (`n < 0`: todos), pulando o vazio colado ao fim do anterior.
List<List<int>> _allMatches(Regexp re, Uint8List b, int n, int ncap) {
  if (n < 0) n = b.length + 1;
  final out = <List<int>>[];
  final m = _Machine(re._prog, b);
  var pos = 0, prevMatchEnd = -1;
  for (var i = 0; i < n && pos <= b.length;) {
    final a = m.exec(pos, ncap);
    if (a == null) break;
    var accept = true;
    if (a[1] == pos) {
      // Casamento vazio: avança uma runa (ou passa do fim).
      if (a[0] == prevMatchEnd) accept = false;
      final w = pos < b.length ? _decodeRune(b, pos).$2 : 0;
      pos = w > 0 ? pos + w : b.length + 1;
    } else {
      pos = a[1];
    }
    prevMatchEnd = a[1];
    if (accept) {
      out.add(a);
      i++;
    }
  }
  return out;
}
