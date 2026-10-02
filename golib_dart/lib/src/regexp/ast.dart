part of '../../regexp.dart';

/// Erro de sintaxe com a mensagem do `regexp/syntax` do Go:
/// "error parsing regexp: <código>: `<trecho>`".
class _SyntaxError implements Exception {
  _SyntaxError(this.code, this.expr, [this.raw]);

  final String code, expr;

  /// Trecho com bytes inválidos (UTF-8 inválido), sem decodificar.
  final Uint8List? raw;

  /// A mensagem do Go (bytes: o trecho pode não ser UTF-8).
  Golang.String get message =>
      Golang.String.fromDart('error parsing regexp: $code: `') +
      (raw != null
          ? Golang.String.fromBytes(raw!)
          : Golang.String.fromDart(expr)) +
      Golang.String.fromDart('`');
}

const _maxRune = 0x10ffff;

// Flags do parser (as de Perl são fixas: ClassNL, PerlX, UnicodeGroups).
const _fFold = 1, _fOneLine = 2, _fDotNL = 4, _fNonGreedy = 8;

// Asserções de largura zero.
const _aBeginText = 0,
    _aEndText = 1,
    _aBeginLine = 2,
    _aEndLine = 3,
    _aWordB = 4,
    _aNoWordB = 5;

enum _K { lit, cls, any, assertion, cat, alt, rep, cap, nop }

/// Nó da árvore de sintaxe.
class _Node {
  _Node(this.k);

  final _K k;
  int rune = 0; // lit; assertion: tipo; cap: índice
  bool fold = false; // lit
  bool flag = false; // any: casa \n; rep: guloso
  _Class? cls;
  List<_Node> subs = const [];
  int min = 0, max = 0; // rep (max -1 = infinito)

  static _Node lit(int r, bool fold) => _Node(_K.lit)
    ..rune = r
    ..fold = fold;
  static _Node assertion(int a) => _Node(_K.assertion)..rune = a;
}

/// Conjunto de runas de uma classe `[...]`, `\d`, `\pL`: intervalos
/// (pares lo, hi), propriedades Unicode (com sinal) e negação.
class _Class {
  final List<int> ranges = [];
  final List<(_Prop, bool)> props = [];
  bool neg = false;
  bool fold = false;

  void addRange(int lo, int hi) {
    ranges
      ..add(lo)
      ..add(hi);
  }

  void addRanges(List<int> rs, {bool negate = false}) {
    if (!negate) {
      ranges.addAll(rs);
      return;
    }
    var next = 0;
    final sorted = <(int, int)>[
      for (var i = 0; i < rs.length; i += 2) (rs[i], rs[i + 1]),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (lo, hi) in sorted) {
      if (lo > next) addRange(next, lo - 1);
      if (hi + 1 > next) next = hi + 1;
    }
    if (next <= _maxRune) addRange(next, _maxRune);
  }

  bool _in(int r) {
    for (var i = 0; i < ranges.length; i += 2) {
      if (r >= ranges[i] && r <= ranges[i + 1]) return true;
    }
    for (final (p, neg) in props) {
      if (p.test(r) != neg) return true;
    }
    return false;
  }

  bool matches(int r) {
    var ok = _in(r);
    if (!ok && fold) {
      for (final v in _orbit(r)) {
        if (v != r && _in(v)) {
          ok = true;
          break;
        }
      }
    }
    return ok != neg;
  }
}

final Map<int, List<int>> _orbitCache = {};

// Órbitas de dobra de caixa com mais de duas runas (`unicode.SimpleFold`)
// que maiúscula/minúscula do Dart não reconstroem sozinhas.
const _orbits = [
  [0x3a3, 0x3c3, 0x3c2],
  [0xb5, 0x39c, 0x3bc],
  [0xc5, 0xe5, 0x212b],
  [0x398, 0x3b8, 0x3d1, 0x3f4],
  [0x392, 0x3b2, 0x3d0],
  [0x395, 0x3b5, 0x3f5],
  [0x39a, 0x3ba, 0x3f0],
  [0x3a0, 0x3c0, 0x3d6],
  [0x3a1, 0x3c1, 0x3f1],
  [0x3a6, 0x3c6, 0x3d5],
  [0x3a9, 0x3c9, 0x2126],
  [0x1e60, 0x1e61, 0x1e9b],
  [0x345, 0x399, 0x3b9, 0x1fbe],
];

/// Runas equivalentes a `r` por dobra de caixa simples (aproxima
/// `unicode.SimpleFold`: maiúscula/minúscula do Dart mais K/S especiais).
List<int> _orbit(int r) {
  if (_orbitCache[r] case final c?) return c;
  final out = <int>{r};
  for (var round = 0; round < 2; round++) {
    for (final c in out.toList()) {
      if (c >= 0xd800 && c <= 0xdfff) continue;
      final s = String.fromCharCode(c);
      for (final t in [s.toLowerCase(), s.toUpperCase()]) {
        final rs = t.runes;
        if (rs.length == 1) out.add(rs.first);
      }
    }
  }
  for (final g in _orbits) {
    if (out.any(g.contains)) out.addAll(g);
  }
  if (out.contains(0x6b)) out.add(0x212a);
  if (out.contains(0x212a)) out.addAll([0x4b, 0x6b]);
  if (out.contains(0x73)) out.add(0x17f);
  if (out.contains(0x17f)) out.addAll([0x53, 0x73]);
  return _orbitCache[r] = out.toList()..sort();
}

/// Propriedade Unicode (`\p{L}`, `\p{Greek}`) avaliada pelo `RegExp` do
/// Dart com `unicode: true` (tabelas Unicode da plataforma).
class _Prop {
  _Prop._(this._re);

  final RegExp _re;
  final Map<int, bool> _memo = {};

  bool test(int r) => _memo[r] ??= _re.hasMatch(String.fromCharCode(r));

  static final Map<String, _Prop?> _cache = {};

  static const _cats = {
    'C', 'Cc', 'Cf', 'Co', 'Cs', 'L', 'Ll', 'Lm', 'Lo', 'Lt', 'Lu', //
    'M', 'Mc', 'Me', 'Mn', 'N', 'Nd', 'Nl', 'No', 'P', 'Pc', 'Pd', 'Pe',
    'Pf', 'Pi', 'Po', 'Ps', 'S', 'Sc', 'Sk', 'Sm', 'So', 'Z', 'Zl', 'Zp',
    'Zs',
  };

  /// `null` se o Go também rejeitaria o nome.
  static _Prop? lookup(String name) => _cache.putIfAbsent(name, () {
    if (name == 'Any') return _Prop._(RegExp(r'[\s\S]', unicode: true));
    try {
      if (_cats.contains(name)) {
        return _Prop._(RegExp('\\p{$name}', unicode: true));
      }
      if (RegExp(r'^[A-Z][A-Za-z_]*$').hasMatch(name)) {
        return _Prop._(RegExp('\\p{Script=$name}', unicode: true));
      }
    } on FormatException {
      return null;
    }
    return null;
  });
}
