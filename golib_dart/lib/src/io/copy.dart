part of '../../io.dart';

// `io.Copy`/`CopyN`/`CopyBuffer` e `io.Discard`, com as duas formas (D2): o
// mesmo algoritmo, só muda o `await` nas chamadas de I/O.

/// `io.Copy(dst, src)`.
(Golang.Int64, GoError?) copy(Writer? dst, Reader? src) =>
    _copyBuffer(dst, src, null);

/// `io.Copy` suspensivo.
Future<(Golang.Int64, GoError?)> copy$async(Writer? dst, Reader? src) =>
    _copyBuffer$async(dst, src, null);

/// `io.CopyBuffer(dst, src, buf)`: `buf` vazio (não nil) é pânico, como no Go.
(Golang.Int64, GoError?) copyBuffer(
  Writer? dst,
  Reader? src,
  Slice<Golang.Uint8> buf,
) => _copyBuffer(dst, src, _userBuffer(buf));

/// `io.CopyBuffer` suspensivo.
Future<(Golang.Int64, GoError?)> copyBuffer$async(
  Writer? dst,
  Reader? src,
  Slice<Golang.Uint8> buf,
) => _copyBuffer$async(dst, src, _userBuffer(buf));

Slice<Golang.Uint8>? _userBuffer(Slice<Golang.Uint8> buf) {
  if (!buf.isNil && buf.length == 0) {
    throw Panic(Golang.String.fromDart('empty buffer in CopyBuffer'));
  }
  return buf.isNil ? null : buf;
}

/// `io.CopyN(dst, src, n)`.
(Golang.Int64, GoError?) copyN(Writer? dst, Reader? src, Golang.Int64 n) {
  final (written, err) = copy(dst, limitReader(src, n));
  return _copiedN(written, err, n);
}

/// `io.CopyN` suspensivo.
Future<(Golang.Int64, GoError?)> copyN$async(
  Writer? dst,
  Reader? src,
  Golang.Int64 n,
) async {
  final (written, err) = await copy$async(dst, limitReader(src, n));
  return _copiedN(written, err, n);
}

(Golang.Int64, GoError?) _copiedN(
  Golang.Int64 written,
  GoError? err,
  Golang.Int64 n,
) {
  if (written == n) return (n, null);
  if (written < n && err == null) return (written, eof);
  return (written, err);
}

/// `copyBuffer` (não exportado): a implementação de [copy]/[copyBuffer],
/// preferindo `WriterTo` do leitor e depois `ReaderFrom` do escritor.
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
  final b = buf ?? _copyBuf(s);
  final st = _CopyState();
  for (;;) {
    final (nr, er) = src!.read(b);
    if (nr.toInt() > 0) {
      final (nw, ew) = dst!.write(b.slice(0, nr.toInt()));
      if (st.wrote(nr, nw, ew)) break;
    }
    if (st.readDone(er)) break;
  }
  return (Golang.Int64(st.written), st.err);
}

/// `copyBuffer` suspensivo.
Future<(Golang.Int64, GoError?)> _copyBuffer$async(
  Writer? dst,
  Reader? src,
  Slice<Golang.Uint8>? buf,
) async {
  final Object? s = src;
  if (s case final WriterTo wt when goHasMethod(wt, 'WriteTo')) {
    return wt.writeTo$async(dst);
  }
  final Object? d = dst;
  if (d case final ReaderFrom rf when goHasMethod(rf, 'ReadFrom')) {
    return rf.readFrom$async(src);
  }
  final b = buf ?? _copyBuf(s);
  final st = _CopyState();
  for (;;) {
    final (nr, er) = await src!.read$async(b);
    if (nr.toInt() > 0) {
      final (nw, ew) = await dst!.write$async(b.slice(0, nr.toInt()));
      if (st.wrote(nr, nw, ew)) break;
    }
    if (st.readDone(er)) break;
  }
  return (Golang.Int64(st.written), st.err);
}

/// Buffer padrão do `Copy`: 32 KiB, ou menos sobre um [LimitedReader].
Slice<Golang.Uint8> _copyBuf(Object? src) {
  var size = 32 * 1024;
  if (src case final LimitedReader l when Golang.Int64(size) > l.n) {
    size = l.n < Golang.Int64(1) ? 1 : l.n.toInt();
  }
  return Slice<Golang.Uint8>.make(size, size, _byte);
}

/// Contas do laço do `copyBuffer` (comuns às duas formas).
final class _CopyState {
  var written = 0;
  GoError? err;

  /// Conta uma escrita; true se o laço para.
  bool wrote(Golang.Int nr, Golang.Int nw, GoError? ew) {
    var w = nw.toInt();
    var errW = ew;
    if (w < 0 || nr.toInt() < w) {
      w = 0;
      errW ??= _errInvalidWrite;
    }
    written += w;
    if (errW != null) {
      err = errW;
      return true;
    }
    if (nr.toInt() != w) {
      err = errShortWrite;
      return true;
    }
    return false;
  }

  /// O erro da leitura; true se o laço para.
  bool readDone(GoError? er) {
    if (er == null) return false;
    if (!identical(er, eof)) err = er;
    return true;
  }
}

/// `io.Discard`: Writer que aceita tudo e não faz nada; implementa
/// `ReaderFrom` como o Go (o `Copy` para `io.Discard` não escreve).
final Writer discard = _Discard();

final class _Discard
    with WriterSync, StringWriterSync
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
      if (err != null)
        return (Golang.Int64(n), identical(err, eof) ? null : err);
    }
  }

  @override
  Future<(Golang.Int64, GoError?)> readFrom$async(Reader? r) async {
    final buf = Slice<Golang.Uint8>.make(8192, 8192, _byte);
    var n = 0;
    for (;;) {
      final (readSize, err) = await r!.read$async(buf);
      n += readSize.toInt();
      if (err != null)
        return (Golang.Int64(n), identical(err, eof) ? null : err);
    }
  }

  @override
  String get $goType => 'io.discard';

  @override
  List<String> get $methods => const ['Write', 'WriteString', 'ReadFrom'];
}
