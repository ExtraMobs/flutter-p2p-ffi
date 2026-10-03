part of '../../io.dart';

// `io.Pipe`: porta de `io/pipe.go` do Go 1.26 sobre `Chan`/`select` do
// runtime (as goroutines são as cadeias async do escalonador, então o
// detector de deadlock vê quem espera no pipe). `Read`/`Write` suspendem: o
// g2d sempre chama `read$async`/`write$async` (estão em
// `ASYNC_SHIM_METHODS`, `g2d/services/dual.py`); a forma síncrona só serve
// com o pipe já fechado, e fora disso é o `fatal` `g2d:` de [syncOfAsync].

/// Erro guardado uma vez (`onceError`): o primeiro `Store` vence.
final class _OnceError {
  GoError? _err;
  void store(GoError? err) => _err ??= err;
  GoError? load() => _err;
}

final class _Pipe {
  final _wrMu = _WriteLock();
  final _wrCh = Chan<Slice<Golang.Uint8>>(0, Slice.nil(_byte));
  final _rdCh = Chan<int>(0, 0);
  final _done = Chan<EmptyStruct>(0, EmptyStruct());
  bool _closed = false;
  final _rerr = _OnceError();
  final _werr = _OnceError();

  bool get _isDone => selectNow([RecvCase(_done)]).$1 == 0;

  Future<(Golang.Int, GoError?)> read(Slice<Golang.Uint8> b) async {
    if (_isDone) return (Golang.Int(0), _readCloseError());
    final (i, v, _) = await select([RecvCase(_wrCh), RecvCase(_done)]);
    if (i != 0) return (Golang.Int(0), _readCloseError());
    final nr = b.copyFrom(v as Slice<Golang.Uint8>);
    await _rdCh.send(nr);
    return (Golang.Int(nr), null);
  }

  Future<(Golang.Int, GoError?)> write(Slice<Golang.Uint8> b) async {
    if (_isDone) return (Golang.Int(0), _writeCloseError());
    await _wrMu.lock();
    try {
      var n = 0;
      for (var once = true; once || b.length > 0; once = false) {
        final (i, _, _) = await select([SendCase(_wrCh, b), RecvCase(_done)]);
        if (i != 0) return (Golang.Int(n), _writeCloseError());
        final nw = await _rdCh.recv();
        b = b.slice(nw);
        n += nw;
      }
      return (Golang.Int(n), null);
    } finally {
      _wrMu.unlock();
    }
  }

  GoError? closeRead(GoError? err) {
    _rerr.store(err ?? errClosedPipe);
    _close();
    return null;
  }

  GoError? closeWrite(GoError? err) {
    _werr.store(err ?? eof);
    _close();
    return null;
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _done.close();
  }

  GoError _readCloseError() {
    final rerr = _rerr.load(), werr = _werr.load();
    if (rerr == null && werr != null) return werr;
    return errClosedPipe;
  }

  GoError _writeCloseError() {
    final werr = _werr.load(), rerr = _rerr.load();
    if (werr == null && rerr != null) return rerr;
    return errClosedPipe;
  }
}

/// `wrMu` do pipe: serializa os `Write` (FIFO), contando a espera como
/// bloqueio para o detector de deadlock, como o `sync.Mutex`.
final class _WriteLock {
  var _locked = false;
  final _waiters = <Chan<EmptyStruct>>[];

  Future<void> lock() async {
    if (!_locked) {
      _locked = true;
      return;
    }
    final c = Chan<EmptyStruct>(0, EmptyStruct());
    _waiters.add(c);
    await c.recv();
  }

  void unlock() {
    if (_waiters.isEmpty) {
      _locked = false;
      return;
    }
    _waiters.removeAt(0).close(); // passa a trava adiante
  }
}

/// `io.PipeReader`.
final class PipeReader extends GoStruct<PipeReader>
    with CloserSync
    implements ReadCloser {
  PipeReader._(this._p);

  /// `(*PipeReader)(nil)` dentro de uma interface.
  static final PipeReader $nil = PipeReader._(_Pipe())..$nilPtr = true;

  final _Pipe _p;

  @override
  String get $goType => 'io.PipeReader';
  @override
  List<String> get $ptrMethods => const ['Close', 'CloseWithError', 'Read'];
  @override
  PipeReader $copy() => PipeReader._(_p);
  @override
  void $set(PipeReader o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  /// `Read(data)` síncrono: só com o pipe já fechado.
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> data) {
    if (_p._isDone) return (Golang.Int(0), _p._readCloseError());
    syncOfAsync('PipeReader.Read');
  }

  /// `Read(data)`: espera um `Write` (ou o fechamento).
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> data) =>
      _p.read(data);

  /// `Close()`: `Write` passa a falhar com `ErrClosedPipe`.
  @override
  GoError? close() => closeWithError(null);

  /// `CloseWithError(err)`: `Write` passa a falhar com err.
  GoError? closeWithError(GoError? err) => _p.closeRead(err);
}

/// `io.PipeWriter`.
final class PipeWriter extends GoStruct<PipeWriter>
    with CloserSync
    implements WriteCloser {
  PipeWriter._(this._p);

  /// `(*PipeWriter)(nil)` dentro de uma interface.
  static final PipeWriter $nil = PipeWriter._(_Pipe())..$nilPtr = true;

  final _Pipe _p;

  @override
  String get $goType => 'io.PipeWriter';
  @override
  List<String> get $ptrMethods => const ['Close', 'CloseWithError', 'Write'];
  @override
  PipeWriter $copy() => PipeWriter._(_p);
  @override
  void $set(PipeWriter o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  /// `Write(data)` síncrono: só com o pipe já fechado.
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> data) {
    if (_p._isDone) return (Golang.Int(0), _p._writeCloseError());
    syncOfAsync('PipeWriter.Write');
  }

  /// `Write(data)`: espera os `Read` consumirem tudo (ou o fechamento).
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> data) =>
      _p.write(data);

  /// `Close()`: `Read` passa a devolver `EOF`.
  @override
  GoError? close() => closeWithError(null);

  /// `CloseWithError(err)`: `Read` passa a devolver err.
  GoError? closeWithError(GoError? err) => _p.closeWrite(err);
}

/// `io.Pipe()`: pipe síncrono em memória.
(PipeReader?, PipeWriter?) pipe() {
  final p = _Pipe();
  return (PipeReader._(p), PipeWriter._(p));
}
