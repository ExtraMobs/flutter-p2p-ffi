part of '../../regexp.dart';

/// DecodeRune do Go sobre bytes: byte inválido, sequência curta, overlong,
/// surrogate ou acima de U+10FFFF dão (U+FFFD, 1).
(int, int) _decodeRune(Uint8List b, int i) {
  final c0 = b[i];
  if (c0 < 0x80) return (c0, 1);
  int n, lo = 0x80, hi = 0xbf;
  if (c0 >= 0xc2 && c0 <= 0xdf) {
    n = 2;
  } else if (c0 >= 0xe0 && c0 <= 0xef) {
    n = 3;
    if (c0 == 0xe0) lo = 0xa0;
    if (c0 == 0xed) hi = 0x9f;
  } else if (c0 >= 0xf0 && c0 <= 0xf4) {
    n = 4;
    if (c0 == 0xf0) lo = 0x90;
    if (c0 == 0xf4) hi = 0x8f;
  } else {
    return (0xfffd, 1);
  }
  if (i + n > b.length) return (0xfffd, 1);
  final c1 = b[i + 1];
  if (c1 < lo || c1 > hi) return (0xfffd, 1);
  if (n == 2) return (((c0 & 0x1f) << 6) | (c1 & 0x3f), 2);
  final c2 = b[i + 2];
  if (c2 < 0x80 || c2 > 0xbf) return (0xfffd, 1);
  if (n == 3) {
    return (((c0 & 0x0f) << 12) | ((c1 & 0x3f) << 6) | (c2 & 0x3f), 3);
  }
  final c3 = b[i + 3];
  if (c3 < 0x80 || c3 > 0xbf) return (0xfffd, 1);
  return (
    ((c0 & 0x07) << 18) |
        ((c1 & 0x3f) << 12) |
        ((c2 & 0x3f) << 6) |
        (c3 & 0x3f),
    4,
  );
}

bool _isWordByte(int c) => c == 0x5f || _isAlnum(c);

/// Simulação Pike (leftmost-first, como o `regexp` do Go): threads em ordem
/// de prioridade; o primeiro `match` corta as de menor prioridade.
class _Machine {
  _Machine(this.prog, this.b);

  final _Prog prog;
  final Uint8List b;
  late final List<int> _mark = List.filled(prog.insts.length, 0);
  int _gen = 0;

  bool _assertion(int kind, int pos) {
    switch (kind) {
      case _aBeginText:
        return pos == 0;
      case _aEndText:
        return pos == b.length;
      case _aBeginLine:
        return pos == 0 || b[pos - 1] == 10;
      case _aEndLine:
        return pos == b.length || b[pos] == 10;
      default:
        final before = pos > 0 && _isWordByte(b[pos - 1]);
        final after = pos < b.length && _isWordByte(b[pos]);
        return (before != after) == (kind == _aWordB);
    }
  }

  void _addThread(
    List<int> pcs,
    List<List<int>> caps,
    int pc0,
    int pos,
    List<int> c0,
  ) {
    final stackPc = <int>[pc0];
    final stackCap = <List<int>>[c0];
    while (stackPc.isNotEmpty) {
      final pc = stackPc.removeLast();
      var cap = stackCap.removeLast();
      if (_mark[pc] == _gen) continue;
      _mark[pc] = _gen;
      final inst = prog.insts[pc];
      switch (inst.op) {
        case _Op.jmp:
          stackPc.add(inst.x);
          stackCap.add(cap);
        case _Op.split:
          stackPc.add(inst.y);
          stackCap.add(cap);
          stackPc.add(inst.x);
          stackCap.add(cap);
        case _Op.save:
          if (inst.x < cap.length) cap = List<int>.of(cap)..[inst.x] = pos;
          stackPc.add(pc + 1);
          stackCap.add(cap);
        case _Op.assertion:
          if (_assertion(inst.x, pos)) {
            stackPc.add(pc + 1);
            stackCap.add(cap);
          }
        default:
          pcs.add(pc);
          caps.add(cap);
      }
    }
  }

  /// Primeiro casamento (leftmost-first) com início em `>= start`; devolve
  /// os `ncap` (>= 2) índices de byte (-1 = grupo não participou) ou `null`.
  List<int>? exec(int start, int ncap) {
    final n = b.length;
    final zero = List<int>.filled(ncap, -1);
    var cpcs = <int>[], ccaps = <List<int>>[];
    var npcs = <int>[], ncaps = <List<int>>[];
    List<int>? matched;
    var pos = start;
    _gen++;
    while (true) {
      if (matched == null) _addThread(cpcs, ccaps, 0, pos, zero);
      if (cpcs.isEmpty && (matched != null || pos >= n)) break;
      var r = -1, w = 0;
      if (pos < n) (r, w) = _decodeRune(b, pos);
      _gen++;
      npcs.clear();
      ncaps.clear();
      for (var t = 0; t < cpcs.length; t++) {
        final inst = prog.insts[cpcs[t]];
        final bool ok;
        switch (inst.op) {
          case _Op.match:
            matched = ccaps[t];
            t = cpcs.length;
            continue;
          case _Op.rune:
            ok = r == inst.rune;
          case _Op.runeFold:
            ok = r >= 0 && inst.orbit.contains(r);
          case _Op.cls:
            ok = r >= 0 && inst.cls!.matches(r);
          case _Op.any:
            ok = r >= 0;
          case _Op.anyNotNL:
            ok = r >= 0 && r != 10;
          default:
            ok = false;
        }
        if (ok) _addThread(npcs, ncaps, cpcs[t] + 1, pos + w, ccaps[t]);
      }
      (cpcs, npcs) = (npcs, cpcs);
      (ccaps, ncaps) = (ncaps, ccaps);
      if (pos >= n) break;
      pos += w;
    }
    return matched;
  }
}
