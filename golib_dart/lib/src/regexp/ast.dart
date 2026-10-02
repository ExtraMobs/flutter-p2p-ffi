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
/// (pares lo, hi), propriedades Unicode (com sinal) e negação. Com `fold`,
/// o que entra é dobrado na hora do parse (`appendFoldedRange` do Go),
/// antes de qualquer negação.
class _Class {
  final List<int> ranges = [];
  final List<(_Prop, bool)> props = [];
  bool neg = false;
  bool fold = false;
  List<int>? _norm;

  void addRange(int lo, int hi) {
    ranges
      ..add(lo)
      ..add(hi);
    if (!fold) return;
    // simpleFold só muda runas entre 0x41 e 0x1e943.
    final from = lo < 0x41 ? 0x41 : lo, to = hi > 0x1e943 ? 0x1e943 : hi;
    for (var c = from; c <= to; c++) {
      for (final f in _orbit(c)) {
        if (f != c && (f < lo || f > hi)) {
          ranges
            ..add(f)
            ..add(f);
        }
      }
    }
  }

  /// Grupo fixo (`\d`, `[:alpha:]`), dobrado e só então negado.
  void addGroup(List<int> g, {bool negate = false}) {
    final tmp = _Class()..fold = fold;
    for (var i = 0; i < g.length; i += 2) {
      tmp.addRange(g[i], g[i + 1]);
    }
    addRanges(tmp.ranges, negate: negate);
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
      if (lo > next)
        ranges
          ..add(next)
          ..add(lo - 1);
      if (hi + 1 > next) next = hi + 1;
    }
    if (next <= _maxRune)
      ranges
        ..add(next)
        ..add(_maxRune);
  }

  List<int> _normalized() {
    final pairs = <(int, int)>[
      for (var i = 0; i < ranges.length; i += 2) (ranges[i], ranges[i + 1]),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = <int>[];
    for (final (lo, hi) in pairs) {
      if (out.isNotEmpty && lo <= out.last + 1) {
        if (hi > out.last) out[out.length - 1] = hi;
      } else {
        out
          ..add(lo)
          ..add(hi);
      }
    }
    return out;
  }

  bool _in(int r) {
    final n = _norm ??= _normalized();
    var lo = 0, hi = n.length ~/ 2 - 1;
    while (lo <= hi) {
      final m = (lo + hi) >> 1;
      if (r < n[2 * m]) {
        hi = m - 1;
      } else if (r > n[2 * m + 1]) {
        lo = m + 1;
      } else {
        return true;
      }
    }
    for (final (p, neg) in props) {
      if (p.test(r, fold) != neg) return true;
    }
    return false;
  }

  bool matches(int r) => _in(r) != neg;
}

final Map<int, List<int>> _orbitCache = {};

/// Ciclo de `unicode.SimpleFold` de `r` (inclui `r`).
List<int> _orbit(int r) {
  if (_orbitCache[r] case final c?) return c;
  final out = [r];
  for (
    var f = unicode.simpleFold(Golang.Rune(r)).toInt();
    f != r;
    f = unicode.simpleFold(Golang.Rune(f)).toInt()
  ) {
    out.add(f);
  }
  return _orbitCache[r] = out;
}

/// Tabela Unicode do Go (`unicode.Categories`/`Scripts`) de `\p{Nome}`.
class _Prop {
  _Prop._(this._table);

  final unicode.RangeTable? _table; // null = Any

  bool _t(int r) => _table == null || unicode.is$(_table, Golang.Rune(r));

  /// Com `fold`: alguma runa do ciclo de dobra está na tabela (as tabelas
  /// `FoldCategory`/`FoldScript` do Go).
  bool test(int r, bool fold) {
    if (_t(r)) return true;
    if (!fold) return false;
    return _orbit(r).any(_t);
  }

  static final Map<String, unicode.RangeTable> _cats = {
    'C': unicode.c,
    'Cc': unicode.cc,
    'Cf': unicode.cf,
    'Co': unicode.co,
    'Cs': unicode.cs,
    'L': unicode.l,
    'Ll': unicode.ll,
    'Lm': unicode.lm,
    'Lo': unicode.lo,
    'Lt': unicode.lt,
    'Lu': unicode.lu,
    'M': unicode.m,
    'Mc': unicode.mc,
    'Me': unicode.me,
    'Mn': unicode.mn,
    'N': unicode.n,
    'Nd': unicode.nd,
    'Nl': unicode.nl,
    'No': unicode.no,
    'P': unicode.p,
    'Pc': unicode.pc,
    'Pd': unicode.pd,
    'Pe': unicode.pe,
    'Pf': unicode.pf,
    'Pi': unicode.pi,
    'Po': unicode.po,
    'Ps': unicode.ps,
    'S': unicode.s,
    'Sc': unicode.sc,
    'Sk': unicode.sk,
    'Sm': unicode.sm,
    'So': unicode.so,
    'Z': unicode.z,
    'Zl': unicode.zl,
    'Zp': unicode.zp,
    'Zs': unicode.zs,
  };

  /// `null` se o Go também rejeitaria o nome.
  static _Prop? lookup(String name) {
    if (name == 'Any') return _Prop._(null);
    final t = _cats[name] ?? unicode.scripts[name];
    return t == null ? null : _Prop._(t);
  }
}
