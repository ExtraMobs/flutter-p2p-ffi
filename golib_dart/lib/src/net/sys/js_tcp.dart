part of 'sys_js.dart';

Future<SysTcpConn> _dialTcp(
  SysAddr remote,
  SysAddr? local,
  DateTime? deadline,
  Future<void>? cancel,
) async {
  if (deadline != null && !deadline.isAfter(DateTime.now())) {
    throw const SysTimeout();
  }
  final opts = <String, JSAny?>{
    'host': _host(remote.ip, remote.zone).toJS,
    'port': remote.port.toJS,
    // Meia-conexão do Go: o EOF do par não fecha a nossa escrita.
    'allowHalfOpen': true.toJS,
  };
  if (local != null && local.ip.isNotEmpty) {
    opts['localAddress'] = _host(local.ip, local.zone).toJS;
  }
  if (local != null && local.port != 0) opts['localPort'] = local.port.toJS;
  final JSObject s;
  try {
    s = _net.callMethod<JSObject>('createConnection'.toJS, _obj(opts));
  } catch (e) {
    throw SysError('connect', 'EOTHER', '$e');
  }
  final done = Completer<JSAny?>();
  _on(
    s,
    'connect',
    (() {
      if (!done.isCompleted) done.complete(null);
    }).toJS,
  );
  _on(
    s,
    'error',
    ((JSAny? e) {
      if (!done.isCompleted) done.complete(e ?? 'error'.toJS);
    }).toJS,
  );
  var aborted = 0; // 1: prazo; 2: cancelado.
  void abort(int why) {
    if (done.isCompleted) return;
    aborted = why;
    s.callMethod<JSAny?>('destroy'.toJS);
    done.complete(null);
  }

  final timer = deadline == null ? null : Deadline(() => abort(1));
  timer?.set(deadline);
  unawaited(cancel?.then((_) => abort(2)));
  final err = await done.future;
  timer?.cancel();
  if (aborted == 1) throw const SysTimeout();
  if (aborted == 2) throw const SysCanceled();
  if (err != null) {
    s.callMethod<JSAny?>('destroy'.toJS);
    throw _mapNodeBind(err, 'connect');
  }
  return _NodeTcpConn(s);
}

/// Pedaço máximo por `socket.write`: a escrita interrompida (prazo, close)
/// sabe quantos pedaços inteiros o Node já entregou ao SO.
const _writeChunk = 64 * 1024;

/// Acima disto em buffer não lido, `pause()` (contrapressão para o par).
const _highWater = 256 * 1024;

/// Conexão TCP sobre um `net.Socket` do Node, com a leitura em fila
/// própria (o Node empurra `data`; o Go puxa com `Read`).
final class _NodeTcpConn implements SysTcpConn {
  _NodeTcpConn(this._s)
    : local = _addr(_s['localAddress'], _s['localPort']),
      remote = _addr(_s['remoteAddress'], _s['remotePort']) {
    _on(
      _s,
      'data',
      ((JSAny? chunk) {
        if (_readShut || _closed) return;
        final b = _bytes(chunk);
        if (b.isEmpty) return;
        _chunks.add(b);
        _buffered += b.length;
        if (_buffered >= _highWater && !_paused) {
          _paused = true;
          _s.callMethod<JSAny?>('pause'.toJS);
        }
        _readers.wakeAll();
      }).toJS,
    );
    _on(
      _s,
      'end',
      (() {
        _eof = true;
        _readers.wakeAll();
      }).toJS,
    );
    _on(
      _s,
      'error',
      ((JSAny? e) {
        _error ??= e ?? 'error'.toJS;
        _readers.wakeAll();
        _writers.wakeAll();
      }).toJS,
    );
    _on(
      _s,
      'close',
      (() {
        _eof = true;
        _readers.wakeAll();
        _writers.wakeAll();
      }).toJS,
    );
    // Conexões aceitas nascem pausadas (`pauseOnConnect`).
    _s.callMethod<JSAny?>('resume'.toJS);
  }

  final JSObject _s;
  final _mu = FdMutex();
  final _chunks = Queue<Uint8List>();
  int _buffered = 0;
  bool _paused = false;
  bool _eof = false;
  bool _readShut = false;

  /// Erro de leitura já entregue (ver [read]).
  bool _readErrDone = false;
  bool _closed = false;
  bool _keepAlive = false;
  int _keepAliveIdleMs = 0;
  bool _lingerReset = false;
  JSAny? _error;
  final _readers = Waiters();
  final _writers = Waiters();
  late final _rd = Deadline(_readers.wakeAll);
  late final _wd = Deadline(_writers.wakeAll);

  @override
  final SysAddr local;

  @override
  final SysAddr remote;

  @override
  Future<int> read(Uint8List buf) async {
    if (buf.isEmpty) return 0;
    return heldIo(() async {
      if (!await _mu.rwlock(true)) throw const SysClosed();
      try {
        while (true) {
          if (_closed) throw const SysClosed();
          if (_rd.expired) throw const SysTimeout();
          if (_readShut || _readErrDone) return 0;
          if (_chunks.isNotEmpty) return _take(buf);
          if (_error != null) {
            // O erro do socket (um `ECONNRESET`, por exemplo) vai uma vez
            // só: a leitura seguinte dá EOF, como no kernel e no Go.
            _readErrDone = true;
            throw _mapNode(_error, 'read');
          }
          if (_eof) return 0;
          await _readers.wait();
        }
      } finally {
        _mu.rwunlock(true);
      }
    });
  }

