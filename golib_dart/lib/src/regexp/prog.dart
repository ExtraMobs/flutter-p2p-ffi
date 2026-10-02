part of '../../regexp.dart';

enum _Op {
  rune,
  runeFold,
  cls,
  any,
  anyNotNL,
  assertion,
  split,
  jmp,
  save,
  match,
}

class _Inst {
  _Inst(this.op);

  final _Op op;
  int x = 0, y = 0; // jmp/split: destinos; save: slot; assertion: tipo
  int rune = 0;
  List<int> orbit = const [];
  _Class? cls;
}

/// Programa para a simulação Pike (como o `regexp/syntax.Prog` do Go).
class _Prog {
  final List<_Inst> insts = [];

  static _Prog compile(_Node root) {
    final p = _Prog();
    p._add(_Op.save).x = 0;
    p._emit(root);
    p._add(_Op.save).x = 1;
    p._add(_Op.match);
    return p;
  }

  _Inst _add(_Op op) {
    final i = _Inst(op);
    insts.add(i);
    return i;
  }

  int get _pc => insts.length;

  void _emit(_Node n) {
    switch (n.k) {
      case _K.nop:
        break;
      case _K.lit:
        if (n.fold) {
          final o = _orbit(n.rune);
          if (o.length > 1) {
            _add(_Op.runeFold).orbit = o;
            break;
          }
        }
        _add(_Op.rune).rune = n.rune;
      case _K.cls:
        _add(_Op.cls).cls = n.cls;
      case _K.any:
        _add(n.flag ? _Op.any : _Op.anyNotNL);
      case _K.assertion:
        _add(_Op.assertion).x = n.rune;
      case _K.cat:
        n.subs.forEach(_emit);
      case _K.alt:
        final jumps = <_Inst>[];
        for (var k = 0; k < n.subs.length - 1; k++) {
          final sp = _add(_Op.split);
          sp.x = _pc;
          _emit(n.subs[k]);
          jumps.add(_add(_Op.jmp));
          sp.y = _pc;
        }
        _emit(n.subs.last);
        for (final j in jumps) {
          j.x = _pc;
        }
      case _K.cap:
        _add(_Op.save).x = 2 * n.rune;
        _emit(n.subs[0]);
        _add(_Op.save).x = 2 * n.rune + 1;
      case _K.rep:
        _rep(n);
    }
  }

  void _split(_Inst sp, bool greedy, int body, int out) {
    sp.x = greedy ? body : out;
    sp.y = greedy ? out : body;
  }

  bool _nullable(_Node n) {
    switch (n.k) {
      case _K.lit || _K.cls || _K.any:
        return false;
      case _K.assertion || _K.nop:
        return true;
      case _K.cat:
        return n.subs.every(_nullable);
      case _K.alt:
        return n.subs.any(_nullable);
      case _K.cap:
        return _nullable(n.subs[0]);
      case _K.rep:
        return n.min == 0 || _nullable(n.subs[0]);
    }
  }

  void _plus(_Node sub, bool greedy) {
    final body = _pc;
    _emit(sub);
    _split(_add(_Op.split), greedy, body, _pc);
  }

  // Como o Go: se o corpo pode casar vazio, `x*` vira `(x+)?` para manter a
  // prioridade e as capturas (`(a*)*` em "" captura "").
  void _star(_Node sub, bool greedy) {
    if (_nullable(sub)) {
      final sp = _add(_Op.split);
      final body = _pc;
      _plus(sub, greedy);
      _split(sp, greedy, body, _pc);
      return;
    }
    final spPc = _pc;
    final sp = _add(_Op.split);
    final body = _pc;
    _emit(sub);
    _add(_Op.jmp).x = spPc;
    _split(sp, greedy, body, _pc);
  }

  void _rep(_Node n) {
    final sub = n.subs[0];
    if (n.max < 0) {
      if (n.min == 0) return _star(sub, n.flag);
      for (var k = 0; k < n.min - 1; k++) {
        _emit(sub);
      }
      return _plus(sub, n.flag);
    }
    for (var k = 0; k < n.min; k++) {
      _emit(sub);
    }
    final splits = <_Inst>[];
    for (var k = n.min; k < n.max; k++) {
      final sp = _add(_Op.split);
      splits.add(sp);
      sp.x = _pc;
      _emit(sub);
    }
    for (final sp in splits) {
      _split(sp, n.flag, sp.x, _pc);
    }
  }
}
