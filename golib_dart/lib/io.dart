/// Shim do pacote Go `io` (parcial: erros sentinela e as interfaces básicas;
/// o resto em `TODO/P0-shim-io.md`).
///
/// As interfaces entram em `SHIM_INTERFACES` (`g2d/config.py`): um tipo
/// gerado com `Write([]byte) (int, error)` declara `implements io.Writer`.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

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

/// `io.Reader`.
abstract interface class Reader {
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p);
}

/// `io.Writer`.
abstract interface class Writer {
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p);
}

/// `io.ByteReader`.
abstract interface class ByteReader {
  (Golang.Uint8, GoError?) readByte();
}

/// `io.ByteWriter`.
abstract interface class ByteWriter {
  GoError? writeByte(Golang.Uint8 c);
}

/// `io.StringWriter`.
abstract interface class StringWriter {
  (Golang.Int, GoError?) writeString(Golang.String s);
}
