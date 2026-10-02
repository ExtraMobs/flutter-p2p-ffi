part of '../../regexp.dart';

/// `regexp.Regexp`: struct de shim usada por ponteiro no código gerado
/// (`go.GoStruct`; o programa compilado é imutável e compartilhado nas
/// cópias, como o Go faz com `Regexp.Copy`).
final class Regexp extends GoStruct<Regexp> implements Stringer {
  Regexp() : this._(Golang.String(), _Prog.compile(_Node(_K.nop)), 0, ['']);

  Regexp._(this._expr, this._prog, this._numCap, this._names);

  /// `(*Regexp)(nil)` dentro de uma interface.
  static final Regexp $nil = Regexp()..$nilPtr = true;

  Golang.String _expr;
  _Prog _prog;
  int _numCap;
  List<String> _names;

  @override
  String get $goType => 'regexp.Regexp';

  @override
  List<String> get $ptrMethods => const [
    'Expand',
    'ExpandString',
    'Find',
    'FindAll',
    'FindAllIndex',
    'FindAllString',
    'FindAllStringIndex',
    'FindAllStringSubmatch',
    'FindAllStringSubmatchIndex',
    'FindAllSubmatch',
    'FindAllSubmatchIndex',
    'FindIndex',
    'FindString',
    'FindStringIndex',
    'FindStringSubmatch',
    'FindStringSubmatchIndex',
    'FindSubmatch',
    'FindSubmatchIndex',
    'Match',
    'MatchString',
    'NumSubexp',
    'ReplaceAll',
    'ReplaceAllFunc',
    'ReplaceAllLiteral',
    'ReplaceAllLiteralString',
    'ReplaceAllString',
    'ReplaceAllStringFunc',
    'Split',
    'String',
    'SubexpIndex',
    'SubexpNames',
  ];

  @override
  Regexp $copy() => Regexp._(_expr, _prog, _numCap, _names);

  @override
  void $set(Regexp o) {
    _expr = o._expr;
    _prog = o._prog;
    _numCap = o._numCap;
    _names = o._names;
  }

  @override
  List<Object?> get $fields => [_expr];

  @override
  List<String> get $fieldNames => const ['expr'];

  /// `String()`: o texto da expressão passada a `Compile`.
  @override
  Golang.String string() => _expr;

  /// `NumSubexp()`.
  Golang.Int numSubexp() => Golang.Int(_numCap);

  /// `SubexpNames()`.
  Slice<Golang.String> subexpNames() =>
      Slice.of([for (final n in _names) Golang.String.fromDart(n)], _strElem);

  /// `SubexpIndex(name)`: -1 se não existe (ou `name` vazio).
  Golang.Int subexpIndex(Golang.String name) {
    final n = name.toDart();
    if (n != '') {
      for (var i = 0; i < _names.length; i++) {
        if (_names[i] == n) return Golang.Int(i);
      }
    }
    return Golang.Int(-1);
  }

  // Um casamento a partir de `pos` (-1 em índice = grupo ausente).
  List<int>? _exec(Uint8List b, int pos, int ncap) =>
      _Machine(_prog, b).exec(pos, ncap);

  /// `MatchString(s)`.
  bool matchString(Golang.String s) => _exec(s.toBytes(), 0, 2) != null;

  /// `Match(b)`.
  bool match(Slice<Golang.Uint8> b) => _exec(_toList(b), 0, 2) != null;

  /// `FindString(s)`: "" se não casa.
  Golang.String findString(Golang.String s) {
    final a = _exec(s.toBytes(), 0, 2);
    return a == null ? Golang.String() : s.slice(a[0], a[1]);
  }

  /// `Find(b)`: nil se não casa; aponta para `b`.
  Slice<Golang.Uint8> find(Slice<Golang.Uint8> b) {
    final a = _exec(_toList(b), 0, 2);
    return a == null ? _nilBytes() : b.slice(a[0], a[1], a[1]);
  }

  /// `FindStringIndex(s)`.
  Slice<Golang.Int> findStringIndex(Golang.String s) {
    final a = _exec(s.toBytes(), 0, 2);
    return a == null ? _nilInts() : _ints(a);
  }

