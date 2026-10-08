part of '../../fmt.dart';

/// Um `pp` do Go (`fmt/print.go`): o laço do formato, os operandos e os
/// métodos que o fmt chama (Formatter, error, Stringer). Flags, largura,
/// precisão e padding ficam no [_Fmt] dele, sobre o mesmo buffer. O que não
/// está portado lança [UnimplementedError] (nunca formata diferente do Go em
/// silêncio).
final class _Printer with io.WriterSync implements State {
  _Printer(this.args, {this.wrapErrs = false});

  final List<Object?> args;
  final bool wrapErrs;
  final wrapped = <int>[];
  final _b = BytesBuilder(copy: false);
  late final _fmt = _Fmt(_b);

  bool _erroring = false;
  bool _panicking = false;
  bool goodArgNum = true;
  bool reordered = false;
  Object? _arg;

  /// Dentro de um campo não exportado: o Go não chama métodos ali
  /// (`CanInterface` falso no `printValue`), em nenhuma profundidade.
  bool _ro = false;

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
      final (verb, size) = decodeRune(f, i);
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
      _b.add(utf8.encode(String.fromCharCode(validRune(r))));

  // -------------------------------------------------------------- operandos
  /// `printArg`/`printValue` do Go. [value] diz o que um [GoValue]
  /// aninhado é no lugar de onde vem (o objeto Dart é o mesmo para T e *T):
  /// `true` struct/array por valor, `false` ponteiro, `null` decidido pelo
  /// `$isValue` (valor dentro de interface). Um campo `*T` vem como [Addr].
  void _printArg(
    Object? arg,
    int verb,
    int depth, {
    String? name,
    String? under,
    bool? value,
  }) {
    arg = unShim(arg); // valor de shim numa interface gerada (D8)
    if (arg is TypeTag) {
      name = arg.name;
      under = arg.under;
      arg = arg.value;
    }
    if (name != null && name.isEmpty) name = null; // $fieldTypes: desconhecido
    if (arg is FmtReflectValue && verb != 0x54 && verb != 0x70) {
      if (!arg.$valid) {
        _fmt.pad(
          _ascii(depth == 0 ? '<invalid reflect.Value>' : '<invalid Value>'),
        );
        return;
      }
      arg = arg.$fmtArg;
    }
    if (arg is Addr && arg.target != null) {
      arg = arg.target;
      value = false;
    }
    // Ponteiro para struct/array: o method set de *T e, aninhado, o endereço.
    final ptr = arg is GoValue && (arg.$nilPtr || !(value ?? arg.$isValue));
    _arg = arg;
    if (arg == null) {
      if (_fmt.sharpV && verb == 0x76 && (depth > 0 || name != null)) {
        _sharpNil(name);
      } else if (verb == 0x54 || verb == 0x76) {
        _fmt.pad(_ascii('<nil>'));
      } else {
        _badVerb(verb);
      }
      return;
    }
    if (verb == 0x54) {
      _fmt.pad(utf8.encode(depth == 0 && name != null ? name : _typeName(arg)));
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
    if ((depth == 0 || !_ro) && _handleMethods(verb, ptr)) return;
    if (_fmt.sharpV && _printSharp(arg, depth, name, under, ptr)) return;
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
        _fmt.pad(_ascii('<nil>'));
      case Slice s:
        _printList(s.items, verb, depth, s.elem);
      case GoValue v when ptr && depth > 0:
        _fmtPointer(v, verb); // ponteiro aninhado: o endereço, como o Go
      case GoArray a:
        if (ptr) _b.addByte(0x26);
        _printList(a.items, verb, depth, a.elem);
      case GoMap m:
        _printMap(m, verb, depth);
      case GoStruct s:
        if (ptr) _b.addByte(0x26);
        _b.addByte(0x7b);
        final fields = s.$fields;
        final names = s.$fieldNames;
        final ro = _ro;
        for (var i = 0; i < fields.length; i++) {
          if (i > 0) _b.addByte(0x20);
          if (_fmt.plusV) {
            _b.add(utf8.encode(names[i]));
            _b.addByte(0x3a);
          }
          _ro = ro || !_exported(names[i]);
          _printArg(fields[i], verb, depth + 1, value: true);
        }
        _ro = ro;
        _b.addByte(0x7d);
      case Addr(target: null):
        _fmt.pad(_ascii('<nil>'));
      default:
        if (verb != 0x76) {
          throw UnimplementedError(
            'fmt: %${String.fromCharCode(verb)} de ${arg.runtimeType}',
          );
        }
        _fmt.pad(_leafV(arg));
    }
  }

  /// `fmtPointer` do Go com verbo `v`: `0x` + endereço (⚠️ estável por
  /// objeto, não o do Go). Os outros verbos não estão portados.
  void _fmtPointer(Object target, int verb) {
    if (verb != 0x76) {
      throw UnimplementedError(
        'fmt: %${String.fromCharCode(verb)} de ponteiro aninhado',
      );
    }
    _fmt.pad(_ascii('0x${_hexAddr(identityHashCode(target))}'));
  }

  /// Campo exportado (`token.IsExported`): o fmt só chama métodos nele.
  static bool _exported(String name) {
    final r = name.runes.first;
    if (r < 0x80) return r >= 0x41 && r <= 0x5a;
    return unicode.isUpper(Golang.Rune(r));
  }

  static bool _bytesVerb(int verb) =>
      verb == 0x73 || verb == 0x71 || verb == 0x78 || verb == 0x58; // s q x X

