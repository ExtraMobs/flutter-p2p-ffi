part of 'sys_js.dart';

// Listener TCP sobre `net.Server` (`pauseOnConnect`: a conexão não lê nada
// até ser aceita).

Future<SysTcpListener> _listenTcp(
  SysAddr local,
  int backlog,
  bool v6Only,
) async {
  final server = _net.callMethod<JSObject>(
    'createServer'.toJS,
    _obj({'allowHalfOpen': true.toJS, 'pauseOnConnect': true.toJS}),
  );
  final l = _NodeTcpListener(server);
  final opts = <String, JSAny?>{
    'port': local.port.toJS,
    'backlog': backlog.toJS,
    'exclusive': true.toJS,
  };
  // Sem host, o Node escuta em `::` dual-stack, ou `0.0.0.0` sem IPv6.
  if (local.ip.isNotEmpty) opts['host'] = _host(local.ip, local.zone).toJS;
  if (v6Only) opts['ipv6Only'] = true.toJS;
  final ready = Completer<JSAny?>();
  l._onListenError = (e) {
    if (!ready.isCompleted) ready.complete(e ?? 'error'.toJS);
  };
  server.callMethod<JSAny?>(
    'listen'.toJS,
    _obj(opts),
    (() {
      if (!ready.isCompleted) ready.complete(null);
    }).toJS,
  );
  final err = await ready.future;
  l._onListenError = null;
  if (err != null) {
    server.callMethod<JSAny?>('close'.toJS);
    throw _mapNodeBind(err, 'listen');
  }
  final a = server.callMethod<JSObject>('address'.toJS);
  l.local = _addr(a['address'], a['port']);
  return l;
}

final class _NodeTcpListener implements SysTcpListener {
  _NodeTcpListener(this._server) {
    _on(
      _server,
      'connection',
      ((JSObject s) {
        if (_closed) {
          s.callMethod<JSAny?>('destroy'.toJS);
          return;
        }
        // Erro antes do accept não pode derrubar o processo.
        _on(s, 'error', ((JSAny? _) {}).toJS);
        _ready.add(s);
        _waiters.wakeAll();
      }).toJS,
    );
    _on(
      _server,
      'error',
      ((JSAny? e) {
        final f = _onListenError;
        if (f != null) return f(e);
        _error = e;
        _waiters.wakeAll();
      }).toJS,
    );
  }

  final JSObject _server;
  final _ready = Queue<JSObject>();
  final _waiters = Waiters();
  late final _deadline = Deadline(_waiters.wakeAll);
  bool _closed = false;
  JSAny? _error;
  void Function(JSAny?)? _onListenError;

  @override
  SysAddr local = SysAddr(Uint8List(0), 0);

  @override
  Future<SysTcpConn> accept() => heldIo(() async {
    while (true) {
      if (_closed) throw const SysClosed();
      if (_deadline.expired) throw const SysTimeout();
      if (_ready.isNotEmpty) return _NodeTcpConn(_ready.removeFirst());
      final err = _error;
      if (err != null) {
        _error = null;
        throw _mapNode(err, 'accept');
      }
      await _waiters.wait();
    }
  });

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _deadline.cancel();
    _server.callMethod<JSAny?>('close'.toJS);
    while (_ready.isNotEmpty) {
      _ready.removeFirst().callMethod<JSAny?>('destroy'.toJS);
    }
    _waiters.wakeAll();
  }

  @override
  set deadline(DateTime? d) => _deadline.set(d);
}
