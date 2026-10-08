part of '../../net.dart';

// `net.Pipe`: porta de `net/pipe.go` do Go 1.26 sobre `Chan`/`select` do
// runtime, como o `io.Pipe` (`src/io/pipe.dart`). `Read`/`Write` suspendem:
// o valor só circula como `net.Conn`, cujo `Read`/`Write` é dual
// (`g2d/services/dualio.py`); a forma síncrona é o `fatal` `g2d:` de
// [syncOfAsync]. O `sync.Mutex` do deadline some (um isolate só).

typedef _Done = Chan<EmptyStruct>;

_Done _newDone() => Chan<EmptyStruct>(0, EmptyStruct());

/// `isClosedChan(c)`.
bool _isClosedChan(_Done c) => selectNow([RecvCase(c)]).$1 == 0;

void _closeOnce(_Done c) {
  if (!_isClosedChan(c)) c.close();
}

/// `pipeDeadline`: o canal `cancel` fecha quando o prazo estoura.
final class _PipeDeadline {
  time.Timer? _timer;
  _Done _cancel = _newDone();

  /// `set(t)`: zero desliga; no futuro arma um timer; no passado fecha já.
  void set(time.Time t) {
    // O Go espera o callback fechar `cancel` quando o `Stop` chega tarde; o
    // callback pode ainda não ter rodado (goroutine nova), então fecha aqui.
    if (_timer != null && !_timer!.stop()) _closeOnce(_cancel);
    _timer = null;

    final closed = _isClosedChan(_cancel);
    if (t.isZero()) {
      if (closed) _cancel = _newDone();
      return;
    }

    final dur = time.until(t);
    if (dur > time.Duration()) {
      if (closed) _cancel = _newDone();
      final c = _cancel;
      _timer = time.afterFunc(dur, () => _closeOnce(c));
      return;
    }

    if (!closed) _cancel.close();
  }

  /// `wait()`.
  _Done wait() => _cancel;
}

