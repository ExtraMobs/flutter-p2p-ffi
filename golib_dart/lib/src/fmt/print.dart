part of '../../fmt.dart';

/// Um `pp` do Go (`fmt/print.go`): o laço do formato, os operandos e os
/// métodos que o fmt chama (Formatter, error, Stringer). Flags, largura,
/// precisão e padding ficam no [_Fmt] dele, sobre o mesmo buffer. O que não
/// está portado lança [UnimplementedError] (nunca formata diferente do Go em
/// silêncio).
final class _Printer implements State {
  _Printer(this.args, {this.wrapErrs = false});

  final List<Object?> args;
  final bool wrapErrs;
  final wrapped = <int>[];
  final _b = BytesBuilder(copy: false);
  late final _fmt = _Fmt(_b);

  bool _erroring = false;
  bool goodArgNum = true;
  bool reordered = false;
  Object? _arg;

  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) {
    _b.add(Uint8List.fromList([for (final x in p.items) x.toInt()]));
    return (Golang.Int(p.length), null);
  }

  @override
  (Golang.Int, bool) width() => (Golang.Int(_fmt.wid), _fmt.widPresent);

  @override
  (Golang.Int, bool) precision() => (Golang.Int(_fmt.prec), _fmt.precPresent);

  @override
  bool flag(Golang.Int c) => switch (c.toInt()) {
    0x2d => _fmt.minus,
    0x2b => _fmt.plus || _fmt.plusV,
    0x23 => _fmt.sharp || _fmt.sharpV,
    0x20 => _fmt.space,
    0x30 => _fmt.zero,
    _ => false,
  };

  Uint8List run(Uint8List f) {
    final end = f.length;
    var argNum = 0;
    var i = 0;
    while (i < end) {
      final last = i;
      while (i < end && f[i] != 0x25) {
        i++;
      }
      if (i > last) _b.add(Uint8List.sublistView(f, last, i));
      if (i >= end) break;
      i++; // '%'
      _fmt.clearFlags();
      flags:
      for (; i < end; i++) {
        switch (f[i]) {
          case 0x23: // '#'
            _fmt.sharp = true;
          case 0x30: // '0'
            _fmt.zero = !_fmt.minus;
          case 0x2b: // '+'
            _fmt.plus = true;
          case 0x2d: // '-'
            _fmt.minus = true;
            _fmt.zero = false;
          case 0x20: // ' '
            _fmt.space = true;
          default:
            break flags;
        }
      }
      goodArgNum = true;
      var afterIndex = false;
      (argNum, i, afterIndex) = _argNumber(argNum, f, i);
      if (i < end && f[i] == 0x2a) {
        i++;
        final (w, ok, n) = _intFromArg(argNum);
        _fmt.wid = w;
        _fmt.widPresent = ok;
        argNum = n;
        if (!_fmt.widPresent) _b.add(_ascii('%!(BADWIDTH)'));
        if (_fmt.wid < 0) {
          _fmt.wid = -_fmt.wid;
          _fmt.minus = true;
          _fmt.zero = false;
        }
        afterIndex = false;
      } else {
        final (w, ok, n) = _parseNum(f, i, end);
        _fmt.wid = w;
        _fmt.widPresent = ok;
        i = n;
        if (afterIndex && _fmt.widPresent) goodArgNum = false; // "%[3]2d"
      }
      if (i + 1 < end && f[i] == 0x2e) {
        i++;
        if (afterIndex) goodArgNum = false; // "%[3].2d"
        (argNum, i, afterIndex) = _argNumber(argNum, f, i);
        if (i < end && f[i] == 0x2a) {
          i++;
          final (w, ok, n) = _intFromArg(argNum);
          _fmt.prec = w;
          _fmt.precPresent = ok;
          argNum = n;
          if (_fmt.prec < 0) {
            _fmt.prec = 0;
            _fmt.precPresent = false;
          }
          if (!_fmt.precPresent) _b.add(_ascii('%!(BADPREC)'));
          afterIndex = false;
        } else {
          final (w, ok, n) = _parseNum(f, i, end);
          _fmt.prec = w;
          _fmt.precPresent = ok;
          i = n;
          if (!_fmt.precPresent) {
            _fmt.prec = 0;
            _fmt.precPresent = true;
          }
        }
      }
      if (!afterIndex) (argNum, i, afterIndex) = _argNumber(argNum, f, i);
      if (i >= end) {
        _b.add(_ascii('%!(NOVERB)'));
        break;
      }
      final (verb, size) = _decodeRune(f, i);
      i += size;
      if (verb == 0x25) {
        _b.addByte(0x25); // `%%` não consome operando nem usa largura
        continue;
      }
      if (!goodArgNum) {
        _b.add(_ascii('%!'));
        _writeRune(verb);
        _b.add(_ascii('(BADINDEX)'));
        continue;
      }
      if (argNum >= args.length) {
        _b.add(_ascii('%!'));
        _writeRune(verb);
        _b.add(_ascii('(MISSING)'));
        continue;
      }
      if (verb == 0x77) wrapped.add(argNum); // 'w'
      if (verb == 0x76 || verb == 0x77) {
        _fmt.sharpV = _fmt.sharp;
        _fmt.sharp = false;
        _fmt.plusV = _fmt.plus;
        _fmt.plus = false;
      }
      _printArg(args[argNum], verb, 0);
      argNum++;
    }
    // Com índice explícito o Go não confere operandos sobrando.
    if (!reordered && argNum < args.length) {
      _fmt.clearFlags();
      _b.add(_ascii('%!(EXTRA '));
      for (var k = argNum; k < args.length; k++) {
        if (k > argNum) _b.add(_ascii(', '));
        final a = args[k];
        if (a == null) {
          _b.add(_ascii('<nil>'));
        } else {
          _b.add(utf8.encode(_typeName(a)));
          _b.addByte(0x3d);
          _printArg(a, 0x76, 0);
        }
      }
      _b.addByte(0x29);
    }
    return _b.takeBytes();
  }

  /// `argNumber` do Go: `[n]` em `f[i]` escolhe o operando (base 1).
  (int, int, bool) _argNumber(int argNum, Uint8List f, int i) {
    if (i >= f.length || f[i] != 0x5b) return (argNum, i, false);
    reordered = true;
    final (index, wid, ok) = _parseArgNumber(f, i);
    if (ok && index >= 0 && index < args.length) return (index, i + wid, true);
    goodArgNum = false;
    return (argNum, i + wid, ok);
  }

  /// `parseArgNumber` do Go: (índice base 0, bytes consumidos, ok).
  static (int, int, bool) _parseArgNumber(Uint8List f, int start) {
    if (f.length - start < 3) return (0, 1, false);
    for (var i = start + 1; i < f.length; i++) {
      if (f[i] == 0x5d) {
        final (width, ok, newi) = _parseNum(f, start + 1, i);
        if (!ok || newi != i) return (0, i - start + 1, false);
        return (width - 1, i - start + 1, true);
      }
    }
    return (0, 1, false);
  }

  (int, bool, int) _intFromArg(int argNum) {
    if (argNum >= args.length) return (0, false, argNum);
    final a = args[argNum];
    if (a is Golang.IntBase) {
      final n = a.toBigInt();
      if (n.abs() <= BigInt.from(1000000)) return (n.toInt(), true, argNum + 1);
    }
    return (0, false, argNum + 1);
  }

  static (int, bool, int) _parseNum(Uint8List s, int start, int end) {
    if (start >= end) return (0, false, end);
    var num = 0;
    var isNum = false;
    var i = start;
    for (; i < end && s[i] >= 0x30 && s[i] <= 0x39; i++) {
      if (num > 1000000) return (0, false, end);
      num = num * 10 + s[i] - 0x30;
      isNum = true;
    }
    return (num, isNum, i);
  }

  void _writeRune(int r) =>
      _b.add(utf8.encode(String.fromCharCode(_validRune(r))));

  // -------------------------------------------------------------- operandos
  void _printArg(Object? arg, int verb, int depth) {
    _arg = arg;
    if (arg == null) {
      if (verb == 0x54 || verb == 0x76) {
        _fmt.pad(_ascii('<nil>'));
      } else {
        _badVerb(verb);
      }
      return;
    }
    if (verb == 0x54) {
      _fmt.pad(utf8.encode(_typeName(arg))); // %T
      return;
    }
    if (verb == 0x70) {
      // %p (antes dos métodos, como o Go): 0x + hex; %#p sem o 0x.
      final a = _pointerOf(arg);
      if (a == null) {
        _badVerb(verb);
      } else {
        _fmt.pad(_ascii(_fmt.sharp ? _hexAddr(a) : '0x${_hexAddr(a)}'));
      }
      return;
    }
    if (_handleMethods(verb, depth > 0)) return;
    switch (arg) {
      case bool() || GoBool():
        final b = arg is GoBool ? arg.$b : arg as bool;
        if (verb == 0x74 || verb == 0x76) {
          _fmt.pad(_ascii(b ? 'true' : 'false'));
        } else {
          _badVerb(verb);
        }
      case Golang.IntBase n:
        _fmtIntegerVerb(n, verb);
      case Golang.FloatBase x:
        _fmtFloatVerb(x.toDouble(), x.$bits, verb);
      case Golang.StringBase s:
        _fmtStringVerb(s.toBytes(), verb);
      case Slice<Golang.Uint8> s when _bytesVerb(verb):
        _fmtStringVerb(
          Uint8List.fromList([for (final c in s.items) c.toInt()]),
          verb,
        );
      case GoArray<Golang.Uint8> a when _bytesVerb(verb):
        _fmtStringVerb(
          Uint8List.fromList([for (final c in a.items) c.toInt()]),
          verb,
        );
      case GoValue v when v.$nilPtr:
        if (_fmt.sharpV) {
          _fmt.pad(_ascii('(*${v.$goType})(nil)'));
        } else {
          _fmt.pad(_ascii('<nil>'));
        }
      case Slice s:
        _printList(s, s.items, verb, depth, s.elem);
      case GoArray a:
        _printList(a, a.items, verb, depth, a.elem);
      case GoMap m:
        _printMap(m, verb, depth);
      case GoStruct s:
        final sharp = _fmt.sharpV;
        if (depth == 0 && !s.$isValue) _b.addByte(0x26);
        if (sharp) _b.add(utf8.encode(s.$goType));
        _b.addByte(0x7b);
        final fields = s.$fields;
        final showNames = _fmt.plusV || sharp;
        final names = showNames ? s.$fieldNames : const <String>[];
        for (var i = 0; i < fields.length; i++) {
          if (i > 0) _b.add(sharp ? _ascii(', ') : _ascii(' '));
          if (showNames) {
            _b.add(utf8.encode(names[i]));
            _b.addByte(0x3a);
          }
          _printArg(fields[i], verb, depth + 1);
        }
        _b.addByte(0x7d);
      case GoOpaqueStruct s:
        _printOpaque(s, depth);
      case Addr(target: null, :final goType):
        if (_fmt.sharpV) {
          if (goType == null) {
            throw UnimplementedError('fmt: %#v de ponteiro nulo sem nome de tipo');
          }
          _fmt.pad(_ascii('(*$goType)(nil)'));
        } else {
          _fmt.pad(_ascii('<nil>'));
        }
      case Addr(:final target) when depth == 0 && target is GoStruct:
        _b.addByte(0x26);
        _printArg(target, verb, depth + 1);
      case Addr(:final target):
        // Ponteiro aninhado (ou de topo para algo que não é GoStruct): o
        // endereço, como o Go; `%#v` acrescenta o nome do tipo entre parênteses.
        final hex = identityHashCode(target);
        if (_fmt.sharpV) {
          final name = target is Golang.GoTyped ? target.$goType : null;
          if (name == null) {
            throw UnimplementedError('fmt: %#v de ponteiro sem nome de tipo');
          }
          _fmt.pad(_ascii('(*$name)(0x${_hexAddr(hex)})'));
        } else {
          _fmt.pad(_ascii('0x${_hexAddr(hex)}'));
        }
      default:
        if (verb != 0x76) {
          throw UnimplementedError(
            'fmt: %${String.fromCharCode(verb)} de ${arg.runtimeType}',
          );
        }
        if (_fmt.sharpV) {
          if (arg is Ptr && arg is Golang.GoTyped) {
            final hex = _pointerOf(arg) ?? 0;
            final name = (arg as Golang.GoTyped).$goType;
            _fmt.pad(_ascii('($name)(${hex == 0 ? 'nil' : '0x${_hexAddr(hex)}'})'));
            return;
          }
          if (arg is! Golang.ComplexBase) {
            throw UnimplementedError('fmt: %#v de ${arg.runtimeType}');
          }
        }
        final b = BytesBuilder(copy: false);
        _appendV(b, arg, nested: depth > 0);
        _fmt.pad(b.takeBytes());
    }
  }

  static bool _bytesVerb(int verb) =>
      verb == 0x73 || verb == 0x71 || verb == 0x78 || verb == 0x58; // s q x X

  /// Struct opaca do runtime (erros): sempre ponteiro no Go (`&tipo{...}` no
  /// topo, `(*tipo)(0x...)` aninhado); `%v`/`%+v` não chegam aqui
  /// (`_handleMethods` já resolveu via `Error()`).
  void _printOpaque(GoOpaqueStruct s, int depth) {
    final name = s.$goType.startsWith('*') ? s.$goType.substring(1) : s.$goType;
    if (depth > 0) {
      _fmt.pad(_ascii('(*$name)(0x${_hexAddr(identityHashCode(s))})'));
      return;
    }
    if (s.$goType.startsWith('*')) _b.addByte(0x26);
    _b.add(utf8.encode(name));
    _b.addByte(0x7b);
    final fields = s.$fields, names = s.$fieldNames;
    for (var i = 0; i < fields.length; i++) {
      if (i > 0) _b.add(_ascii(', '));
      _b.add(utf8.encode(names[i]));
      _b.addByte(0x3a);
      _printArg(fields[i], 0x76, depth + 1);
    }
    _b.addByte(0x7d);
  }

  /// Nome Go do tipo de um slice/array/map (nomeado ou não), para `%#v`;
  /// `'?'` no nome (dicionário de genérico ou descritor de shim escrito à
  /// mão sem o metadado) nunca vira saída — lança em vez de adivinhar.
  ///
  /// `[]byte`/`[]uint8` no nível de topo (argumento direto do Printf, não
  /// aninhado): o Go usa a grafia fixa `[]byte` aí (`fmt.fmtBytes`); aninhado
  /// (campo, elemento...) é `[]uint8`, como o resto (`Slice.goType` já dá o
  /// nome normalizado — `go_type_name` também normaliza `byte`/`rune`).
  static String _containerGoType(Object v, {bool topLevel = false}) {
    if (topLevel && v is Slice<Golang.Uint8> && v is! Golang.GoTyped) {
      return '[]byte';
    }
    final name = switch (v) {
      Golang.GoTyped t => t.$goType,
      Slice s => s.goType,
      GoMap m => m.goType,
      _ => throw UnimplementedError('fmt: nome do tipo de ${v.runtimeType}'),
    };
    if (name.contains('?')) {
      throw UnimplementedError('fmt: %#v de tipo sem nome (genérico ou shim)');
    }
    return name;
  }

  /// Elemento nulo de um slice/array/map/campo de contêiner sob `%#v`: como
  /// o Go, `(*T)(nil)` para ponteiro/func, `T(nil)` para os demais (interface
  /// — o único outro caso onde um elemento é `null`).
  String _nilElemText(String goType) {
    if (goType == '?') {
      throw UnimplementedError('fmt: %#v de elemento nulo sem nome de tipo');
    }
    if (goType.startsWith('*') || goType.startsWith('func(') || goType.startsWith('func ')) {
      return '($goType)(nil)';
    }
    return '$goType(nil)';
  }

  void _printElem(Object? e, int verb, int depth, Elem elem, bool sharp) {
    if (sharp && e == null) {
      _b.add(_ascii(_nilElemText(elem.goType)));
      return;
    }
    _printArg(e, verb, depth);
  }

  void _printList(Object container, Iterable<Object?> items, int verb, int depth, Elem elem) {
    final sharp = _fmt.sharpV;
    if (sharp) {
      _b.add(utf8.encode(_containerGoType(container, topLevel: depth == 0)));
      if (container is Slice && container.isNil) {
        _b.add(_ascii('(nil)'));
        return;
      }
      _b.addByte(0x7b);
    } else {
      _b.addByte(0x5b);
    }
    var first = true;
    for (final e in items) {
      if (!first) _b.add(sharp ? _ascii(', ') : _ascii(' '));
      first = false;
      _printElem(e, verb, depth + 1, elem, sharp);
    }
    _b.addByte(sharp ? 0x7d : 0x5d);
  }

  void _printMap(GoMap m, int verb, int depth) {
    final sharp = _fmt.sharpV;
    if (sharp) {
      _b.add(utf8.encode(_containerGoType(m)));
      if (m.isNil) {
        _b.add(_ascii('(nil)'));
        return;
      }
    }
    final all = m.entries.toList();
    final order = List.generate(all.length, (i) => i)
      ..sort((x, y) {
        final c = m.identity ? 0 : _compareKeys(all[x].key, all[y].key);
        return c != 0 ? c : x - y;
      });
    if (sharp) {
      _b.addByte(0x7b);
    } else {
      _b.add(_ascii('map['));
    }
    for (var i = 0; i < order.length; i++) {
      if (i > 0) _b.add(sharp ? _ascii(', ') : _ascii(' '));
      _printElem(all[order[i]].key, verb, depth + 1, m.keyElem, sharp);
      _b.addByte(0x3a);
      _printElem(all[order[i]].value, verb, depth + 1, m.elem, sharp);
    }
    _b.addByte(sharp ? 0x7d : 0x5d);
  }

  /// `Error()`/`String()` nos verbos de string (o `handleMethods` do Go).
  bool _handleMethods(int verb, bool nested) {
    if (_erroring) return false;
    final arg = _arg;
    if (verb == 0x77) {
      if (arg is! GoError || !wrapErrs) {
        _badVerb(verb);
        return true;
      }
      verb = 0x76;
    }
    if (arg is Formatter && _hasMethod(arg, 'Format', nested)) {
      try {
        arg.format(this, Golang.Rune(verb));
      } on Panic catch (p) {
        final Object o = arg;
        if (o is GoValue && o.$nilPtr) {
          _fmt.pad(_ascii('<nil>'));
          return true;
        }
        _b.add(_ascii('%!'));
        _writeRune(verb);
        _b.add(utf8.encode('(PANIC=Format method: ${describePanic(p.value)})'));
      }
      return true;
    }
    if (_fmt.sharpV) {
      // `%#v`: só `GoStringer` (o Go não tenta `error`/`Stringer` aqui —
      // sem `GoString`, cai na representação estrutural/de sintaxe Go).
      if (arg is GoStringer && _hasMethod(arg, 'GoString', nested)) {
        try {
          _fmt.pad(_fmt.truncate(arg.goString().toBytes()));
        } on Panic catch (p) {
          final Object o = arg;
          if (o is GoValue && o.$nilPtr) {
            _fmt.pad(_ascii('<nil>'));
            return true;
          }
          _b.add(_ascii('%!'));
          _writeRune(verb);
          _b.add(utf8.encode('(PANIC=GoString method: ${describePanic(p.value)})'));
        }
        return true;
      }
      return false;
    }
    if (verb != 0x76 &&
        verb != 0x73 &&
        verb != 0x78 &&
        verb != 0x58 &&
        verb != 0x71) {
      return false;
    }
    final String kind;
    final Golang.String Function() call;
    if (arg is GoError && _hasMethod(arg, 'Error', nested)) {
      kind = 'Error';
      call = arg.error;
    } else if (arg is Stringer && _hasMethod(arg, 'String', nested)) {
      kind = 'String';
      call = arg.string;
    } else {
      return false;
    }
    final Uint8List text;
    try {
      text = call().toBytes();
    } on Panic catch (p) {
      if (arg is GoValue && arg.$nilPtr) {
        _fmt.pad(_ascii('<nil>'));
        return true;
      }
      _b.add(_ascii('%!'));
      _writeRune(verb);
      _b.add(utf8.encode('(PANIC=$kind method: ${describePanic(p.value)})'));
      return true;
    }
    _fmtStringVerb(text, verb);
    return true;
  }

  void _badVerb(int verb) {
    _erroring = true;
    final arg = _arg;
    _b.add(_ascii('%!'));
    _writeRune(verb);
    _b.addByte(0x28);
    if (arg != null) {
      _b.add(utf8.encode(_typeName(arg)));
      _b.addByte(0x3d);
      _printArg(arg, 0x76, 0);
    } else {
      _b.add(_ascii('<nil>'));
    }
    _b.addByte(0x29);
    _erroring = false;
  }

  static String _typeName(Object a) => switch (a) {
    bool() => 'bool',
    GoValue v when !v.$isValue => '*${v.$goType}',
    Golang.GoTyped t => t.$goType,
    Addr(target: final Golang.GoTyped t?) => '*${t.$goType}',
    _ => throw UnimplementedError('fmt: nome do tipo de ${a.runtimeType}'),
  };

  // ------------------------------------------ verbos por tipo (o _Fmt formata)
  void _fmtIntegerVerb(Golang.IntBase n, int verb) {
    final v = n.toBigInt();
    switch (verb) {
      case 0x76 || 0x64: // v d
        if (_fmt.sharpV && !n.$signed) {
          // `%#v` de inteiro sem sinal: hex com `0x` (fmt0x64 do Go), como %p.
          final oldSharp = _fmt.sharp;
          _fmt.sharp = true;
          _fmt.fmtInteger(v, 16, verb, _hexLower);
          _fmt.sharp = oldSharp;
        } else {
          _fmt.fmtInteger(v, 10, verb, _hexLower);
        }
      case 0x62: // b
        _fmt.fmtInteger(v, 2, verb, _hexLower);
      case 0x6f || 0x4f: // o O
        _fmt.fmtInteger(v, 8, verb, _hexLower);
      case 0x78: // x
        _fmt.fmtInteger(v, 16, verb, _hexLower);
      case 0x58: // X
        _fmt.fmtInteger(v, 16, verb, _hexUpper);
      case 0x63: // c
        _fmt.pad(utf8.encode(String.fromCharCode(_runeOf(v))));
      case 0x71: // q
        // `#` não faz diferença no `%q`/`%#v` de runa no Go (só em string).
        final r = utf8.encode(String.fromCharCode(_runeOf(v)));
        _fmt.pad(_quote(r, 0x27, _fmt.plus));
      case 0x55: // U
        _fmt.fmtUnicode(v);
      default:
        _badVerb(verb);
    }
  }

  static int _runeOf(BigInt v) => v.isNegative || v > BigInt.from(0x10ffff)
      ? 0xfffd
      : _validRune(v.toInt());

  void _fmtFloatVerb(double v, int bits, int verb) {
    switch (verb) {
      case 0x76: // v
        // `%#v` de float é igual a `%v` no Go (sem prefixo, sem dígitos extras).
        _fmt.fmtFloat(v, bits, 'g', -1);
      case 0x67 || 0x47: // g G
        _fmt.fmtFloat(v, bits, String.fromCharCode(verb), -1);
      case 0x65 || 0x45 || 0x66: // e E f
        _fmt.fmtFloat(v, bits, String.fromCharCode(verb), 6);
      case 0x46: // F
        _fmt.fmtFloat(v, bits, 'f', 6);
      case 0x62 || 0x78 || 0x58: // b x X
        throw UnimplementedError('fmt: %${String.fromCharCode(verb)} de float');
      default:
        _badVerb(verb);
    }
  }

  void _fmtStringVerb(Uint8List s, int verb) {
    switch (verb) {
      case 0x76: // v
        if (_fmt.sharpV) {
          // `%#v` de string é `%q` sem a forma com aspas simples (`sharp` já
          // virou `sharpV`, então nunca entra em backquote aqui).
          _fmt.pad(_quote(_fmt.truncate(s), 0x22, _fmt.plus));
        } else {
          _fmt.pad(_fmt.truncate(s));
        }
      case 0x73: // s
        _fmt.pad(_fmt.truncate(s));
      case 0x78: // x
        _fmt.fmtSbx(s, _hexLower);
      case 0x58: // X
        _fmt.fmtSbx(s, _hexUpper);
      case 0x71: // q
        final t = _fmt.truncate(s);
        if (_fmt.sharp && _canBackquote(t)) {
          _fmt.pad([0x60, ...t, 0x60]);
        } else {
          _fmt.pad(_quote(t, 0x22, _fmt.plus));
        }
      default:
        _badVerb(verb);
    }
  }
}
