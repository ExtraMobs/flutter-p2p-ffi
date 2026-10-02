part of '../../unicode.dart';

const _range16Elem = Elem<Range16>(6, Range16.new);
const _range32Elem = Elem<Range32>(12, Range32.new);

Slice<Range16> _nilR16() => Slice.nil(_range16Elem);
Slice<Range32> _nilR32() => Slice.nil(_range32Elem);

/// `unicode.Range16`: struct de shim (`go.GoStruct`, como `bytes.Buffer`) —
/// faixa fechada [Lo, Hi] com passo Stride, para runas até 0xFFFF. Aceita o
/// literal composto Go (`unicode.Range16{0x41, 0x5a, 1}`) porque o g2d lê os
/// campos do struct (`go/types`) e chama o construtor por nome, qualquer que
/// seja o pacote dono do tipo.
final class Range16 extends GoStruct<Range16> {
  Range16({Golang.Uint16? lo, Golang.Uint16? hi, Golang.Uint16? stride})
    : lo = lo ?? Golang.Uint16(0),
      hi = hi ?? Golang.Uint16(0),
      stride = stride ?? Golang.Uint16(0);

  Golang.Uint16 lo;
  Golang.Uint16 hi;
  Golang.Uint16 stride;

  @override
  String get $goType => 'unicode.Range16';

  @override
  Range16 $copy() => Range16(lo: lo, hi: hi, stride: stride);

  @override
  void $set(Range16 o) {
    lo = o.lo;
    hi = o.hi;
    stride = o.stride;
  }

  @override
  List<Object?> get $fields => [lo, hi, stride];

  @override
  List<String> get $fieldNames => const ['Lo', 'Hi', 'Stride'];
}

/// `unicode.Range32`: como [Range16], para runas >= 0x10000.
final class Range32 extends GoStruct<Range32> {
  Range32({Golang.Uint32? lo, Golang.Uint32? hi, Golang.Uint32? stride})
    : lo = lo ?? Golang.Uint32(0),
      hi = hi ?? Golang.Uint32(0),
      stride = stride ?? Golang.Uint32(0);

  Golang.Uint32 lo;
  Golang.Uint32 hi;
  Golang.Uint32 stride;

  @override
  String get $goType => 'unicode.Range32';

  @override
  Range32 $copy() => Range32(lo: lo, hi: hi, stride: stride);

  @override
  void $set(Range32 o) {
    lo = o.lo;
    hi = o.hi;
    stride = o.stride;
  }

  @override
  List<Object?> get $fields => [lo, hi, stride];

  @override
  List<String> get $fieldNames => const ['Lo', 'Hi', 'Stride'];
}

/// `unicode.RangeTable`: um conjunto de runas como faixas de 16 e 32 bits
/// ordenadas (`R16`, `R32`); `LatinOffset` é só uma dica de atalho do Go (as
/// primeiras `LatinOffset` entradas de `R16` cobrem até `MaxLatin1`) — aqui
/// [is_] sempre varre `R16` inteiro, então o resultado é o mesmo com ou sem
/// o atalho (conferido pelo oráculo para os 0x00..0xFF).
final class RangeTable extends GoStruct<RangeTable> {
  RangeTable({
    Slice<Range16>? r16,
    Slice<Range32>? r32,
    Golang.Int? latinOffset,
  }) : r16 = r16 ?? _nilR16(),
       r32 = r32 ?? _nilR32(),
       latinOffset = latinOffset ?? Golang.Int(0);

  Slice<Range16> r16;
  Slice<Range32> r32;
  Golang.Int latinOffset;

  @override
  String get $goType => 'unicode.RangeTable';

  @override
  RangeTable $copy() =>
      RangeTable(r16: r16, r32: r32, latinOffset: latinOffset);

  @override
  void $set(RangeTable o) {
    r16 = o.r16;
    r32 = o.r32;
    latinOffset = o.latinOffset;
  }

  @override
  List<Object?> get $fields => [r16, r32, latinOffset];

  @override
  List<String> get $fieldNames => const ['R16', 'R32', 'LatinOffset'];
}

/// Tamanho máximo de tabela para busca linear (`unicode.linearMax` do Go).
const _linearMax = 18;

bool _is16(Slice<Range16> ranges, int r) {
  final n = ranges.length;
  if (n <= _linearMax || r <= 0xff) {
    for (var i = 0; i < n; i++) {
      final rg = ranges[i];
      final lo = rg.lo.toInt();
      if (r < lo) return false;
      final hi = rg.hi.toInt();
      if (r <= hi) {
        final stride = rg.stride.toInt();
        return stride == 1 || (r - lo) % stride == 0;
      }
    }
    return false;
  }
  var lo = 0, hi = n;
  while (lo < hi) {
    final m = (lo + hi) >> 1;
    final rg = ranges[m];
    final rgLo = rg.lo.toInt(), rgHi = rg.hi.toInt();
    if (rgLo <= r && r <= rgHi) {
      final stride = rg.stride.toInt();
      return stride == 1 || (r - rgLo) % stride == 0;
    }
    if (r < rgLo) {
      hi = m;
    } else {
      lo = m + 1;
    }
  }
  return false;
}