/// `pipeAddr{}` (valor na interface: `$isValue`): `Network()` e `String()`
/// são `"pipe"`.
final class _PipeAddr extends GoStruct<_PipeAddr> implements Addr {
  @override
  String get $goType => 'net.pipeAddr';
  @override
  List<String> get $valueMethods => const ['Network', 'String'];
  @override
  _PipeAddr $copy() => _PipeAddr();
  @override
  void $set(_PipeAddr o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  @override
  Golang.String network() => _gs('pipe');
  @override
  Golang.String string() => _gs('pipe');
}

/// `*net.pipe`: uma ponta do [pipe].
final class _NetPipe extends GoStruct<_NetPipe>
    with io.CloserSync
    implements Conn {
  _NetPipe(
    this._rdRx,
    this._rdTx,
    this._wrTx,
    this._wrRx,
    this._localDone,
    this._remoteDone,
  );

  final Chan<_Bytes> _rdRx;
  final Chan<int> _rdTx;
  final Chan<_Bytes> _wrTx;
  final Chan<int> _wrRx;
  final _wrMu = sync.Mutex();
  final _Done _localDone;
  final _Done _remoteDone;
  final _readDeadline = _PipeDeadline();
  final _writeDeadline = _PipeDeadline();

  @override
  String get $goType => 'net.pipe';
  @override
  List<String> get $ptrMethods => const [
    'Close',
    'LocalAddr',
    'Read',
    'RemoteAddr',
    'SetDeadline',
    'SetReadDeadline',
    'SetWriteDeadline',
    'Write',
  ];
  @override
  _NetPipe $copy() => this;
  @override
  void $set(_NetPipe o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  @override
  Addr? localAddr() => _PipeAddr()..$isValue = true;
  @override
  Addr? remoteAddr() => _PipeAddr()..$isValue = true;

  @override
  (Golang.Int, GoError?) read(_Bytes b) => syncOfAsync('net.pipe.Read');

  /// `Read(b)`: o erro que não é `EOF`/`ErrClosedPipe` vem em `*OpError`.
  @override
  Future<(Golang.Int, GoError?)> read$async(_Bytes b) async {
    final (n, err) = await _read(b);
    if (err != null &&
        !identical(err, io.eof) &&
        !identical(err, io.errClosedPipe)) {
      return (Golang.Int(n), _opError('read', 'pipe', null, null, err));
    }
    return (Golang.Int(n), err);
  }

  Future<(int, GoError?)> _read(_Bytes b) async {
    if (_isClosedChan(_localDone)) return (0, io.errClosedPipe);
    if (_isClosedChan(_remoteDone)) return (0, io.eof);
    if (_isClosedChan(_readDeadline.wait())) {
      return (0, os.errDeadlineExceeded);
    }
    final (i, bw, _) = await select([
      RecvCase(_rdRx),
      RecvCase(_localDone),
      RecvCase(_remoteDone),
      RecvCase(_readDeadline.wait()),
    ]);
    switch (i) {
      case 0:
        final nr = b.copyFrom(bw as _Bytes);
        await _rdTx.send(nr);
        return (nr, null);
      case 1:
        return (0, io.errClosedPipe);
      case 2:
        return (0, io.eof);
      default:
        return (0, os.errDeadlineExceeded);
    }
  }

  @override
  (Golang.Int, GoError?) write(_Bytes b) => syncOfAsync('net.pipe.Write');

  /// `Write(b)`: só `ErrClosedPipe` vem sem `*OpError`.
  @override
  Future<(Golang.Int, GoError?)> write$async(_Bytes b) async {
    final (n, err) = await _write(b);
    if (err != null && !identical(err, io.errClosedPipe)) {
      return (Golang.Int(n), _opError('write', 'pipe', null, null, err));
    }
    return (Golang.Int(n), err);
  }

  Future<(int, GoError?)> _write(_Bytes b) async {
    if (_isClosedChan(_localDone) || _isClosedChan(_remoteDone)) {
      return (0, io.errClosedPipe);
    }
    if (_isClosedChan(_writeDeadline.wait())) {
      return (0, os.errDeadlineExceeded);
    }
    await _wrMu.lock$async(); // o b inteiro sai junto
    try {
      var n = 0;
      for (var once = true; once || b.length > 0; once = false) {
        final (i, _, _) = await select([
          SendCase(_wrTx, b),
          RecvCase(_localDone),
          RecvCase(_remoteDone),
          RecvCase(_writeDeadline.wait()),
        ]);
        switch (i) {
          case 0:
            final nw = await _wrRx.recv();
            b = b.slice(nw);
            n += nw;
          case 1 || 2:
            return (n, io.errClosedPipe);
          default:
            return (n, os.errDeadlineExceeded);
        }
      }
      return (n, null);
    } finally {
      _wrMu.unlock();
    }
  }

  GoError? _setDeadlines(time.Time t, {bool read = true, bool write = true}) {
    if (_isClosedChan(_localDone) || _isClosedChan(_remoteDone)) {
      return io.errClosedPipe;
    }
    if (read) _readDeadline.set(t);
    if (write) _writeDeadline.set(t);
    return null;
  }

  @override
  GoError? setDeadline(time.Time t) => _setDeadlines(t);
  @override
  GoError? setReadDeadline(time.Time t) => _setDeadlines(t, write: false);
  @override
  GoError? setWriteDeadline(time.Time t) => _setDeadlines(t, read: false);

  /// `Close()`: o outro lado lê `EOF`; este passa a dar `ErrClosedPipe`.
  @override
  GoError? close() {
    _closeOnce(_localDone);
    return null;
  }
}

/// `net.Pipe()`: conexão síncrona em memória, full duplex; cada `Read` de
/// uma ponta casa com um `Write` da outra, sem buffer.
(Conn?, Conn?) pipe() {
  final cb1 = Chan<_Bytes>(0, Slice.nil(_byteElem));
  final cb2 = Chan<_Bytes>(0, Slice.nil(_byteElem));
  final cn1 = Chan<int>(0, 0);
  final cn2 = Chan<int>(0, 0);
  final done1 = _newDone(), done2 = _newDone();
  return (
    _NetPipe(cb1, cn1, cb2, cn2, done1, done2),
    _NetPipe(cb2, cn2, cb1, cn1, done2, done1),
  );
}