  int _take(Uint8List buf) {
    var n = 0;
    while (n < buf.length && _chunks.isNotEmpty) {
      final head = _chunks.first;
      final k = head.length <= buf.length - n ? head.length : buf.length - n;
      buf.setRange(n, n + k, head);
      n += k;
      if (k == head.length) {
        _chunks.removeFirst();
      } else {
        _chunks
          ..removeFirst()
          ..addFirst(Uint8List.sublistView(head, k));
      }
    }
    _buffered -= n;
    if (_paused && _buffered < _highWater ~/ 2) {
      _paused = false;
      _s.callMethod<JSAny?>('resume'.toJS);
    }
    return n;
  }

  @override
  Future<int> write(Uint8List data) async {
    if (data.isEmpty) return 0;
    return heldIo(() async {
      if (!await _mu.rwlock(false)) throw const SysClosed();
      var written = 0;
      try {
        while (written < data.length) {
          if (_closed) throw SysClosed(written);
          if (_wd.expired) throw SysTimeout(written);
          if (_error != null) throw _mapNode(_error, 'write', written: written);
          final end = written + _writeChunk < data.length
              ? written + _writeChunk
              : data.length;
          var finished = false;
          JSAny? failure;
          _s.callMethod<JSAny?>(
            'write'.toJS,
            Uint8List.fromList(Uint8List.sublistView(data, written, end)).toJS,
            ((JSAny? e) {
              finished = true;
              failure = e;
              _writers.wakeAll();
            }).toJS,
          );
          // ⚠️ Prazo ou close no meio: o pedaço em voo pode ainda sair (o
          // Node não desfaz um `write` aceito); `written` só conta pedaços
          // confirmados.
          while (!finished) {
            if (_closed) throw SysClosed(written);
            if (_wd.expired) throw SysTimeout(written);
            await _writers.wait();
          }
          if (failure != null) {
            throw _mapNode(_error ?? failure, 'write', written: written);
          }
          written = end;
        }
        return written;
      } finally {
        _mu.rwunlock(false);
      }
    });
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _mu.close();
    _rd.cancel();
    _wd.cancel();
    _chunks.clear();
    // `SetLinger(0)`: RST em vez de FIN (o par lê `connection reset by
    // peer`). `resetAndDestroy` existe no Node ≥ 18.3.
    if (_lingerReset && _s.has('resetAndDestroy')) {
      _s.callMethod<JSAny?>('resetAndDestroy'.toJS);
    } else {
      _s.callMethod<JSAny?>('destroy'.toJS);
    }
    _readers.wakeAll();
    _writers.wakeAll();
  }

  @override
  void closeWrite() {
    if (_closed) throw const SysClosed();
    _s.callMethod<JSAny?>('end'.toJS);
  }

  /// ⚠️ O Node não tem `shutdown(SHUT_RD)`: as leituras passam a dar EOF e o
  /// que o par mandar é descartado aqui (no linux o kernel faria o mesmo).
  @override
  void closeRead() {
    if (_closed) throw const SysClosed();
    _readShut = true;
    _chunks.clear();
    _buffered = 0;
    if (_paused) {
      _paused = false;
      _s.callMethod<JSAny?>('resume'.toJS);
    }
    _readers.wakeAll();
  }

  @override
  set readDeadline(DateTime? d) => _rd.set(d);

  @override
  set writeDeadline(DateTime? d) => _wd.set(d);

  @override
  void setNoDelay(bool v) {
    if (_closed) throw const SysClosed();
    _s.callMethod<JSAny?>('setNoDelay'.toJS, v.toJS);
  }

  @override
  void setKeepAlive(bool v) {
    if (_closed) throw const SysClosed();
    _keepAlive = v;
    _applyKeepAlive();
  }

  /// O Node só expõe `setKeepAlive(enable, initialDelay)`: o estado tem de
  /// ser lembrado aqui para que mudar um não desfaça o outro.
  void _applyKeepAlive() => _s.callMethod<JSAny?>(
    'setKeepAlive'.toJS,
    _keepAlive.toJS,
    _keepAliveIdleMs.toJS,
  );

  /// ⚠️ No Node só o tempo de ociosidade é ajustável (`initialDelay`), e
  /// ele só vale com o keepalive ligado.
  @override
  void setKeepAliveIdle(int secs) {
    if (_closed) throw const SysClosed();
    _keepAliveIdleMs = secs * 1000;
    _applyKeepAlive();
  }

  /// ⚠️ `TCP_KEEPINTVL` não existe no Node: aceito e ignorado.
  @override
  void setKeepAliveInterval(int secs) {
    if (_closed) throw const SysClosed();
  }

  /// ⚠️ `TCP_KEEPCNT` não existe no Node: aceito e ignorado.
  @override
  void setKeepAliveCount(int n) {
    if (_closed) throw const SysClosed();
  }

  /// `sec == 0` vira `resetAndDestroy()` no [close] (RST, como o
  /// `SO_LINGER` com prazo zero). ⚠️ `sec > 0` não tem equivalente no Node:
  /// aceito e ignorado (o `close` não espera).
  @override
  void setLinger(int sec) {
    if (_closed) throw const SysClosed();
    _lingerReset = sec == 0;
  }
}
