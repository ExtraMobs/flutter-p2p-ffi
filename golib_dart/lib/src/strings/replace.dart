part of '../../strings.dart';

Golang.String _fromBuilder(BytesBuilder b) =>
    Golang.String.fromBytes(b.takeBytes());

/// `strings.Replace(s, old, new, n)`: n < 0 sem limite; `old` vazio casa no
/// início e depois de cada sequência UTF-8.
Golang.String replace(
  Golang.String s,
  Golang.String old,
  Golang.String new_,
  Golang.Int n_,
) {
  var n = n_.toInt();
  if (old == new_ || n == 0) return s;
  final m = count(s, old).toInt();
  if (m == 0) return s;
  if (n < 0 || m < n) n = m;
  final b = BytesBuilder(copy: false);
  var start = 0;
  if (old.length > 0) {
    for (var k = 0; k < n; k++) {
      final j = start + index(s.slice(start), old).toInt();
      b.add(s.slice(start, j).toBytes());
      b.add(new_.toBytes());
      start = j + old.length;
    }
  } else {
    b.add(new_.toBytes());
    for (var k = 0; k < n - 1; k++) {
      final j = start + s.decodeRune(start).$2;
      b.add(s.slice(start, j).toBytes());
      b.add(new_.toBytes());
      start = j;
    }
  }
  b.add(s.slice(start).toBytes());
  return _fromBuilder(b);
}

/// `strings.ReplaceAll(s, old, new)`.
Golang.String replaceAll(
  Golang.String s,
  Golang.String old,
  Golang.String new_,
) => replace(s, old, new_, Golang.Int(-1));

/// `strings.Repeat(s, count)`: panica com count negativo ou estouro.
Golang.String repeat(Golang.String s, Golang.Int count_) {
  final count = count_.toInt();
  if (count == 0) return Golang.String();
  if (count == 1) return s;
  if (count < 0) {
    throw Panic(Golang.String.fromDart('strings: negative Repeat count'));
  }
  if (BigInt.from(s.length) * BigInt.from(count) >
      BigInt.parse('9223372036854775807')) {
    throw Panic(
      Golang.String.fromDart('strings: Repeat output length overflow'),
    );
  }
  if (s.length == 0) return Golang.String();
  final one = s.toBytes();
  final out = Uint8List(one.length * count);
  for (var i = 0; i < count; i++) {
    out.setRange(i * one.length, (i + 1) * one.length, one);
  }
  return Golang.String.fromBytes(out);
}

/// `strings.Compare(a, b)`.
Golang.Int compare(Golang.String a, Golang.String b) {
  final c = a.compareTo(b);
  return Golang.Int(c < 0 ? -1 : (c > 0 ? 1 : 0));
}

/// `strings.Cut(s, sep)`.
(Golang.String, Golang.String, bool) cut(Golang.String s, Golang.String sep) {
  final i = index(s, sep).toInt();
  if (i >= 0) return (s.slice(0, i), s.slice(i + sep.length), true);
  return (s, Golang.String(), false);
}

/// `strings.CutPrefix(s, prefix)`.
(Golang.String, bool) cutPrefix(Golang.String s, Golang.String prefix) =>
    hasPrefix(s, prefix) ? (s.slice(prefix.length), true) : (s, false);

/// `strings.CutSuffix(s, suffix)`.
(Golang.String, bool) cutSuffix(Golang.String s, Golang.String suffix) =>
    hasSuffix(s, suffix)
    ? (s.slice(0, s.length - suffix.length), true)
    : (s, false);

/// `strings.Map(mapping, s)`: runa negativa some; inválida vira U+FFFD.
Golang.String map(
  Golang.Rune Function(Golang.Rune)? mapping,
  Golang.String s,
) {
  final b = BytesBuilder(copy: false);
  for (var i = 0; i < s.length;) {
    final (c, n) = s.decodeRune(i);
    final r = mapping!(Golang.Rune(c)).toInt();
    if (r >= 0) b.add(Golang.String.fromCodePoint(r).toBytes());
    i += n;
  }
  return _fromBuilder(b);
}

/// `strings.FieldsFunc(s, f)`: f é chamada uma vez por runa, em ordem.
Slice<Golang.String> fieldsFunc(Golang.String s, bool Function(Golang.Rune)? f) {
  final spans = <(int, int)>[];
  var start = -1;
  for (var i = 0; i < s.length;) {
    final (r, n) = s.decodeRune(i);
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
  final a = Slice<Golang.String>.make(spans.length, spans.length, _strElem);
  for (var i = 0; i < spans.length; i++) {
    a[i] = s.slice(spans[i].$1, spans[i].$2);
  }
  return a;
}

/// `strings.SplitAfter(s, sep)`.
Slice<Golang.String> splitAfter(Golang.String s, Golang.String sep) =>
    _genSplit(s, sep, sep.length, -1);

/// `strings.SplitAfterN(s, sep, n)`.
Slice<Golang.String> splitAfterN(
  Golang.String s,
  Golang.String sep,
  Golang.Int n,
) => _genSplit(s, sep, sep.length, n.toInt());
