/// Shim do pacote Go `io` (parcial: erros sentinela, interfaces, ReadFull,
/// ReadAll, WriteString, Discard, Pipe; o resto em `TODO/P1-shim-io.md`).
///
/// As interfaces entram em `SHIM_INTERFACES` (`g2d/config.py`): um tipo
/// gerado com `Write([]byte) (int, error)` declara `implements io.Writer`.
///
/// Versão dupla (decisão D2, `docs/mapping-spec.md` § "I/O que suspende"):
/// cada método de I/O tem a forma síncrona (`read`) e a suspensiva
/// (`read$async`, sufixo impossível em Go), e cada função do shim que chama
/// esses métodos também (`readAll` e `readAll$async`). O g2d escolhe pela
/// cor: o método de interface é `async` quando alguma implementação que
/// chega nele no grafo suspende. Quem nunca suspende (`bytes.Buffer`,
/// `strings.Reader`...) ganha o `$async` dos mixins `*Sync`.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

part 'src/io/interfaces.dart';
part 'src/io/read_write.dart';
part 'src/io/pipe.dart';

GoError _err(String s) => ErrorString(Golang.String.fromDart(s));

/// `io.EOF`.
final GoError eof = _err('EOF');

/// `io.ErrUnexpectedEOF`.
final GoError errUnexpectedEOF = _err('unexpected EOF');

/// `io.ErrShortWrite`.
final GoError errShortWrite = _err('short write');

/// `io.ErrShortBuffer`.
final GoError errShortBuffer = _err('short buffer');

/// `io.ErrNoProgress`.
final GoError errNoProgress = _err(
  'multiple Read calls return no data or error',
);

/// `io.ErrClosedPipe`.
final GoError errClosedPipe = _err('io: read/write on closed pipe');

/// `io.SeekStart`, `io.SeekCurrent`, `io.SeekEnd` vêm dobradas pelo g2d.

const _byte = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);

/// `io.Discard`: Writer que aceita tudo e não faz nada.
final Writer discard = _Discard();

final class _Discard
    with WriterSync, StringWriterSync
    implements Writer, StringWriter, Golang.GoTyped {
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) =>
      (Golang.Int(p.length), null);

  @override
  (Golang.Int, GoError?) writeString(Golang.String s) =>
      (Golang.Int(s.length), null);

  @override
  String get $goType => 'io.discard';

  @override
  List<String> get $methods => const ['Write', 'WriteString'];
}
