part of '../../io.dart';

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

/// `io.Copy(dst, src)`.
(Golang.Int64, GoError?) copy(Writer? dst, Reader? src) =>
    _copyBuffer(dst, src, null);

/// `io.CopyBuffer(dst, src, buf)`: `buf` vazio (não nil) é pânico, como no Go.
(Golang.Int64, GoError?) copyBuffer(
  Writer? dst,
  Reader? src,
  Slice<Golang.Uint8> buf,
) {
  if (!buf.isNil && buf.length == 0) {
    throw Panic(Golang.String.fromDart('empty buffer in CopyBuffer'));
  }
  return _copyBuffer(dst, src, buf.isNil ? null : buf);
}

/// `io.CopyN(dst, src, n)`.
(Golang.Int64, GoError?) copyN(Writer? dst, Reader? src, Golang.Int64 n) {
  final (written, err) = copy(dst, limitReader(src, n));
  if (written == n) return (n, null);
  if (written < n && err == null) return (written, eof);
  return (written, err);
}

/// `copyBuffer` (não exportado): a implementação de [copy]/[copyBuffer],
/// preferindo `WriterTo`/`ReaderFrom` como o Go.
(Golang.Int64, GoError?) _copyBuffer(
  Writer? dst,
  Reader? src,
  Slice<Golang.Uint8>? buf,
) {
  final Object? s = src;
  if (s case final WriterTo wt when goHasMethod(wt, 'WriteTo')) {
    return wt.writeTo(dst);
  }
  final Object? d = dst;
  if (d case final ReaderFrom rf when goHasMethod(rf, 'ReadFrom')) {
    return rf.readFrom(src);
  }
  var b = buf;
  if (b == null) {
    var size = 32 * 1024;
    if (s case final LimitedReader l when Golang.Int64(size) > l.n) {
      size = l.n < Golang.Int64(1) ? 1 : l.n.toInt();
    }
    b = Slice<Golang.Uint8>.make(size, size, _byte);
  }
  var written = 0;
  GoError? err;
  for (;;) {
    final (nr, er) = src!.read(b);
    if (nr.toInt() > 0) {
      final (nw, ew) = dst!.write(b.slice(0, nr.toInt()));
      var w = nw.toInt();
      var errW = ew;
      if (w < 0 || nr.toInt() < w) {
        w = 0;
        errW ??= _errInvalidWrite;
      }
      written += w;
      if (errW != null) {
        err = errW;
        break;
      }
      if (nr.toInt() != w) {
        err = errShortWrite;
        break;
      }
    }
    if (er != null) {
      if (!identical(er, eof)) err = er;
      break;
    }
  }
  return (Golang.Int64(written), err);
}

/// `io.Discard`: Writer que aceita tudo e não faz nada; implementa
/// `ReaderFrom` como otimização (o `Copy` para `io.Discard` não escreve).
final Writer discard = _Discard();

final class _Discard
    implements Writer, StringWriter, ReaderFrom, Golang.GoTyped {
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) =>
      (Golang.Int(p.length), null);

  @override
  (Golang.Int, GoError?) writeString(Golang.String s) =>
      (Golang.Int(s.length), null);

  @override
  (Golang.Int64, GoError?) readFrom(Reader? r) {
    final buf = Slice<Golang.Uint8>.make(8192, 8192, _byte);
    var n = 0;
    for (;;) {
      final (readSize, err) = r!.read(buf);
      n += readSize.toInt();
      if (err != null) {
        if (identical(err, eof)) return (Golang.Int64(n), null);
        return (Golang.Int64(n), err);
      }
    }
  }

  @override
  String get $goType => 'io.discard';

  @override
  List<String> get $methods => const ['Write', 'WriteString', 'ReadFrom'];
}

/// `io.NopCloser(r)`: `ReadCloser` com `Close` sem efeito; se `r` implementa
/// `WriterTo`, o resultado também implementa (encaminhando para `r`).
ReadCloser nopCloser(Reader? r) {
  final Object? o = r;
  if (o case final WriterTo wt when goHasMethod(wt, 'WriteTo')) {
    return _NopCloserWriterTo(r);
  }
  return _NopCloser(r);
}

final class _NopCloser implements ReadCloser, Golang.GoTyped {
  _NopCloser(this._r);

  final Reader? _r;

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) => _r!.read(p);

  @override
  GoError? close() => null;

  @override
  String get $goType => 'io.nopCloser';

  @override
  List<String> get $methods => const ['Read', 'Close'];
}

final class _NopCloserWriterTo implements ReadCloser, WriterTo, Golang.GoTyped {
  _NopCloserWriterTo(this._r);

  final Reader? _r;

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) => _r!.read(p);

  @override
  GoError? close() => null;

  @override
  (Golang.Int64, GoError?) writeTo(Writer? w) => (_r as WriterTo).writeTo(w);

  @override
  String get $goType => 'io.nopCloserWriterTo';

  @override
  List<String> get $methods => const ['Read', 'Close', 'WriteTo'];
}
