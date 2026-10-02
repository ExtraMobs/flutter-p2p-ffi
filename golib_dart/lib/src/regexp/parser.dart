part of '../../regexp.dart';

/// Resultado do parse: árvore, número de grupos e nomes (índice 0 = '').
class _Parsed {
  _Parsed(this.root, this.numCap, this.names);

  final _Node root;
  final int numCap;
  final List<String> names;
}

/// Parser descendente recursivo da sintaxe do Go (flags `syntax.Perl`),
/// com os mesmos códigos e trechos de erro do `regexp/syntax`.
class _Parser {
  _Parser(this.cur, this.whole);

  final _Cur cur;
  final String whole;
  int flags = _fOneLine;
  int numCap = 0;
  final names = <String>[''];

  static _Parsed parse(Golang.String expr) {
    final bytes = expr.toBytes();
    final runes = <int>[];
    for (var i = 0; i < bytes.length;) {
      final (r, w) = _decodeRune(bytes, i);
      if (r == 0xfffd && w == 1) {
        throw _SyntaxError(
          'invalid UTF-8',
          utf8.decode(bytes.sublist(i), allowMalformed: true),
          bytes.sublist(i),
        );
      }
      runes.add(r);
      i += w;
    }
    final p = _Parser(_Cur(runes), String.fromCharCodes(runes));
    final root = p._alt();
    if (!p.cur.eof) throw _SyntaxError('unexpected )', p.whole);
    return _Parsed(root, p.numCap, p.names);
  }

  _Node _alt() {
    final branches = [_concat()];
    while (!cur.eof && cur.peek == 0x7c) {
      cur.i++;
      branches.add(_concat());
    }
    if (branches.length == 1) return branches[0];
    return _Node(_K.alt)..subs = branches;
  }

  _Node _concat() {
    final items = <_Node>[];
    var lastRepeat = -1;
    while (!cur.eof) {
      final c = cur.peek;
      if (c == 0x7c || c == 0x29) break;
      final tokStart = cur.i;
      var repeat = -1;
      switch (c) {
        case 0x28:
          final n = _group();
          if (n != null) items.add(n);
        case 0x5e:
          cur.i++;
          items.add(
            _Node.assertion(flags & _fOneLine != 0 ? _aBeginText : _aBeginLine),
          );
        case 0x24:
          cur.i++;
          items.add(
            _Node.assertion(flags & _fOneLine != 0 ? _aEndText : _aEndLine),
          );
        case 0x2e:
          cur.i++;
          items.add(_Node(_K.any)..flag = flags & _fDotNL != 0);
        case 0x5b:
          items.add(_parseClass(cur, flags));
        case 0x2a || 0x2b || 0x3f:
          cur.i++;
          final (min, max) = switch (c) {
            0x2a => (0, -1),
            0x2b => (1, -1),
            _ => (0, 1),
          };
          _repeat(items, min, max, tokStart, lastRepeat);
          repeat = tokStart;
        case 0x7b:
          final r = _parseRepeat();
          if (r == null) {
            cur.i++;
            items.add(_Node.lit(0x7b, false));
            break;
          }
          final (min, max) = r;
          if (min < 0 || min > 1000 || max > 1000 || (max >= 0 && min > max)) {
            throw _SyntaxError('invalid repeat count', cur.text(tokStart));
          }
          _repeat(items, min, max, tokStart, lastRepeat);
          repeat = tokStart;
        case 0x5c:
          _backslash(items);
        default:
          cur.i++;
          items.add(_Node.lit(c, flags & _fFold != 0));
      }
      lastRepeat = repeat;
    }
    if (items.isEmpty) return _Node(_K.nop);
    if (items.length == 1) return items[0];
    return _Node(_K.cat)..subs = items;
  }

  // Operador de repetição já consumido (até antes de um `?` guloso/preguiçoso).
  void _repeat(
    List<_Node> items,
    int min,
    int max,
    int tokStart,
    int lastRepeat,
  ) {
    var greedy = flags & _fNonGreedy == 0;
    if (!cur.eof && cur.peek == 0x3f) {
      cur.i++;
      greedy = !greedy;
    }
    if (lastRepeat >= 0) {
      throw _SyntaxError(
        'invalid nested repetition operator',
        cur.text(lastRepeat),
      );
    }
    if (items.isEmpty) {
      throw _SyntaxError(
        'missing argument to repetition operator',
        cur.text(tokStart),
      );
    }
    final rep = _Node(_K.rep)
      ..subs = [items.removeLast()]
      ..min = min
      ..max = max
      ..flag = greedy;
    if ((min >= 2 || max >= 2) && !_repeatOk(rep, 1000)) {
      // O Go indica só o operador (sem o `?` preguiçoso).
      var end = cur.i;
      if (cur.s[end - 1] == 0x3f && end - 1 > tokStart) end--;
      throw _SyntaxError('invalid repeat count', cur.text(tokStart, end));
    }
    items.add(rep);
  }

  bool _repeatOk(_Node n, int limit) {
    if (n.k == _K.rep) {
      var m = n.max;
      if (m == 0) return true;
      if (m < 0) m = n.min;
      if (m > limit) return false;
      if (m > 0) limit ~/= m;
    }
    for (final s in n.subs) {
      if (!_repeatOk(s, limit)) return false;
    }
    return true;
  }

