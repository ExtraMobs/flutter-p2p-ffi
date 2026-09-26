/// Shim do pacote Go `fmt`.
// ignore_for_file: library_prefixes
library;

import 'dart:convert';
import 'dart:typed_data';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'fixed_types/golang/src/float_format.dart' show formatGoFloatFmt;
import 'src/runtime/output.dart';
import 'src/unicode/isprint.dart';

/// `fmt.Stringer`.
abstract interface class Stringer {
  Golang.String string();
}

/// `fmt.Println`: operandos em `%v` separados por espaço, mais newline.
/// Escreve os bytes exatos (strings Go podem não ser UTF-8 válido).
(Golang.Int, GoError?) println(Slice<Object?> args) {
  final bytes = _sprintln(args);
  writeStdout(bytes);
  return (Golang.Int(bytes.length), null);
}

/// `fmt.Sprintln`: como [println], devolvido como string.
Golang.String sprintln(Slice<Object?> args) =>
    Golang.String.fromBytes(_sprintln(args));

Uint8List _sprintln(Slice<Object?> args) {
  final a = args.items.toList();
  final b = BytesBuilder(copy: false);
  for (var i = 0; i < a.length; i++) {
    if (i > 0) b.addByte(0x20);
    _appendV(b, a[i]);
  }
  b.addByte(0x0a);
  return b.takeBytes();
}

/// `fmt.Print`: como [sprint], escrito na saída padrão.
(Golang.Int, GoError?) print(Slice<Object?> args) {
  final bytes = _sprint(args);
  writeStdout(bytes);
  return (Golang.Int(bytes.length), null);
}

/// `fmt.Sprint`: espaço entre operandos quando nenhum dos dois é string.
Golang.String sprint(Slice<Object?> args) =>
    Golang.String.fromBytes(_sprint(args));

Uint8List _sprint(Slice<Object?> args) {
  final a = args.items.toList();
  final b = BytesBuilder(copy: false);
  for (var i = 0; i < a.length; i++) {
    if (i > 0 && a[i] is! Golang.String && a[i - 1] is! Golang.String) {
      b.addByte(0x20);
    }
    _appendV(b, a[i]);
  }
  return b.takeBytes();
}

/// Endereço de um valor com endereço no Go (ponteiro, slice, map, func), 0
/// para nil, ou null se v não tem endereço. ⚠️ Estável por objeto, não o
/// endereço do Go (que nem o Go reproduz entre execuções).
int? _pointerOf(Object? v) => switch (v) {
  NilPtr() => 0,
  PtrView(:final $p) when $p is NilPtr => 0,
  Ptr p => p.hashCode, // Box: identidade; ElemPtr/FieldPtr: dono + posição
  Addr(target: null) => 0,
  Addr(:final target) => identityHashCode(target),
  GoValue s when s.$nilPtr => 0,
  GoValue s when !s.$isValue => identityHashCode(s), // *T de struct/array
  Slice s => sliceAddr(s),
  GoMap m => m.isNil ? 0 : identityHashCode(m),
  Function f => identityHashCode(f),
  _ => null,
};

/// Hex do endereço na forma do Go (`c0` + 8 dígitos, como 0xc00000a0a8).
String _hexAddr(int a) =>
    a == 0 ? '0' : 'c0${(a & 0x7fffffff).toRadixString(16).padLeft(8, '0')}';

