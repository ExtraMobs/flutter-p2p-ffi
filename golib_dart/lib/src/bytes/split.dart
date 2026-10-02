part of '../../bytes.dart';

/// `bytes.Split(s, sep)`: subslices de s com cap limitado ao pedaço
/// (`s[:m:m]`), como no Go.
Slice<_Bytes> split(_Bytes s, _Bytes sep) => _genSplit(s, sep, 0, -1);

/// `bytes.SplitN(s, sep, n)`.
Slice<_Bytes> splitN(_Bytes s, _Bytes sep, Golang.Int n) =>
    _genSplit(s, sep, 0, n.toInt());

/// `bytes.SplitAfter(s, sep)`.
Slice<_Bytes> splitAfter(_Bytes s, _Bytes sep) =>
    _genSplit(s, sep, sep.length, -1);

/// `bytes.SplitAfterN(s, sep, n)`.
Slice<_Bytes> splitAfterN(_Bytes s, _Bytes sep, Golang.Int n) =>
    _genSplit(s, sep, sep.length, n.toInt());

Slice<_Bytes> _genSplit(_Bytes s, _Bytes sep, int sepSave, int n) {
  if (n == 0) return Slice.nil(_bytesElem);
  if (sep.length == 0) return _explode(s, n);
  if (n < 0) n = count(s, sep).toInt() + 1;
  if (n > s.length + 1) n = s.length + 1;
  final a = Slice<_Bytes>.make(n, n, _bytesElem);
  var i = 0;
  for (; i < n - 1; i++) {
    final m = index(s, sep).toInt();
    if (m < 0) break;
    a[i] = s.slice(0, m + sepSave, m + sepSave);
    s = s.slice(m + sep.length);
  }
  a[i] = s;
  return a.slice(0, i + 1);
}

Slice<_Bytes> _explode(_Bytes s, int n) {
  if (n <= 0 || n > s.length) n = s.length;
  final a = Slice<_Bytes>.make(n, n, _bytesElem);
  var na = 0;
  final g = _str(s);
  var off = 0;
  while (off < s.length) {
    if (na + 1 >= n) {
      a[na++] = s.slice(off);
      break;
    }
    final size = g.decodeRune(off).$2;
    a[na++] = s.slice(off, off + size, off + size);
    off += size;
  }
  return a.slice(0, na);
}

/// `bytes.FieldsFunc(s, f)`: f é chamada uma vez por runa, em ordem.
Slice<_Bytes> fieldsFunc(_Bytes s, bool Function(Golang.Rune)? f) {
  final g = _str(s);
  final spans = <(int, int)>[];
  var start = -1;
  for (var i = 0; i < s.length;) {
    final (r, n) = g.decodeRune(i);
    if (f!(Golang.Rune(r))) {
      if (start >= 0) {
        spans.add((start, i));
        start = -1;
      }
    } else if (start < 0) {
      start = i;
    }
    i += n;
  }
  if (start >= 0) spans.add((start, s.length));
  final a = Slice<_Bytes>.make(spans.length, spans.length, _bytesElem);
  for (var i = 0; i < spans.length; i++) {
    a[i] = s.slice(spans[i].$1, spans[i].$2, spans[i].$2);
  }
  return a;
}
