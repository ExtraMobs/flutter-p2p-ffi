/// Shim do pacote Go `io`: porta de `io.go`/`multi.go` do Go 1.26
/// (`io.Pipe`/`PipeReader`/`PipeWriter` dependem de goroutines — ver
/// `TODO/P0-design-m4-concorrencia.md`, seção "io.Pipe").
///
/// As interfaces entram em `SHIM_INTERFACES` (`g2d/config.py`): um tipo
/// gerado com `Write([]byte) (int, error)` declara `implements io.Writer`.
///
/// `io.SeekStart`/`io.SeekCurrent`/`io.SeekEnd` são constantes inteiras sem
/// tipo: o g2d as dobra no valor literal em cada uso (como `math.Pi`), então
/// não precisam de símbolo aqui.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

part 'src/io/funcs.dart';
part 'src/io/limited_reader.dart';
part 'src/io/section_reader.dart';
part 'src/io/offset_writer.dart';
part 'src/io/multi.dart';
part 'src/io/tee_reader.dart';

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

/// `errInvalidWrite` (não exportado): resultado impossível de `Write`.
final GoError _errInvalidWrite = _err('invalid write result');

/// `errWhence` (não exportado): `Seek` com whence inválido.
final GoError _errWhence = _err('Seek: invalid whence');

/// `errOffset` (não exportado): `Seek`/`WriteAt` com offset inválido.
final GoError _errOffset = _err('Seek: invalid offset');

const _byte = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);

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

/// `io.Closer`.
abstract interface class Closer {
  GoError? close();
}

/// `io.Seeker`.
abstract interface class Seeker {
  (Golang.Int64, GoError?) seek(Golang.Int64 offset, Golang.Int whence);
}

/// `io.ReaderAt`.
abstract interface class ReaderAt {
  (Golang.Int, GoError?) readAt(Slice<Golang.Uint8> p, Golang.Int64 off);
}

/// `io.WriterAt`.
abstract interface class WriterAt {
  (Golang.Int, GoError?) writeAt(Slice<Golang.Uint8> p, Golang.Int64 off);
}

/// `io.ReaderFrom`.
abstract interface class ReaderFrom {
  (Golang.Int64, GoError?) readFrom(Reader? r);
}

/// `io.WriterTo`.
abstract interface class WriterTo {
  (Golang.Int64, GoError?) writeTo(Writer? w);
}

/// `io.RuneReader`.
abstract interface class RuneReader {
  (Golang.Rune, Golang.Int, GoError?) readRune();
}

/// `io.ByteScanner`.
abstract interface class ByteScanner implements ByteReader {
  GoError? unreadByte();
}

/// `io.RuneScanner`.
abstract interface class RuneScanner implements RuneReader {
  GoError? unreadRune();
}

/// `io.ReadCloser`.
abstract interface class ReadCloser implements Reader, Closer {}

/// `io.WriteCloser`.
abstract interface class WriteCloser implements Writer, Closer {}

/// `io.ReadWriter`.
abstract interface class ReadWriter implements Reader, Writer {}

/// `io.ReadWriteCloser`.
abstract interface class ReadWriteCloser implements Reader, Writer, Closer {}

/// `io.ReadSeeker`.
abstract interface class ReadSeeker implements Reader, Seeker {}

/// `io.ReadSeekCloser`.
abstract interface class ReadSeekCloser implements Reader, Seeker, Closer {}

/// `io.WriteSeeker`.
abstract interface class WriteSeeker implements Writer, Seeker {}

/// `io.ReadWriteSeeker`.
abstract interface class ReadWriteSeeker implements Reader, Writer, Seeker {}