/// Formatação `%v` do Go. Os wrappers de `fixed_types` já formatam como o Go
/// no `toString` (floats: `strconv.FormatFloat(x, 'g', -1, bits)`).
void _appendV(BytesBuilder b, Object? v, {bool nested = false}) {
  switch (v) {
    case null:
      b.add(utf8.encode('<nil>'));
    // Ponteiro nil tipado: o fmt chama String()/Error() (o método pode
    // tratar nil); se ele entrar em panic, imprime <nil> (handleMethods).
    case GoValue s when s.$nilPtr:
      try {
        final Object o = s;
        if (o is GoError) {
          b.add(o.error().toBytes());
        } else if (o is Stringer) {
          b.add(o.string().toBytes());
        } else {
          b.add(utf8.encode('<nil>'));
        }
      } catch (_) {
        b.add(utf8.encode('<nil>'));
      }
    case NilPtr():
      b.add(utf8.encode('<nil>'));
    // Como o fmt do Go: error, depois Stringer, antes da forma estrutural.
    case GoError e:
      b.add(e.error().toBytes());
    case Stringer s:
      b.add(s.string().toBytes());
    case GoStruct s:
      // Ponteiro para struct no nível de topo: &{...}; aninhado ou por valor: {...}.
      if (!nested && !s.$isValue) b.addByte(0x26);
      b.addByte(0x7b);
      final fields = s.$fields;
      for (var i = 0; i < fields.length; i++) {
        if (i > 0) b.addByte(0x20);
        _appendV(b, fields[i], nested: true);
      }
      b.addByte(0x7d);
    case GoArray a:
      _appendList(b, a.items);
    case Slice s:
      _appendList(b, s.items);
    case GoMap m:
      // Go ordena as chaves ao imprimir (internal/fmtsort).
      // Ordenação estável: empates (ponteiros) ficam na ordem de inserção.
      final all = m.entries.toList();
      final entries = [
        for (final i
            in List.generate(all.length, (i) => i)..sort((x, y) {
              final c = m.identity ? 0 : _compareKeys(all[x].key, all[y].key);
              return c != 0 ? c : x - y;
            }))
          all[i],
      ];
      b.add(utf8.encode('map['));
      for (var i = 0; i < entries.length; i++) {
        if (i > 0) b.addByte(0x20);
        _appendV(b, entries[i].key, nested: true);
        b.addByte(0x3a); // :
        _appendV(b, entries[i].value, nested: true);
      }
      b.addByte(0x5d);
    case Addr(target: null):
      b.add(utf8.encode('<nil>'));
    case Addr(:final target) when !nested && target is GoStruct:
      b.addByte(0x26); // &{...} no nível de topo
      _appendV(b, target);
    case Addr(:final target):
      // Ponteiro aninhado: o Go imprime o endereço.
      b.add(utf8.encode('0x${_hexAddr(identityHashCode(target))}'));
    // *T (T não-struct) e func: o endereço, como o Go.
    case Ptr() || Function():
      final a = _pointerOf(v)!;
      b.add(utf8.encode(a == 0 ? '<nil>' : '0x${_hexAddr(a)}'));
    case Golang.StringBase s:
      b.add(s.toBytes());
    default:
      b.add(utf8.encode(v.toString()));
  }
}

/// `%v` de um único valor, como bytes.
Uint8List formatV(Object? v) {
  final b = BytesBuilder(copy: false);
  _appendV(b, v);
  return b.takeBytes();
}

/// Ordem do internal/fmtsort.compare: nil primeiro; números por valor (NaN
/// antes); strings por bytes; false antes de true; complex pela parte real e
/// depois a imaginária; structs e arrays campo a campo.
///
/// Dois casos o Go ordena por endereço de memória, que não é reproduzível:
/// ponteiros (aqui empatam e ficam na ordem de inserção, que costuma ser a
/// de alocação) e o tipo dinâmico de chaves interface de tipos diferentes.
int _compareKeys(Object? a, Object? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  final ta = _keyType(a), tb = _keyType(b);
  // Limite (⚠️ em docs/mapping-spec.md): o Go compara os endereços dos
  // descritores de tipo, que seguem o layout do linker (nomeados de main,
  // depois string, int8, int64, int, uint, ... no gc 1.25) e mudam com os
  // pacotes linkados; o nome do tipo só dá uma ordem determinística.
  if (ta != tb) return ta.compareTo(tb);
  switch ((a, b)) {
    case (GoValue($nilPtr: true), _) || (_, GoValue($nilPtr: true)):
      return 0;
    case (final bool x, final bool y):
      return x == y ? 0 : (x ? 1 : -1);
    case (final Golang.Complex128 x, final Golang.Complex128 y):
      final c = x.real.compareTo(y.real);
      return c != 0 ? c : x.imag.compareTo(y.imag);
    case (final Golang.Complex64 x, final Golang.Complex64 y):
      final c = x.real.compareTo(y.real);
      return c != 0 ? c : x.imag.compareTo(y.imag);
    case (final GoStruct x, final GoStruct y):
      return _compareAll(x.$fields, y.$fields);
    case (final GoArray x, final GoArray y):
      return _compareAll(x.items, y.items);
    case (final Comparable x, final Comparable y):
      return x.compareTo(y);
  }
  return 0; // ponteiros (Addr, Ptr): ordem de inserção
}

