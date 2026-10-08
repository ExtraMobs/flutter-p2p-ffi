part of '../../net.dart';

// `net.Buffers` (net.go) e o `writeBuffers` das conexões (`writev_unix.go`
// + `poll.FD.Writev`). `Buffers` tem a forma de tipo nomeado gerado
// (`SHIM_NAMED_CLASSES`); os métodos são de `*Buffers` ([Buffers$Ptr]).
// `WriteTo` é dual (`DUAL_SHIM_CALLS`): suspende quando o `Write` do
// destino suspende, e numa conexão do shim sempre (o `writev`).

/// `net.Buffers` (`type Buffers [][]byte`).
final class Buffers extends Slice<_Bytes> implements Golang.GoTyped {
  Buffers(Slice<_Bytes> v) : super.alias(v);

  @override
  String get $goType => 'net.Buffers';
  @override
  List<String> get $methods => const [];
}

/// `*net.Buffers`: vista sobre qualquer ponteiro para o valor.
final class Buffers$Ptr extends PtrView<Buffers>
    with io.ReaderSync
    implements io.Reader, io.WriterTo {
  Buffers$Ptr(super.$p);

  /// `(*Buffers)(nil)` dentro de uma interface.
  static final Buffers$Ptr $nil = Buffers$Ptr(const NilPtr<Buffers>());

  @override
  String get $goType => '*net.Buffers';
  @override
  List<String> get $methods => const ['Read', 'WriteTo'];

  /// `WriteTo(w)` síncrono; numa conexão do shim, o `writev` suspende.
  @override
  (Golang.Int64, GoError?) writeTo(io.Writer? w) {
    if (w is _BuffersWriter) syncOfAsync('net.Buffers.WriteTo');
    final s = value;
    var n = 0;
    for (var i = 0; i < s.length; i++) {
      final (nb, err) = w!.write(s[i]);
      n += nb.toInt();
      if (err != null) return _wrote(n, err);
    }
    return _wrote(n, null);
  }

  /// `WriteTo(w)`: o `writeBuffers` da conexão, ou um `Write` por pedaço.
  @override
  Future<(Golang.Int64, GoError?)> writeTo$async(io.Writer? w) async {
    if (w is _BuffersWriter) return (w as _BuffersWriter)._writeBuffers(this);
    final s = value;
    var n = 0;
    for (var i = 0; i < s.length; i++) {
      final (nb, err) = await w!.write$async(s[i]);
      n += nb.toInt();
      if (err != null) return _wrote(n, err);
    }
    return _wrote(n, null);
  }

  (Golang.Int64, GoError?) _wrote(int n, GoError? err) {
    _consume(n);
    return (Golang.Int64(n), err);
  }

  /// `Read(p)`: copia e consome; `EOF` quando acabou.
  @override
  (Golang.Int, GoError?) read(_Bytes p) {
    var n = 0;
    while (p.length > 0 && value.length > 0) {
      final n0 = p.copyFrom(value[0]);
      _consume(n0);
      p = p.slice(n0);
      n += n0;
    }
    return (Golang.Int(n), value.length == 0 ? io.eof : null);
  }

  /// `consume(n)`: muda o slice e os `v[i]`, nunca os bytes.
  void _consume(int n) {
    while (value.length > 0) {
      final ln0 = value[0].length;
      if (ln0 > n) {
        value[0] = value[0].slice(n);
        return;
      }
      n -= ln0;
      value[0] = Slice.nil(_byteElem);
      value = Buffers(value.slice(1));
    }
  }
}

/// `buffersWriter`: as conexões do shim.
abstract interface class _BuffersWriter {
  Future<(Golang.Int64, GoError?)> _writeBuffers(Buffers$Ptr v);
}

/// `(*conn).writeBuffers` sobre o `poll.FD.Writev`: até 1024 pedaços não
/// vazios por vez. Rede FFI ([sys.SysWritev]): o `writev(2)` de verdade.
/// Nas outras (`dart:io`, Node), os pedaços juntos num [write] só (a
/// mesma mensagem no datagrama), com o erro renomeado para o do Go
/// (`writev ...: writev: ...`).
Future<(Golang.Int64, GoError?)> _writeBuffersVia(
  Buffers$Ptr v,
  Object? fd,
  bool closed,
  Future<(Golang.Int, GoError?)> Function(_Bytes) write,
  GoError Function(String op, Object e) op,
) async {
  var n = 0;
  while (v.value.length > 0) {
    final chunks = <Uint8List>[];
    final s = v.value;
    for (var i = 0; i < s.length && chunks.length < 1024; i++) {
      if (s[i].length > 0) chunks.add(_u8(s[i]));
    }
    if (chunks.isEmpty) break;
    int k;
    GoError? err;
    if (fd is sys.SysWritev && !closed) {
      try {
        k = await fd.writev(chunks);
      } on Object catch (e) {
        k = e is sys.SysException ? e.written : 0;
        err = op('writev', e);
      }
    } else {
      final all = Uint8List(chunks.fold(0, (t, c) => t + c.length));
      var o = 0;
      for (final c in chunks) {
        all.setAll(o, c);
        o += c.length;
      }
      final (w, e) = await write(_bytes(all));
      k = w.toInt();
      err = _asWritev(e);
    }
    n += k;
    v._consume(k);
    if (err != null) return (Golang.Int64(n), err);
  }
  return (Golang.Int64(n), null);
}

/// O `*OpError` de um `Write` como o do `writev`.
GoError? _asWritev(GoError? err) {
  if (err is! OpError) return err;
  final e = err.err;
  return OpError(
    op: _gs('writev'),
    net: err.net,
    source: err.source,
    addr: err.addr$,
    err: e is os.SyscallError
        ? os.SyscallError(syscall: _gs('writev'), err: e.err)
        : e,
  );
}