  int? _parseInt() {
    if (cur.eof || cur.peek < 0x30 || cur.peek > 0x39) return null;
    if (cur.left >= 2 &&
        cur.peek == 0x30 &&
        cur.s[cur.i + 1] >= 0x30 &&
        cur.s[cur.i + 1] <= 0x39) {
      return null;
    }
    var n = 0, over = false;
    while (!cur.eof && cur.peek >= 0x30 && cur.peek <= 0x39) {
      n = n * 10 + cur.s[cur.i++] - 0x30;
      if (n > 100000000) {
        over = true;
        n = 100000001;
      }
    }
    return over ? -1 : n;
  }

  /// `{n}`, `{n,}`, `{n,m}` em `cur.i`; consome só se válido.
  (int, int)? _parseRepeat() {
    final save = cur.i;
    (int, int)? fail() {
      cur.i = save;
      return null;
    }

    cur.i++;
    final lo = _parseInt();
    if (lo == null || cur.eof) return fail();
    int hi;
    if (cur.peek != 0x2c) {
      hi = lo;
    } else {
      cur.i++;
      if (cur.eof) return fail();
      if (cur.peek == 0x7d) {
        hi = -1;
      } else {
        final h = _parseInt();
        if (h == null) return fail();
        hi = h;
      }
    }
    if (cur.eof || cur.peek != 0x7d) return fail();
    cur.i++;
    return (lo, hi);
  }

  void _backslash(List<_Node> items) {
    if (cur.left >= 2) {
      switch (cur.s[cur.i + 1]) {
        case 0x41:
          cur.i += 2;
          items.add(_Node.assertion(_aBeginText));
          return;
        case 0x62:
          cur.i += 2;
          items.add(_Node.assertion(_aWordB));
          return;
        case 0x42:
          cur.i += 2;
          items.add(_Node.assertion(_aNoWordB));
          return;
        case 0x51:
          cur.i += 2;
          var end = cur.s.length;
          for (var k = cur.i; k + 1 < cur.s.length; k++) {
            if (cur.s[k] == 0x5c && cur.s[k + 1] == 0x45) {
              end = k;
              break;
            }
          }
          for (var k = cur.i; k < end; k++) {
            items.add(_Node.lit(cur.s[k], flags & _fFold != 0));
          }
          cur.i = end == cur.s.length ? end : end + 2;
          return;
        case 0x7a:
          cur.i += 2;
          items.add(_Node.assertion(_aEndText));
          return;
      }
    }
    final cls = _Class()..fold = flags & _fFold != 0;
    if (_parseUnicodeClass(cur, cls) || _parsePerlClass(cur, cls)) {
      items.add(_Node(_K.cls)..cls = cls);
      return;
    }
    items.add(_Node.lit(_parseEscape(cur), flags & _fFold != 0));
  }

  static bool _wordChar(int c) => c == 0x5f || _isAlnum(c);

  /// `(` em `cur.i`: grupo ou flags `(?i)`; `null` se só mudou as flags.
  _Node? _group() {
    final start = cur.i;
    final saved = flags;
    if (cur.at(1, 0x3f)) {
      final left = cur.left;
      final named =
          (left > 4 && cur.at(2, 0x50) && cur.at(3, 0x3c)) ||
          (left > 3 && cur.at(2, 0x3c));
      if (named) {
        final begin = start + (cur.at(2, 0x50) ? 4 : 3);
        var end = -1;
        for (var k = start; k < cur.s.length; k++) {
          if (cur.s[k] == 0x3e) {
            end = k;
            break;
          }
        }
        if (end < 0) {
          throw _SyntaxError(
            'invalid named capture',
            cur.text(start, cur.s.length),
          );
        }
        final name = cur.text(begin, end);
        if (name.isEmpty || !name.runes.every(_wordChar)) {
          throw _SyntaxError('invalid named capture', cur.text(start, end + 1));
        }
        cur.i = end + 1;
        final idx = ++numCap;
        names.add(name);
        return _closeGroup(idx, saved);
      }
      // Grupo sem captura ou flags.
      cur.i += 2;
      var f = flags;
      var sign = 1;
      var sawFlag = false;
      while (!cur.eof) {
        final c = cur.s[cur.i++];
        switch (c) {
          case 0x69:
            f |= _fFold;
            sawFlag = true;
            continue;
          case 0x6d:
            f &= ~_fOneLine;
            sawFlag = true;
            continue;
          case 0x73:
            f |= _fDotNL;
            sawFlag = true;
            continue;
          case 0x55:
            f |= _fNonGreedy;
            sawFlag = true;
            continue;
          case 0x2d:
            if (sign < 0) break;
            sign = -1;
            f = ~f;
            sawFlag = false;
            continue;
          case 0x3a || 0x29:
            if (sign < 0) {
              if (!sawFlag) break;
              f = ~f;
            }
            if (c == 0x3a) {
              flags = f;
              return _closeGroup(0, saved);
            }
            flags = f;
            return null;
        }
        break;
      }
      throw _SyntaxError('invalid or unsupported Perl syntax', cur.text(start));
    }
    cur.i++;
    final idx = ++numCap;
    names.add('');
    return _closeGroup(idx, saved);
  }

  _Node _closeGroup(int idx, int saved) {
    final inner = _alt();
    if (cur.eof) throw _SyntaxError('missing closing )', whole);
    cur.i++; // ')'
    flags = saved;
    if (idx == 0) return inner;
    return _Node(_K.cap)
      ..rune = idx
      ..subs = [inner];
  }
}
