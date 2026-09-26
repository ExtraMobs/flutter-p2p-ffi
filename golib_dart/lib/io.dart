/// Shim do pacote Go `io` (parcial: erros sentinela, interfaces, ReadFull,
/// ReadAll, WriteString, Discard; o resto em `TODO/P0-shim-io.md`).
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

/// `io.WriteSeeker`.
abstract interface class WriteSeeker implements Writer, Seeker {}

/// `io.ReadWriteSeeker`.
abstract interface class ReadWriteSeeker implements Reader, Writer, Seeker {}

/// `io.SeekStart`, `io.SeekCurrent`, `io.SeekEnd` vêm dobradas pelo g2d.

const _byte = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);

/// `io.ReadAtLeast(r, buf, min)`: lê até ter pelo menos min bytes;
/// `ErrShortBuffer` se buf for menor, `ErrUnexpectedEOF` se o EOF vier no meio.
(Golang.Int, GoError?) readAtLeast(
  Reader? r,
  Slice<Golang.Uint8> buf,
  Golang.Int min,
) {
  final m = min.toIndex();
  if (buf.length < m) return (Golang.Int(0), errShortBuffer);
  var n = 0;
  GoError? err;
  while (n < m && err == null) {
    final (nn, e) = r!.read(buf.slice(n));
    n += nn.toInt();
    err = e;
  }
  if (n >= m) {
    err = null;
  } else if (n > 0 && identical(err, eof)) {
    err = errUnexpectedEOF;
  }
  return (Golang.Int(n), err);
}

/// `io.ReadFull(r, buf)`.
(Golang.Int, GoError?) readFull(Reader? r, Slice<Golang.Uint8> buf) =>
    readAtLeast(r, buf, Golang.Int(buf.length));

/// `io.WriteString(w, s)`: `WriteString` do próprio w se ele tiver (no method
/// set do valor), senão `Write([]byte(s))`.
(Golang.Int, GoError?) writeString(Writer? w, Golang.String s) {
  final Object? o = w;
  if (o case final StringWriter sw when goHasMethod(sw, 'WriteString')) {
    return sw.writeString(s);
  }
  return w!.write(bytesOf(s, _byte));
}

/// `io.ReadAll(r)`: o algoritmo do Go 1.26 (pedaços crescendo 1,5× a partir
/// de 256 bytes, copiados no fim num slice do tamanho certo; mesmo `cap`).
(Slice<Golang.Uint8>, GoError?) readAll(Reader? r) {
  Slice<Golang.Uint8> fresh(int n) =>
      Slice<Golang.Uint8>.nil(_byte)
          .appendSlice(Slice<Golang.Uint8>.make(n, n, _byte))
          .slice(0, 0);

  var b = Slice<Golang.Uint8>.make(0, 512, _byte);
  var next = 256;
  final chunks = <Slice<Golang.Uint8>>[];
  var finalSize = 0;
  for (;;) {
    final (n, err) = r!.read(b.slice(b.length, b.capacity));
    b = b.slice(0, b.length + n.toInt());
    if (err != null) {
      final e = identical(err, eof) ? null : err;
      if (chunks.isEmpty) return (b, e);
      finalSize += b.length;
      var out = fresh(finalSize);
      for (final c in chunks) {
        out = out.appendSlice(c);
      }
      return (out.appendSlice(b), e);
    }
    if (b.capacity - b.length < b.capacity ~/ 16) {
      chunks.add(b);
      finalSize += b.length;
      b = fresh(next);
      next += next ~/ 2;
    }
  }
}

/// `io.Discard`: Writer que aceita tudo e não faz nada.
final Writer discard = _Discard();

final class _Discard implements Writer, StringWriter, Golang.GoTyped {
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
