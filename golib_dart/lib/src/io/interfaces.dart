part of '../../io.dart';

// Interfaces de I/O com versão dupla (D2): `m` síncrono e `m$async`. Uma
// implementação que nunca suspende usa o mixin `*Sync` (o `$async` chama o
// síncrono); uma gerada que suspende tem o corpo no `$async`, e o síncrono
// cai no `fatal` `g2d:` de [syncOfAsync] (o g2d nunca o chama).

/// `io.Reader`.
abstract interface class Reader {
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p);
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p);
}

/// `io.Writer`.
abstract interface class Writer {
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p);
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> p);
}

/// `io.ByteReader`.
abstract interface class ByteReader {
  (Golang.Uint8, GoError?) readByte();
  Future<(Golang.Uint8, GoError?)> readByte$async();
}

/// `io.ByteWriter`.
abstract interface class ByteWriter {
  GoError? writeByte(Golang.Uint8 c);
  Future<GoError?> writeByte$async(Golang.Uint8 c);
}

/// `io.StringWriter`.
abstract interface class StringWriter {
  (Golang.Int, GoError?) writeString(Golang.String s);
  Future<(Golang.Int, GoError?)> writeString$async(Golang.String s);
}

/// `io.Closer`.
abstract interface class Closer {
  GoError? close();
  Future<GoError?> close$async();
}

/// `io.Seeker` (só síncrono: nenhum `Seek` do grafo espera outra goroutine).
abstract interface class Seeker {
  (Golang.Int64, GoError?) seek(Golang.Int64 offset, Golang.Int whence);
}

/// `io.ReaderAt`.
abstract interface class ReaderAt {
  (Golang.Int, GoError?) readAt(Slice<Golang.Uint8> p, Golang.Int64 off);
  Future<(Golang.Int, GoError?)> readAt$async(
    Slice<Golang.Uint8> p,
    Golang.Int64 off,
  );
}

/// `io.WriterAt`.
abstract interface class WriterAt {
  (Golang.Int, GoError?) writeAt(Slice<Golang.Uint8> p, Golang.Int64 off);
  Future<(Golang.Int, GoError?)> writeAt$async(
    Slice<Golang.Uint8> p,
    Golang.Int64 off,
  );
}

/// `io.ReaderFrom`: `ReadFrom` chama `Read` no argumento, então tem as duas
/// formas como os métodos de I/O.
abstract interface class ReaderFrom {
  (Golang.Int64, GoError?) readFrom(Reader? r);
  Future<(Golang.Int64, GoError?)> readFrom$async(Reader? r);
}

/// `io.WriterTo`: `WriteTo` chama `Write` no argumento (duas formas).
abstract interface class WriterTo {
  (Golang.Int64, GoError?) writeTo(Writer? w);
  Future<(Golang.Int64, GoError?)> writeTo$async(Writer? w);
}

/// `io.RuneReader` (só síncrono, como [Seeker]).
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

/// `read$async` de um [Reader] que nunca suspende.
mixin ReaderSync implements Reader {
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) async =>
      this.read(p);
}

/// `write$async` de um [Writer] que nunca suspende.
mixin WriterSync implements Writer {
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> p) async =>
      this.write(p);
}

/// `readByte$async` de um [ByteReader] que nunca suspende.
mixin ByteReaderSync implements ByteReader {
  @override
  Future<(Golang.Uint8, GoError?)> readByte$async() async => this.readByte();
}

/// `writeByte$async` de um [ByteWriter] que nunca suspende.
mixin ByteWriterSync implements ByteWriter {
  @override
  Future<GoError?> writeByte$async(Golang.Uint8 c) async => this.writeByte(c);
}

/// `writeString$async` de um [StringWriter] que nunca suspende.
mixin StringWriterSync implements StringWriter {
  @override
  Future<(Golang.Int, GoError?)> writeString$async(Golang.String s) async =>
      this.writeString(s);
}

/// `close$async` de um [Closer] que nunca suspende.
mixin CloserSync implements Closer {
  @override
  Future<GoError?> close$async() async => this.close();
}

/// `readAt$async` de um [ReaderAt] que nunca suspende.
mixin ReaderAtSync implements ReaderAt {
  @override
  Future<(Golang.Int, GoError?)> readAt$async(
    Slice<Golang.Uint8> p,
    Golang.Int64 off,
  ) async => this.readAt(p, off);
}

/// `writeAt$async` de um [WriterAt] que nunca suspende.
mixin WriterAtSync implements WriterAt {
  @override
  Future<(Golang.Int, GoError?)> writeAt$async(
    Slice<Golang.Uint8> p,
    Golang.Int64 off,
  ) async => this.writeAt(p, off);
}