  /// `FindIndex(b)`.
  Slice<Golang.Int> findIndex(Slice<Golang.Uint8> b) {
    final a = _exec(_toList(b), 0, 2);
    return a == null ? _nilInts() : _ints(a);
  }

  /// `FindStringSubmatchIndex(s)`.
  Slice<Golang.Int> findStringSubmatchIndex(Golang.String s) {
    final a = _exec(s.toBytes(), 0, _ncap);
    return a == null ? _nilInts() : _ints(a);
  }

  /// `FindSubmatchIndex(b)`.
  Slice<Golang.Int> findSubmatchIndex(Slice<Golang.Uint8> b) {
    final a = _exec(_toList(b), 0, _ncap);
    return a == null ? _nilInts() : _ints(a);
  }

  int get _ncap => 2 * (_numCap + 1);

  /// `FindStringSubmatch(s)`: "" nos grupos ausentes; nil se não casa.
  Slice<Golang.String> findStringSubmatch(Golang.String s) {
    final a = _exec(s.toBytes(), 0, _ncap);
    return a == null ? _nilStrs() : _strSubs(s, a);
  }

  /// `FindSubmatch(b)`: nil nos grupos ausentes; nil se não casa.
  Slice<Slice<Golang.Uint8>> findSubmatch(Slice<Golang.Uint8> b) {
    final a = _exec(_toList(b), 0, _ncap);
    return a == null ? _nilBytess() : _byteSubs(b, a);
  }

  /// `FindAllString(s, n)`.
  Slice<Golang.String> findAllString(Golang.String s, Golang.Int n) {
    final ms = _allMatches(this, s.toBytes(), n.toInt(), 2);
    if (ms.isEmpty) return _nilStrs();
    return Slice.of([for (final a in ms) s.slice(a[0], a[1])], _strElem);
  }

  /// `FindAll(b, n)`.
  Slice<Slice<Golang.Uint8>> findAll(Slice<Golang.Uint8> b, Golang.Int n) {
    final ms = _allMatches(this, _toList(b), n.toInt(), 2);
    if (ms.isEmpty) return _nilBytess();
    return Slice.of([
      for (final a in ms) b.slice(a[0], a[1], a[1]),
    ], _bytesElem);
  }

  /// `FindAllStringIndex(s, n)`.
  Slice<Slice<Golang.Int>> findAllStringIndex(Golang.String s, Golang.Int n) {
    final ms = _allMatches(this, s.toBytes(), n.toInt(), 2);
    return ms.isEmpty
        ? Slice.nil(_intsElem)
        : Slice.of([for (final a in ms) _ints(a)], _intsElem);
  }

  /// `FindAllIndex(b, n)`.
  Slice<Slice<Golang.Int>> findAllIndex(Slice<Golang.Uint8> b, Golang.Int n) {
    final ms = _allMatches(this, _toList(b), n.toInt(), 2);
    return ms.isEmpty
        ? Slice.nil(_intsElem)
        : Slice.of([for (final a in ms) _ints(a)], _intsElem);
  }

  /// `FindAllStringSubmatch(s, n)`.
  Slice<Slice<Golang.String>> findAllStringSubmatch(
    Golang.String s,
    Golang.Int n,
  ) {
    final ms = _allMatches(this, s.toBytes(), n.toInt(), _ncap);
    return ms.isEmpty
        ? Slice.nil(_strsElem)
        : Slice.of([for (final a in ms) _strSubs(s, a)], _strsElem);
  }

  /// `FindAllSubmatch(b, n)`.
  Slice<Slice<Slice<Golang.Uint8>>> findAllSubmatch(
    Slice<Golang.Uint8> b,
    Golang.Int n,
  ) {
    final ms = _allMatches(this, _toList(b), n.toInt(), _ncap);
    return ms.isEmpty
        ? Slice.nil(_bytessElem)
        : Slice.of([for (final a in ms) _byteSubs(b, a)], _bytessElem);
  }

  /// `FindAllStringSubmatchIndex(s, n)`.
  Slice<Slice<Golang.Int>> findAllStringSubmatchIndex(
    Golang.String s,
    Golang.Int n,
  ) {
    final ms = _allMatches(this, s.toBytes(), n.toInt(), _ncap);
    return ms.isEmpty
        ? Slice.nil(_intsElem)
        : Slice.of([for (final a in ms) _ints(a)], _intsElem);
  }