int _compareAll(Iterable<Object?> a, Iterable<Object?> b) {
  final ib = b.iterator;
  for (final x in a) {
    ib.moveNext();
    final c = _compareKeys(x, ib.current);
    if (c != 0) return c;
  }
  return 0;
}

String _keyType(Object k) => switch (k) {
  Golang.GoTyped t => t.$goType,
  bool() => 'bool',
  Golang.Complex128() => 'complex128',
  Golang.Complex64() => 'complex64',
  _ => '',
};

void _appendList(BytesBuilder b, Iterable<Object?> items) {
  b.addByte(0x5b); // [
  var first = true;
  for (final e in items) {
    if (!first) b.addByte(0x20);
    first = false;
    _appendV(b, e, nested: true);
  }
  b.addByte(0x5d); // ]
}

// ------------------------------------------------------------------ Printf

/// `fmt.Sprintf`.
Golang.String sprintf(Golang.String format, Slice<Object?> a) =>
    Golang.String.fromBytes(_Printf(a.items.toList()).run(format.toBytes()));

/// `fmt.Printf`: como [sprintf], escrito na saída padrão.
(Golang.Int, GoError?) printf(Golang.String format, Slice<Object?> a) {
  final bytes = _Printf(a.items.toList()).run(format.toBytes());
  writeStdout(bytes);
  return (Golang.Int(bytes.length), null);
}

/// `fmt.Errorf`: sem `%w`, `*errors.errorString`; com um, `*fmt.wrapError`
/// (Unwrap devolve o operando); com vários, `*fmt.wrapErrors`.
GoError? errorf(Golang.String format, Slice<Object?> a) {
  final args = a.items.toList();
  final p = _Printf(args, wrapErrs: true);
  final s = Golang.String.fromBytes(p.run(format.toBytes()));
  if (p.reordered) p.wrapped.sort();
  if (p.wrapped.isEmpty) return ErrorString(s);
  if (p.wrapped.length == 1) {
    final e = args[p.wrapped[0]];
    return WrapError(s, e is GoError ? e : null);
  }
  return WrapErrors(s, [
    for (var k = 0; k < p.wrapped.length; k++)
      if (k == 0 || p.wrapped[k - 1] != p.wrapped[k])
        if (args[p.wrapped[k]] case final GoError e) e,
  ]);
}

const _hexLower = '0123456789abcdef';
const _hexUpper = '0123456789ABCDEF';

List<int> _ascii(String s) => s.codeUnits;

/// Um `pp` do Go: flags do verbo corrente e o buffer de saída. Porte de
/// `fmt/print.go` e `fmt/format.go`; o que não está portado lança
/// [UnimplementedError] (nunca formata diferente do Go em silêncio).
final class _Printf {
  _Printf(this.args, {this.wrapErrs = false});

  final List<Object?> args;
  final bool wrapErrs;
  final wrapped = <int>[];
  final _b = BytesBuilder(copy: false);

  bool minus = false, plus = false, sharp = false, space = false, zero = false;
  bool plusV = false, sharpV = false;
  int wid = 0, prec = 0;
  bool widPresent = false, precPresent = false;
  bool _erroring = false;
  bool goodArgNum = true;
  bool reordered = false;
  Object? _arg;

