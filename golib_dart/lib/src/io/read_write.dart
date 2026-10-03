part of '../../io.dart';

// Funções que chamam métodos de I/O: cada uma tem a versão síncrona e a
// `$async` (D2), com o mesmo algoritmo; só muda o `await` na chamada.

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
  return _atLeast(n, m, err);
}

/// `io.ReadAtLeast` suspensivo.
Future<(Golang.Int, GoError?)> readAtLeast$async(
  Reader? r,
  Slice<Golang.Uint8> buf,
  Golang.Int min,
) async {
  final m = min.toIndex();
  if (buf.length < m) return (Golang.Int(0), errShortBuffer);
  var n = 0;
  GoError? err;
  while (n < m && err == null) {
    final (nn, e) = await r!.read$async(buf.slice(n));
    n += nn.toInt();
    err = e;
  }
  return _atLeast(n, m, err);
}

(Golang.Int, GoError?) _atLeast(int n, int m, GoError? err) {
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

/// `io.ReadFull` suspensivo.
Future<(Golang.Int, GoError?)> readFull$async(
  Reader? r,
  Slice<Golang.Uint8> buf,
) => readAtLeast$async(r, buf, Golang.Int(buf.length));

/// `io.WriteString(w, s)`: `WriteString` do próprio w se ele tiver (no method
/// set do valor), senão `Write([]byte(s))`.
(Golang.Int, GoError?) writeString(Writer? w, Golang.String s) {
  final Object? o = w;
  if (o case final StringWriter sw when goHasMethod(sw, 'WriteString')) {
    return sw.writeString(s);
  }
  return w!.write(bytesOf(s, _byte));
}

/// `io.WriteString` suspensivo.
Future<(Golang.Int, GoError?)> writeString$async(
  Writer? w,
  Golang.String s,
) async {
  final Object? o = w;
  if (o case final StringWriter sw when goHasMethod(sw, 'WriteString')) {
    return sw.writeString$async(s);
  }
  return w!.write$async(bytesOf(s, _byte));
}

/// `io.ReadAll(r)`: o algoritmo do Go 1.26 (pedaços crescendo 1,5× a partir
/// de 256 bytes, copiados no fim num slice do tamanho certo; mesmo `cap`).
(Slice<Golang.Uint8>, GoError?) readAll(Reader? r) {
  final acc = _ReadAll();
  for (;;) {
    final (n, err) = r!.read(acc.free);
    final out = acc.add(n, err);
    if (out != null) return out;
  }
}

/// `io.ReadAll` suspensivo.
Future<(Slice<Golang.Uint8>, GoError?)> readAll$async(Reader? r) async {
  final acc = _ReadAll();
  for (;;) {
    final (n, err) = await r!.read$async(acc.free);
    final out = acc.add(n, err);
    if (out != null) return out;
  }
}

/// Estado do `ReadAll` entre leituras (comum às duas versões).
final class _ReadAll {
  var b = Slice<Golang.Uint8>.make(0, 512, _byte);
  var next = 256;
  final chunks = <Slice<Golang.Uint8>>[];
  var finalSize = 0;

  static Slice<Golang.Uint8> _fresh(int n) =>
      Slice<Golang.Uint8>.nil(_byte)
          .appendSlice(Slice<Golang.Uint8>.make(n, n, _byte))
          .slice(0, 0);

  /// Onde a próxima leitura escreve.
  Slice<Golang.Uint8> get free => b.slice(b.length, b.capacity);

  /// Conta uma leitura; devolve o resultado do `ReadAll` quando acabou.
  (Slice<Golang.Uint8>, GoError?)? add(Golang.Int n, GoError? err) {
    b = b.slice(0, b.length + n.toInt());
    if (err != null) {
      final e = identical(err, eof) ? null : err;
      if (chunks.isEmpty) return (b, e);
      finalSize += b.length;
      var out = _fresh(finalSize);
      for (final c in chunks) {
        out = out.appendSlice(c);
      }
      return (out.appendSlice(b), e);
    }
    if (b.capacity - b.length < b.capacity ~/ 16) {
      chunks.add(b);
      finalSize += b.length;
      b = _fresh(next);
      next += next ~/ 2;
    }
    return null;
  }
}