  /// `FindAllSubmatchIndex(b, n)`.
  Slice<Slice<Golang.Int>> findAllSubmatchIndex(
    Slice<Golang.Uint8> b,
    Golang.Int n,
  ) {
    final ms = _allMatches(this, _toList(b), n.toInt(), _ncap);
    return ms.isEmpty
        ? Slice.nil(_intsElem)
        : Slice.of([for (final a in ms) _ints(a)], _intsElem);
  }

  /// `ReplaceAllString(src, repl)`: `$1`, `${name}` expandem como no Go.
  Golang.String replaceAllString(Golang.String src, Golang.String repl) {
    final r = repl.toBytes();
    return _replaceAll(
      this,
      src.toBytes(),
      _ncap,
      (dst, m, b) => _expand(this, dst, r, b, m),
    );
  }

  /// `ReplaceAllLiteralString(src, repl)`.
  Golang.String replaceAllLiteralString(Golang.String src, Golang.String repl) {
    final r = repl.toBytes();
    return _replaceAll(this, src.toBytes(), 2, (dst, m, b) => dst.addAll(r));
  }

  /// `ReplaceAllStringFunc(src, repl)`.
  Golang.String replaceAllStringFunc(
    Golang.String src,
    Golang.String Function(Golang.String)? repl,
  ) => _replaceAll(
    this,
    src.toBytes(),
    2,
    (dst, m, b) => dst.addAll(repl!(src.slice(m[0], m[1])).toBytes()),
  );

  /// `ReplaceAll(src, repl)`.
  Slice<Golang.Uint8> replaceAll(
    Slice<Golang.Uint8> src,
    Slice<Golang.Uint8> repl,
  ) {
    final r = _toList(repl);
    return _fromList(
      _replaceAllBytes(
        this,
        _toList(src),
        _ncap,
        (dst, m, b) => _expand(this, dst, r, b, m),
      ),
    );
  }

  /// `ReplaceAllLiteral(src, repl)`.
  Slice<Golang.Uint8> replaceAllLiteral(
    Slice<Golang.Uint8> src,
    Slice<Golang.Uint8> repl,
  ) {
    final r = _toList(repl);
    return _fromList(
      _replaceAllBytes(this, _toList(src), 2, (dst, m, b) => dst.addAll(r)),
    );
  }

  /// `ReplaceAllFunc(src, repl)`.
  Slice<Golang.Uint8> replaceAllFunc(
    Slice<Golang.Uint8> src,
    Slice<Golang.Uint8> Function(Slice<Golang.Uint8>)? repl,
  ) => _fromList(
    _replaceAllBytes(
      this,
      _toList(src),
      2,
      (dst, m, b) => dst.addAll(_toList(repl!(src.slice(m[0], m[1], m[1])))),
    ),
  );

  /// `Expand(dst, template, src, match)`: anexa a `dst` o `template` com
  /// `$` expandido.
  Slice<Golang.Uint8> expand(
    Slice<Golang.Uint8> dst,
    Slice<Golang.Uint8> template,
    Slice<Golang.Uint8> src,
    Slice<Golang.Int> match,
  ) => _expandInto(this, dst, _toList(template), _toList(src), match);

  /// `ExpandString(dst, template, src, match)`.
  Slice<Golang.Uint8> expandString(
    Slice<Golang.Uint8> dst,
    Golang.String template,
    Golang.String src,
    Slice<Golang.Int> match,
  ) => _expandInto(this, dst, template.toBytes(), src.toBytes(), match);

  /// `Split(s, n)`.
  Slice<Golang.String> split(Golang.String s, Golang.Int n) {
    final k = n.toInt();
    if (k == 0) return _nilStrs();
    if (_expr.length > 0 && s.length == 0) {
      return Slice.of([Golang.String()], _strElem);
    }
    final ms = _allMatches(this, s.toBytes(), k, 2);
    final out = <Golang.String>[];
    var beg = 0, end = 0;
    for (final m in ms) {
      if (k > 0 && out.length == k - 1) break;
      end = m[0];
      if (m[1] != 0) out.add(s.slice(beg, end));
      beg = m[1];
    }
    if (end != s.length) out.add(s.slice(beg));
    return Slice.of(out, _strElem);
  }
}
