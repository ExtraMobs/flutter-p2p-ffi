/// Shim do pacote Go `fmt`.
// ignore_for_file: library_prefixes
library;

import 'dart:convert';
import 'dart:typed_data';

import 'builtin.dart';
import 'io.dart' as io;
import 'fixed_types/golang.dart' as Golang;
import 'fixed_types/golang/src/float_format.dart' show formatGoFloatFmt;
import 'src/runtime/output.dart';
import 'src/unicode/isprint.dart';

part 'src/fmt/format.dart';
part 'src/fmt/print.dart';
part 'src/fmt/value.dart';
part 'src/fmt/sort_keys.dart';
part 'src/fmt/quote.dart';

/// `fmt.Stringer`.
abstract interface class Stringer {
  Golang.String string();
}

/// `fmt.GoStringer`: `%#v` chama `GoString()` (sem aspas/escape) quando o
/// tipo o implementa, em vez da sintaxe Go estrutural.
abstract interface class GoStringer {
  Golang.String goString();
}

/// `fmt.State`: o printer visto pelo método `Format` (flags, largura,
/// precisão e a saída).
abstract interface class State implements io.Writer {
  (Golang.Int, bool) width();
  (Golang.Int, bool) precision();
  bool flag(Golang.Int c);
}

/// `fmt.Formatter`: `Format(f State, verb rune)` troca a formatação de
/// todos os verbos (menos `%T` e `%p`), como no Go.
abstract interface class Formatter {
  void format(State? f, Golang.Rune verb);
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

// ------------------------------------------------------------------ Printf

/// `fmt.Sprintf`.
Golang.String sprintf(Golang.String format, Slice<Object?> a) =>
    Golang.String.fromBytes(_Printer(a.items.toList()).run(format.toBytes()));

/// `fmt.Printf`: como [sprintf], escrito na saída padrão.
(Golang.Int, GoError?) printf(Golang.String format, Slice<Object?> a) {
  final bytes = _Printer(a.items.toList()).run(format.toBytes());
  writeStdout(bytes);
  return (Golang.Int(bytes.length), null);
}

(Golang.Int, GoError?) _fwrite(io.Writer? w, Uint8List bytes) =>
    w!.write(Slice.of([for (final b in bytes) Golang.Uint8(b)], _fbyte));

const _fbyte = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

/// `fmt.Fprint(w, a...)`: como [sprint], escrito em w (um só `Write`).
(Golang.Int, GoError?) fprint(io.Writer? w, Slice<Object?> args) =>
    _fwrite(w, _sprint(args));

/// `fmt.Fprintln(w, a...)`.
(Golang.Int, GoError?) fprintln(io.Writer? w, Slice<Object?> args) =>
    _fwrite(w, _sprintln(args));

/// `fmt.Fprintf(w, format, a...)`.
(Golang.Int, GoError?) fprintf(
  io.Writer? w,
  Golang.String format,
  Slice<Object?> a,
) => _fwrite(w, _Printer(a.items.toList()).run(format.toBytes()));

/// `fmt.Errorf`: sem `%w`, `*errors.errorString`; com um, `*fmt.wrapError`
/// (Unwrap devolve o operando); com vários, `*fmt.wrapErrors`.
GoError? errorf(Golang.String format, Slice<Object?> a) {
  final args = a.items.toList();
  final p = _Printer(args, wrapErrs: true);
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