  /// Elementos de slice/array: struct/array por valor pelo descritor
  /// (`Elem.value`); senão ponteiro, ou o `$isValue` de um valor em interface.
  void _printList(Iterable<Object?> items, int verb, int depth, Elem elem) {
    _b.addByte(0x5b);
    var first = true;
    for (final e in items) {
      if (!first) _b.addByte(0x20);
      first = false;
      _printArg(e, verb, depth + 1, value: elem.value ? true : null);
    }
    _b.addByte(0x5d);
  }

  /// Chave `*T` só em map `identity`. ⚠️ Chave de interface com `*T`
  /// (`map[any]V`) é tratada como valor.
  void _printMap(GoMap m, int verb, int depth) {
    final entries = _sortedEntries(m);
    _b.add(_ascii('map['));
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) _b.addByte(0x20);
      _printArg(entries[i].key, verb, depth + 1, value: !m.identity);
      _b.addByte(0x3a);
      _printArg(
        entries[i].value,
        verb,
        depth + 1,
        value: m.elem.value ? true : null,
      );
    }
    _b.addByte(0x5d);
  }

  /// `Error()`/`String()` nos verbos de string (o `handleMethods` do Go);
  /// [ptr]: o operando é `*T` (method set de *T), não T.
  bool _handleMethods(int verb, bool ptr) {
    if (_erroring) return false;
    final arg = _arg;
    if (verb == 0x77) {
      if (arg is! GoError || !wrapErrs) {
        _badVerb(verb);
        return true;
      }
      verb = 0x76;
    }
    if (arg is Formatter && _hasMethod(arg, 'Format', ptr)) {
      try {
        arg.format(this, Golang.Rune(verb));
      } catch (e) {
        _catchPanic(e, arg, verb, 'Format');
      }
      return true;
    }
    if (_fmt.sharpV) {
      // %#v: GoString() em vez de Error()/String() (handleMethods do Go).
      if (arg is GoStringer && _hasMethod(arg, 'GoString', ptr)) {
        final Uint8List text;
        try {
          text = arg.goString().toBytes();
        } catch (e) {
          _catchPanic(e, arg, verb, 'GoString');
          return true;
        }
        _fmt.pad(_fmt.truncate(text));
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
    if (arg is GoError && _hasMethod(arg, 'Error', ptr)) {
      kind = 'Error';
      call = arg.error;
    } else if (arg is Stringer && _hasMethod(arg, 'String', ptr)) {
      kind = 'String';
      call = arg.string;
    } else {
      return false;
    }
    final Uint8List text;
    try {
      text = call().toBytes();
    } catch (e) {
      _catchPanic(e, arg, verb, kind);
      return true;
    }
    _fmtStringVerb(text, verb);
    return true;
  }

  /// `catchPanic` do Go: panic (ou falha do runtime Dart que o Go teria
  /// como panic, ex. nil deref) dentro de um método chamado pelo fmt. Com
  /// receptor ponteiro nil sai `<nil>`; senão `%!v(PANIC=String method: ...)`
  /// com o valor do panic em `%v`. Exceção que não é panic do Go (ex.
  /// [UnimplementedError]) segue.
  void _catchPanic(Object e, Object? arg, int verb, String method) {
    final v = panicValue(e);
    if (identical(v, e) && e is! Panic) throw e;
    if (_isNilPtr(arg)) {
      _fmt.pad(_ascii('<nil>'));
      return;
    }
    if (_panicking) throw e;
    final saved = _Fmt(_b)..copyFlags(_fmt);
    _fmt.clearFlags();
    _b.add(_ascii('%!'));
    _writeRune(verb);
    _b.add(utf8.encode('(PANIC=$method method: '));
    _panicking = true;
    _printArg(v, 0x76, 0);
    _panicking = false;
    _b.addByte(0x29);
    _fmt.copyFlags(saved);
  }

  /// Ponteiro nil tipado (`(*T)(nil)` numa interface).
  static bool _isNilPtr(Object? v) =>
      (v is GoValue && v.$nilPtr) ||
      v is NilPtr ||
      (v is PtrView && v.$p is NilPtr);

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
    ShimIface s => _typeName(s.$v),
    bool() => 'bool',
    Func f => f.sig,
    TypeTag t => t.name,
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
          // fmt0x64(v, true): sem sinal em %#v sai 0x...
          final sharp = _fmt.sharp;
          _fmt.sharp = true;
          _fmt.fmtInteger(v, 16, verb, _hexLower);
          _fmt.sharp = sharp;
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
        // fmtQc do Go ignora o `#` (backquote só em string).
        final r = utf8.encode(String.fromCharCode(_runeOf(v)));
        _fmt.pad(quoteBytes(r, 0x27, _fmt.plus));
      case 0x55: // U
        _fmt.fmtUnicode(v);
      default:
        _badVerb(verb);
    }
  }

  static int _runeOf(BigInt v) =>
      v.isNegative || v > BigInt.from(0x10ffff) ? 0xfffd : validRune(v.toInt());

  void _fmtFloatVerb(double v, int bits, int verb) {
    switch (verb) {
      case 0x76: // v
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
          _fmt.pad(quoteBytes(_fmt.truncate(s), 0x22, _fmt.plus)); // fmtQ
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
        if (_fmt.sharp && canBackquote(t)) {
          _fmt.pad([0x60, ...t, 0x60]);
        } else {
          _fmt.pad(quoteBytes(t, 0x22, _fmt.plus));
        }
      default:
        _badVerb(verb);
    }
  }
}