  void _clearFlags() {
    minus = plus = sharp = space = zero = false;
    plusV = sharpV = false;
    wid = prec = 0;
    widPresent = precPresent = false;
  }

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
      _clearFlags();
      flags:
      for (; i < end; i++) {
        switch (f[i]) {
          case 0x23: // '#'
            sharp = true;
          case 0x30: // '0'
            zero = !minus;
          case 0x2b: // '+'
            plus = true;
          case 0x2d: // '-'
            minus = true;
            zero = false;
          case 0x20: // ' '
            space = true;
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
        wid = w;
        widPresent = ok;
        argNum = n;
        if (!widPresent) _b.add(_ascii('%!(BADWIDTH)'));
        if (wid < 0) {
          wid = -wid;
          minus = true;
          zero = false;
        }
        afterIndex = false;
      } else {
        final (w, ok, n) = _parseNum(f, i, end);
        wid = w;
        widPresent = ok;
        i = n;
        if (afterIndex && widPresent) goodArgNum = false; // "%[3]2d"
      }
      if (i + 1 < end && f[i] == 0x2e) {
        i++;
        if (afterIndex) goodArgNum = false; // "%[3].2d"
        (argNum, i, afterIndex) = _argNumber(argNum, f, i);
        if (i < end && f[i] == 0x2a) {
          i++;
          final (w, ok, n) = _intFromArg(argNum);
          prec = w;
          precPresent = ok;
          argNum = n;
          if (prec < 0) {
            prec = 0;
            precPresent = false;
          }
          if (!precPresent) _b.add(_ascii('%!(BADPREC)'));
          afterIndex = false;
        } else {
          final (w, ok, n) = _parseNum(f, i, end);
          prec = w;
          precPresent = ok;
          i = n;
          if (!precPresent) {
            prec = 0;
            precPresent = true;
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
        sharpV = sharp;
        sharp = false;
        plusV = plus;
        plus = false;
      }
      _printArg(args[argNum], verb, 0);
      argNum++;
    }
    // Com índice explícito o Go não confere operandos sobrando.
    if (!reordered && argNum < args.length) {
      _clearFlags();
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
        _pad(_ascii('<nil>'));
      } else {
        _badVerb(verb);
      }
      return;
    }
    if (verb == 0x54) {
      _pad(utf8.encode(_typeName(arg))); // %T
      return;
    }
    if (verb == 0x70) {
      // %p (antes dos métodos, como o Go): 0x + hex; %#p sem o 0x.
      final a = _pointerOf(arg);
      if (a == null) {
        _badVerb(verb);
      } else {
        _pad(_ascii(sharp ? _hexAddr(a) : '0x${_hexAddr(a)}'));
      }
      return;
    }
    if (_handleMethods(verb)) return;
    switch (arg) {
      case bool() || GoBool():
        final b = arg is GoBool ? arg.$b : arg as bool;
        if (verb == 0x74 || verb == 0x76) {
          _pad(_ascii(b ? 'true' : 'false'));
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
        _pad(_ascii('<nil>'));
      case Slice s:
        _printList(s.items, verb, depth);
      case GoArray a:
        _printList(a.items, verb, depth);
      case GoMap m:
        _printMap(m, verb, depth);
      case GoStruct s:
        if (sharpV) throw UnimplementedError('fmt: %#v de struct');
        if (depth == 0 && !s.$isValue) _b.addByte(0x26);
        _b.addByte(0x7b);
        final fields = s.$fields;
        final names = plusV ? s.$fieldNames : const <String>[];
        for (var i = 0; i < fields.length; i++) {
          if (i > 0) _b.addByte(0x20);
          if (plusV) {
            _b.add(utf8.encode(names[i]));
            _b.addByte(0x3a);
          }
          _printArg(fields[i], verb, depth + 1);
        }
        _b.addByte(0x7d);
      case Addr(target: null):
        _pad(_ascii('<nil>'));
      case Addr(:final target) when depth == 0 && target is GoStruct:
        _b.addByte(0x26);
        _printArg(target, verb, depth + 1);
      default:
        if (verb != 0x76) {
          throw UnimplementedError(
            'fmt: %${String.fromCharCode(verb)} de ${arg.runtimeType}',
          );
        }
        final b = BytesBuilder(copy: false);
        _appendV(b, arg, nested: depth > 0);
        _pad(b.takeBytes());
    }
  }

  static bool _bytesVerb(int verb) =>
      verb == 0x73 || verb == 0x71 || verb == 0x78 || verb == 0x58; // s q x X

  void _printList(Iterable<Object?> items, int verb, int depth) {
    if (sharpV) throw UnimplementedError('fmt: %#v de slice/array');
    _b.addByte(0x5b);
    var first = true;
    for (final e in items) {
      if (!first) _b.addByte(0x20);
      first = false;
      _printArg(e, verb, depth + 1);
    }
    _b.addByte(0x5d);
  }

  void _printMap(GoMap m, int verb, int depth) {
    if (sharpV) throw UnimplementedError('fmt: %#v de map');
    final all = m.entries.toList();
    final order = List.generate(all.length, (i) => i)
      ..sort((x, y) {
        final c = m.identity ? 0 : _compareKeys(all[x].key, all[y].key);
        return c != 0 ? c : x - y;
      });
    _b.add(_ascii('map['));
    for (var i = 0; i < order.length; i++) {
      if (i > 0) _b.addByte(0x20);
      _printArg(all[order[i]].key, verb, depth + 1);
      _b.addByte(0x3a);
      _printArg(all[order[i]].value, verb, depth + 1);
    }
    _b.addByte(0x5d);
  }

  /// `Error()`/`String()` nos verbos de string (o `handleMethods` do Go).
  bool _handleMethods(int verb) {
    if (_erroring) return false;
    final arg = _arg;
    if (verb == 0x77) {
      if (arg is! GoError || !wrapErrs) {
        _badVerb(verb);
        return true;
      }
      verb = 0x76;
    }
    if (sharpV) throw UnimplementedError('fmt: %#v (GoStringer)');
    if (verb != 0x76 &&
        verb != 0x73 &&
        verb != 0x78 &&
        verb != 0x58 &&
        verb != 0x71) {
      return false;
    }
    final String kind;
    final Golang.String Function() call;
    if (arg is GoError) {
      kind = 'Error';
      call = arg.error;
    } else if (arg is Stringer) {
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
        _pad(_ascii('<nil>'));
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

  // -------------------------------------------------------------- padding
  void _writePadding(int n) {
    if (n <= 0) return;
    _b.add(List.filled(n, zero && !minus ? 0x30 : 0x20));
  }

  /// Largura em runas, à esquerda (ou à direita com `-`).
  void _pad(List<int> s) {
    if (!widPresent || wid == 0) {
      _b.add(s);
      return;
    }
    final width = wid - _runeCount(s);
    if (!minus) {
      _writePadding(width);
      _b.add(s);
    } else {
      _b.add(s);
      _writePadding(width);
    }
  }

  // -------------------------------------------------------------- inteiros
  void _fmtIntegerVerb(Golang.IntBase n, int verb) {
    final v = n.toBigInt();
    switch (verb) {
      case 0x76 || 0x64: // v d
        if (sharpV) throw UnimplementedError('fmt: %#v de inteiro');
        _fmtInteger(v, 10, verb, _hexLower);
      case 0x62: // b
        _fmtInteger(v, 2, verb, _hexLower);
      case 0x6f || 0x4f: // o O
        _fmtInteger(v, 8, verb, _hexLower);
      case 0x78: // x
        _fmtInteger(v, 16, verb, _hexLower);
      case 0x58: // X
        _fmtInteger(v, 16, verb, _hexUpper);
      case 0x63: // c
        _pad(utf8.encode(String.fromCharCode(_runeOf(v))));
      case 0x71: // q
        if (sharp) throw UnimplementedError('fmt: %#q de runa');
        final r = utf8.encode(String.fromCharCode(_runeOf(v)));
        _pad(_quote(r, 0x27, plus));
      case 0x55: // U
        _fmtUnicode(v);
      default:
        _badVerb(verb);
    }
  }

  static int _runeOf(BigInt v) => v.isNegative || v > BigInt.from(0x10ffff)
      ? 0xfffd
      : _validRune(v.toInt());

  void _fmtInteger(BigInt v, int base, int verb, String digitSet) {
    final negative = v.isNegative;
    final u = v.abs();
    var p = 0;
    if (precPresent) {
      p = prec;
      if (p == 0 && u == BigInt.zero) {
        final oldZero = zero;
        zero = false;
        _writePadding(wid);
        zero = oldZero;
        return;
      }
    } else if (zero && !minus && widPresent) {
      p = wid;
      if (negative || plus || space) p--;
    }
    var digits = u.toRadixString(base);
    if (identical(digitSet, _hexUpper)) digits = digits.toUpperCase();
    if (digits.length < p) digits = '0' * (p - digits.length) + digits;
    if (sharp) {
      switch (base) {
        case 2:
          digits = '0b$digits';
        case 8:
          if (!digits.startsWith('0')) digits = '0$digits';
        case 16:
          digits = '0${identical(digitSet, _hexUpper) ? 'X' : 'x'}$digits';
      }
    }
    if (verb == 0x4f) digits = '0o$digits';
    if (negative) {
      digits = '-$digits';
    } else if (plus) {
      digits = '+$digits';
    } else if (space) {
      digits = ' $digits';
    }
    final oldZero = zero;
    zero = false;
    _pad(_ascii(digits));
    zero = oldZero;
  }

  void _fmtUnicode(BigInt v) {
    var hex = v.toUnsigned(64).toRadixString(16).toUpperCase();
    final p = precPresent && prec > 4 ? prec : 4;
    if (hex.length < p) hex = '0' * (p - hex.length) + hex;
    var s = 'U+$hex';
    if (sharp && !v.isNegative && v <= BigInt.from(0x10ffff)) {
      final r = v.toInt();
      if (isPrint(r)) s = "$s '${String.fromCharCode(r)}'";
    }
    final oldZero = zero;
    zero = false;
    _pad(utf8.encode(s));
    zero = oldZero;
  }

  // -------------------------------------------------------------- floats
  void _fmtFloatVerb(double v, int bits, int verb) {
    switch (verb) {
      case 0x76: // v
        if (sharpV) throw UnimplementedError('fmt: %#v de float');
        _fmtFloat(v, bits, 'g', -1);
      case 0x67 || 0x47: // g G
        _fmtFloat(v, bits, String.fromCharCode(verb), -1);
      case 0x65 || 0x45 || 0x66: // e E f
        _fmtFloat(v, bits, String.fromCharCode(verb), 6);
      case 0x46: // F
        _fmtFloat(v, bits, 'f', 6);
      case 0x62 || 0x78 || 0x58: // b x X
        throw UnimplementedError('fmt: %${String.fromCharCode(verb)} de float');
      default:
        _badVerb(verb);
    }
  }

  void _fmtFloat(double v, int bits, String fmt, int p) {
    if (precPresent) p = prec;
    final s = formatGoFloatFmt(v, fmt, p, bits);
    var num = s.startsWith('-') || s.startsWith('+') ? s : '+$s';
    if (space && num[0] == '+' && !plus) num = ' ${num.substring(1)}';
    if (num[1] == 'I' || num[1] == 'N') {
      final oldZero = zero;
      zero = false;
      if (num[1] == 'N' && !space && !plus) num = num.substring(1);
      _pad(_ascii(num));
      zero = oldZero;
      return;
    }
    if (sharp) throw UnimplementedError('fmt: # em float');
    if (plus || num[0] != '+') {
      if (zero && !minus && widPresent && wid > num.length) {
        _b.addByte(num.codeUnitAt(0));
        _writePadding(wid - num.length);
        _b.add(_ascii(num.substring(1)));
        return;
      }
      _pad(_ascii(num));
      return;
    }
    _pad(_ascii(num.substring(1)));
  }

  // -------------------------------------------------------------- strings
  void _fmtStringVerb(Uint8List s, int verb) {
    switch (verb) {
      case 0x76: // v
        if (sharpV) throw UnimplementedError('fmt: %#v de string');
        _pad(_truncate(s));
      case 0x73: // s
        _pad(_truncate(s));
      case 0x78: // x
        _fmtSbx(s, _hexLower);
      case 0x58: // X
        _fmtSbx(s, _hexUpper);
      case 0x71: // q
        final t = _truncate(s);
        if (sharp && _canBackquote(t)) {
          _pad([0x60, ...t, 0x60]);
        } else {
          _pad(_quote(t, 0x22, plus));
        }
      default:
        _badVerb(verb);
    }
  }

  /// Precisão em runas.
  List<int> _truncate(Uint8List s) {
    if (!precPresent) return s;
    var n = prec;
    for (var i = 0; i < s.length; i += _decodeRune(s, i).$2) {
      if (n-- <= 0) return Uint8List.sublistView(s, 0, i);
    }
    return s;
  }

  void _fmtSbx(Uint8List s, String digits) {
    var length = s.length;
    if (precPresent && prec < length) length = prec;
    var width = 2 * length;
    if (width > 0) {
      if (space) {
        if (sharp) width *= 2;
        width += length - 1;
      } else if (sharp) {
        width += 2;
      }
    } else {
      if (widPresent) _writePadding(wid);
      return;
    }
    if (widPresent && wid > width && !minus) _writePadding(wid - width);
    final x = identical(digits, _hexUpper) ? 0x58 : 0x78;
    if (sharp) _b.add([0x30, x]);
    for (var i = 0; i < length; i++) {
      if (space && i > 0) {
        _b.addByte(0x20);
        if (sharp) _b.add([0x30, x]);
      }
      _b.add([digits.codeUnitAt(s[i] >> 4), digits.codeUnitAt(s[i] & 0xf)]);
    }
    if (widPresent && wid > width && minus) _writePadding(wid - width);
  }
}

int _validRune(int r) =>
    r < 0 || r > 0x10ffff || (r >= 0xd800 && r <= 0xdfff) ? 0xfffd : r;

/// Runa UTF-8 em `s[i]`: (runa, largura); inválida → (U+FFFD, 1).
(int, int) _decodeRune(List<int> s, int i) {
  final c = s[i];
  if (c < 0x80) return (c, 1);
  final int need, min;
  var r = 0;
  if (c >= 0xc2 && c <= 0xdf) {
    need = 1;
    min = 0x80;
    r = c & 0x1f;
  } else if (c >= 0xe0 && c <= 0xef) {
    need = 2;
    min = 0x800;
    r = c & 0x0f;
  } else if (c >= 0xf0 && c <= 0xf4) {
    need = 3;
    min = 0x10000;
    r = c & 0x07;
  } else {
    return (0xfffd, 1);
  }
  if (i + need >= s.length) return (0xfffd, 1);
  for (var k = 1; k <= need; k++) {
    final b = s[i + k];
    if (b & 0xc0 != 0x80) return (0xfffd, 1);
    r = (r << 6) | (b & 0x3f);
  }
  if (r < min || r > 0x10ffff || (r >= 0xd800 && r <= 0xdfff)) {
    return (0xfffd, 1);
  }
  return (r, need + 1);
}

int _runeCount(List<int> s) {
  var n = 0;
  for (var i = 0; i < s.length; i += _decodeRune(s, i).$2) {
    n++;
  }
  return n;
}

/// `strconv.Quote` (`quote` = `"`) / `QuoteRune` (`'`); `ascii`: as versões
/// `...ToASCII`. Byte inválido vira `\xNN`.
List<int> _quote(List<int> s, int quote, bool ascii) {
  final out = <int>[quote];
  for (var i = 0; i < s.length;) {
    final (r, w) = _decodeRune(s, i);
    if (w == 1 && s[i] >= 0x80) {
      out.addAll(_ascii('\\x'));
      out.add(_hexLower.codeUnitAt(s[i] >> 4));
      out.add(_hexLower.codeUnitAt(s[i] & 0xf));
      i++;
      continue;
    }
    i += w;
    if (r == quote || r == 0x5c) {
      out.addAll([0x5c, r]);
    } else if (ascii ? r < 0x80 && isPrint(r) : isPrint(r)) {
      out.addAll(utf8.encode(String.fromCharCode(r)));
    } else {
      switch (r) {
        case 0x07:
          out.addAll(_ascii(r'\a'));
        case 0x08:
          out.addAll(_ascii(r'\b'));
        case 0x0c:
          out.addAll(_ascii(r'\f'));
        case 0x0a:
          out.addAll(_ascii(r'\n'));
        case 0x0d:
          out.addAll(_ascii(r'\r'));
        case 0x09:
          out.addAll(_ascii(r'\t'));
        case 0x0b:
          out.addAll(_ascii(r'\v'));
        default:
          if (r < 0x20 || r == 0x7f) {
            out.addAll(_ascii('\\x${r.toRadixString(16).padLeft(2, '0')}'));
          } else if (r < 0x10000) {
            out.addAll(_ascii('\\u${r.toRadixString(16).padLeft(4, '0')}'));
          } else {
            out.addAll(_ascii('\\U${r.toRadixString(16).padLeft(8, '0')}'));
          }
      }
    }
  }
  out.add(quote);
  return out;
}

/// `strconv.CanBackquote`.
bool _canBackquote(List<int> s) {
  for (var i = 0; i < s.length;) {
    final (r, w) = _decodeRune(s, i);
    if (w == 1 && s[i] >= 0x80) return false;
    i += w;
    if (r == 0xfeff || r == 0x60 || (r < 0x20 && r != 0x09) || r == 0x7f) {
      return false;
    }
  }
  return true;
}
