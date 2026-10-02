part of '../../bytes.dart';

_Bytes _emptyBytes() => Slice<Golang.Uint8>.make(0, 0, _byteElem);

void _put(_Bytes dst, int at, _Bytes src) {
  for (var i = 0; i < src.length; i++) {
    dst[at + i] = src[i];
  }
}

/// `bytes.Clone(b)`: nil continua nil.
_Bytes clone(_Bytes b) =>
    b.isNil ? _nilBytes() : _emptyBytes().appendSlice(b);

/// `bytes.Join(s, sep)`.
_Bytes join(Slice<_Bytes> s, _Bytes sep) {
  if (s.length == 0) return _emptyBytes();
  if (s.length == 1) return _nilBytes().appendSlice(s[0]);
  var n = sep.length * (s.length - 1);
  for (var i = 0; i < s.length; i++) {
    n += s[i].length;
  }
  final b = Slice<Golang.Uint8>.make(n, n, _byteElem);
  var bp = 0;
  _put(b, bp, s[0]);
  bp += s[0].length;
  for (var i = 1; i < s.length; i++) {
    _put(b, bp, sep);
    bp += sep.length;
    _put(b, bp, s[i]);
    bp += s[i].length;
  }
  return b;
}

/// `bytes.Repeat(b, count)`: panica com count negativo ou estouro.
_Bytes repeat(_Bytes b, Golang.Int count_) {
  final count = count_.toInt();
  if (count == 0) return _emptyBytes();
  if (count < 0) {
    throw Panic(Golang.String.fromDart('bytes: negative Repeat count'));
  }
  if (BigInt.from(b.length) * BigInt.from(count) >
      BigInt.parse('9223372036854775807')) {
    throw Panic(Golang.String.fromDart('bytes: Repeat output length overflow'));
  }
  if (b.length == 0) return _emptyBytes();
  final n = b.length * count;
  final nb = Slice<Golang.Uint8>.make(n, n, _byteElem);
  for (var i = 0; i < count; i++) {
    _put(nb, i * b.length, b);
  }
  return nb;
}

/// `bytes.Map(mapping, s)`: runa negativa some; inválida vira U+FFFD.
_Bytes map(Golang.Rune Function(Golang.Rune)? mapping, _Bytes s) {
  final g = _str(s);
  var b = Slice<Golang.Uint8>.make(0, s.length, _byteElem);
  for (var i = 0; i < s.length;) {
    final (c, n) = g.decodeRune(i);
    final r = mapping!(Golang.Rune(c)).toInt();
    if (r >= 0) {
      b = b.append([
        for (final x in Golang.String.fromCodePoint(r).toBytes())
          Golang.Uint8(x),
      ]);
    }
    i += n;
  }
  return b;
}

/// `bytes.Replace(s, old, new, n)`: sempre cópia; n < 0 sem limite; `old`
/// vazio casa no início e depois de cada sequência UTF-8.
_Bytes replace(_Bytes s, _Bytes old, _Bytes new_, Golang.Int n_) {
  var n = n_.toInt();
  var m = 0;
  if (n != 0) m = count(s, old).toInt();
  if (m == 0) return _nilBytes().appendSlice(s);
  if (n < 0 || m < n) n = m;
  final total = s.length + n * (new_.length - old.length);
  final t = Slice<Golang.Uint8>.make(total, total, _byteElem);
  var w = 0, start = 0;
  void put(_Bytes src) {
    _put(t, w, src);
    w += src.length;
  }

  if (old.length > 0) {
    for (var k = 0; k < n; k++) {
      final j = start + index(s.slice(start), old).toInt();
      put(s.slice(start, j));
      put(new_);
      start = j + old.length;
    }
  } else {
    final g = _str(s);
    put(new_);
    for (var k = 0; k < n - 1; k++) {
      final j = start + g.decodeRune(start).$2;
      put(s.slice(start, j));
      put(new_);
      start = j;
    }
  }
  put(s.slice(start));
  return t.slice(0, w);
}

/// `bytes.ReplaceAll(s, old, new)`.
_Bytes replaceAll(_Bytes s, _Bytes old, _Bytes new_) =>
    replace(s, old, new_, Golang.Int(-1));
