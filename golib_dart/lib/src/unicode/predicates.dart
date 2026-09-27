part of '../../unicode.dart';

// Constantes fixas do padrão Unicode (não mudam com a versão de dados):
// `unicode.Version` (a versão dos dados) mora em tables.g.dart, gerado.

/// `unicode.MaxRune`.
const maxRune = 0x10ffff;

/// `unicode.ReplacementChar`.
const replacementChar = 0xfffd;

/// `unicode.MaxASCII`.
const maxASCII = 0x7f;

/// `unicode.MaxLatin1`.
const maxLatin1 = 0xff;

// As predicados abaixo sempre usam a tabela cheia (is_/isExcludingLatin
// coincidem: ver o comentário em RangeTable). Não há tabela `properties`
// separada para o atalho Latin-1 do Go — o oráculo
// (test/unicode_tables_test.dart) confere a equivalência para 0..0x10FFFF.

/// `unicode.IsUpper(r)`.
bool isUpper(Golang.Rune r) => _is(upper, r.toInt());

/// `unicode.IsLower(r)`.
bool isLower(Golang.Rune r) => _is(lower, r.toInt());

/// `unicode.IsTitle(r)`: a categoria `Lt` não tem entradas até `MaxLatin1`,
/// então a tabela cheia já concorda com o atalho do Go de recusar direto
/// (oráculo).
bool isTitle(Golang.Rune r) => _is(title, r.toInt());

/// `unicode.IsLetter(r)`.
bool isLetter(Golang.Rune r) => _is(letter, r.toInt());

/// `unicode.IsMark(r)`.
bool isMark(Golang.Rune r) => _is(mark, r.toInt());

/// `unicode.IsNumber(r)`.
bool isNumber(Golang.Rune r) => _is(number, r.toInt());

/// `unicode.IsDigit(r)`.
bool isDigit(Golang.Rune r) => _is(digit, r.toInt());

/// `unicode.IsPunct(r)`.
bool isPunct(Golang.Rune r) => _is(punct, r.toInt());

/// `unicode.IsSymbol(r)`.
bool isSymbol(Golang.Rune r) => _is(symbol, r.toInt());

/// `unicode.IsSpace(r)`.
bool isSpace(Golang.Rune r) => _is(white_Space, r.toInt());

/// `unicode.IsControl(r)`: só há controles até `MaxLatin1` (categoria `Cc`);
/// a tabela cheia já não tem nada acima disso, então a varredura direta
/// concorda com o atalho do Go (oráculo).
bool isControl(Golang.Rune r) => _is(cc, r.toInt());

/// `unicode.GraphicRanges`: `L`, `M`, `N`, `P`, `S`, `Zs`.
List<RangeTable> _graphicRanges() => [l, m, n, p, s, zs];

/// `unicode.PrintRanges`: `L`, `M`, `N`, `P`, `S`.
List<RangeTable> _printRanges() => [l, m, n, p, s];

/// `unicode.IsGraphic(r)`.
bool isGraphic(Golang.Rune r) {
  final v = r.toInt();
  for (final t in _graphicRanges()) {
    if (_is(t, v)) return true;
  }
  return false;
}

/// `unicode.IsPrint(r)`: como [isGraphic], mas só o espaço ASCII entre os
/// separadores.
bool isPrint(Golang.Rune r) {
  final v = r.toInt();
  if (v == 0x20) return true;
  for (final t in _printRanges()) {
    if (_is(t, v)) return true;
  }
  return false;
}

/// `unicode.To(_case, r)`.
Golang.Rune to(Golang.Int case_, Golang.Rune r) {
  final (mapped, _) = _to(case_.toInt(), r.toInt(), _caseRanges);
  return Golang.Rune(mapped);
}

/// `unicode.ToUpper(r)`: atalho ASCII, senão [to] com `UpperCase`.
Golang.Rune toUpper(Golang.Rune r) {
  final v = r.toInt();
  if (v <= maxASCII) {
    return Golang.Rune(v >= 0x61 && v <= 0x7a ? v - 0x20 : v);
  }
  final (mapped, _) = _to(upperCase, v, _caseRanges);
  return Golang.Rune(mapped);
}

/// `unicode.ToLower(r)`: atalho ASCII, senão [to] com `LowerCase`.
Golang.Rune toLower(Golang.Rune r) {
  final v = r.toInt();
  if (v <= maxASCII) {
    return Golang.Rune(v >= 0x41 && v <= 0x5a ? v + 0x20 : v);
  }
  final (mapped, _) = _to(lowerCase, v, _caseRanges);
  return Golang.Rune(mapped);
}

/// `unicode.ToTitle(r)`: atalho ASCII (igual a maiúscula), senão [to] com
/// `TitleCase`.
Golang.Rune toTitle(Golang.Rune r) {
  final v = r.toInt();
  if (v <= maxASCII) {
    return Golang.Rune(v >= 0x61 && v <= 0x7a ? v - 0x20 : v);
  }
  final (mapped, _) = _to(titleCase, v, _caseRanges);
  return Golang.Rune(mapped);
}

/// `unicode.SimpleFold(r)`: próxima runa equivalente por *simple case
/// folding* (ciclo; a menor > r, ou a menor >= 0 se r for a maior do ciclo).
/// A tabela `_foldPairs` é o ciclo completo de toda runa com
/// `SimpleFold(r) != r`, extraída direto da função real do Go pelo gerador
/// (`tool/gen_unicode_case.go`) — não precisa do `asciiFold`/`caseOrbit`
/// internos do Go (não exportados) para ser fiel: é a mesma função, só que
/// tabulada por completo em vez de calculada a partir de `CaseRanges` mais
/// as exceções.
Golang.Rune simpleFold(Golang.Rune r) {
  final v = r.toInt();
  if (v < 0 || v > maxRune) return r;
  var lo = 0, hi = _foldPairs.length;
  while (lo < hi) {
    final m = (lo + hi) >> 1;
    if (_foldPairs[m].$1 < v) {
      lo = m + 1;
    } else {
      hi = m;
    }
  }
  if (lo < _foldPairs.length && _foldPairs[lo].$1 == v) {
    return Golang.Rune(_foldPairs[lo].$2);
  }
  return r;
}