bool _is32(Slice<Range32> ranges, int r) {
  final n = ranges.length;
  if (n <= _linearMax) {
    for (var i = 0; i < n; i++) {
      final rg = ranges[i];
      final lo = rg.lo.toInt();
      if (r < lo) return false;
      final hi = rg.hi.toInt();
      if (r <= hi) {
        final stride = rg.stride.toInt();
        return stride == 1 || (r - lo) % stride == 0;
      }
    }
    return false;
  }
  var lo = 0, hi = n;
  while (lo < hi) {
    final m = (lo + hi) >> 1;
    final rg = ranges[m];
    final rgLo = rg.lo.toInt(), rgHi = rg.hi.toInt();
    if (rgLo <= r && r <= rgHi) {
      final stride = rg.stride.toInt();
      return stride == 1 || (r - rgLo) % stride == 0;
    }
    if (r < rgLo) {
      hi = m;
    } else {
      lo = m + 1;
    }
  }
  return false;
}

/// `unicode.Is(rangeTab, r)`: r (com o sinal, como o Go trata negativos)
/// dentro de alguma faixa de rangeTab. Nome com `$` porque `is` é reservado
/// no Dart (`services/naming.py.escape`).
bool is$(RangeTable? rangeTab, Golang.Rune r) => _is(rangeTab!, r.toInt());

bool _is(RangeTable rangeTab, int r) {
  final r16 = rangeTab.r16;
  if (r16.length > 0 && r >= 0 && r <= r16[r16.length - 1].hi.toInt()) {
    return _is16(r16, r);
  }
  final r32 = rangeTab.r32;
  if (r32.length > 0 && r >= r32[0].lo.toInt()) return _is32(r32, r);
  return false;
}

/// `unicode.In(r, ranges...)`. O variádico `...*RangeTable` vira uma lista
/// Dart simples: nenhum pacote do grafo chama `In`/`IsOneOf` hoje
/// (`docs/stdlib-coverage.md`), então a ABI exata do variádico não foi
/// exercitada; ajustar para `go.Slice` se um caso real precisar.
bool in$(Golang.Rune r, List<RangeTable?> ranges) {
  for (final t in ranges) {
    if (is$(t, r)) return true;
  }
  return false;
}

/// `unicode.IsOneOf(ranges, r)`: como [in$], argumentos trocados.
bool isOneOf(List<RangeTable?> ranges, Golang.Rune r) => in$(r, ranges);

/// `unicode.CaseRange`: uma faixa de mapeamento de caixa 1:1. `Delta` é
/// `List<int>` (3 posições: Upper/Lower/Title) em vez do array Go `d
/// [MaxCase]rune`: `d` não é exportado, então nenhum código fora do pacote
/// `unicode` consegue nomeá-lo (só indexar `cr.Delta[i]`, que `List<int>`
/// cobre) nem montar um `CaseRange{}` de fora — não há literal composto real
/// para casar.
final class CaseRange extends GoStruct<CaseRange> {
  CaseRange({Golang.Uint32? lo, Golang.Uint32? hi, List<int>? delta})
    : lo = lo ?? Golang.Uint32(0),
      hi = hi ?? Golang.Uint32(0),
      delta = delta ?? const [0, 0, 0];

  Golang.Uint32 lo;
  Golang.Uint32 hi;
  List<int> delta;

  @override
  String get $goType => 'unicode.CaseRange';

  @override
  CaseRange $copy() => CaseRange(lo: lo, hi: hi, delta: delta);

  @override
  void $set(CaseRange o) {
    lo = o.lo;
    hi = o.hi;
    delta = o.delta;
  }

  @override
  List<Object?> get $fields => [lo, hi, delta];

  @override
  List<String> get $fieldNames => const ['Lo', 'Hi', 'Delta'];
}

const _caseRangeElem = Elem<CaseRange>(20, CaseRange.new);

/// Índices em `Delta` (`unicode.UpperCase`/`LowerCase`/`TitleCase`).
const upperCase = 0;
const lowerCase = 1;
const titleCase = 2;
const maxCase = 3;

/// `unicode.UpperLower`: delta impossível, marca um par Upper/Lower
/// alternado (`unicode.convertCase`).
const upperLower = maxRune + 1;

CaseRange? _lookupCaseRange(int r, List<CaseRange> ranges) {
  var lo = 0, hi = ranges.length;
  while (lo < hi) {
    final m = (lo + hi) >> 1;
    final cr = ranges[m];
    final crLo = cr.lo.toInt(), crHi = cr.hi.toInt();
    if (crLo <= r && r <= crHi) return cr;
    if (r < crLo) {
      hi = m;
    } else {
      lo = m + 1;
    }
  }
  return null;
}

int _convertCase(int case_, int r, CaseRange cr) {
  final delta = cr.delta[case_];
  if (delta > maxRune) {
    // Sequência Upper/Lower alternada: limpa/marca o bit baixo do deslocamento
    // desde o início da faixa (par nos deslocamentos pares = Upper).
    final lo = cr.lo.toInt();
    return lo + (((r - lo) & ~1) | (case_ & 1));
  }
  return r + delta;
}

(int, bool) _to(int case_, int r, List<CaseRange> ranges) {
  if (case_ < 0 || maxCase <= case_) return (replacementChar, false);
  final cr = _lookupCaseRange(r, ranges);
  if (cr != null) return (_convertCase(case_, r, cr), true);
  return (r, false);
}
