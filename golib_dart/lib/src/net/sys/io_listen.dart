part of 'sys_io.dart';

// Listener TCP: fila de conexões aceitas pelo `RawServerSocket`, com prazo
// e contrapressão (pausa acima do backlog).

Future<SysTcpListener> _listenTcp(
  SysAddr local,
  int backlog,
  bool v6Only,
) async {
  RawServerSocket srv;
  try {
    if (local.ip.isEmpty) {
      try {
        srv = await RawServerSocket.bind(
          InternetAddress.anyIPv6,
          local.port,
          backlog: backlog,
        );
      } on SocketException catch (e) {
        // Sem IPv6 (EAFNOSUPPORT/EADDRNOTAVAIL): `0.0.0.0`, como o
        // `favoriteAddrFamily` do Go.
        final code = _errnoNames[e.osError?.errorCode ?? 0];
        if (code != 'EAFNOSUPPORT' && code != 'EADDRNOTAVAIL') rethrow;
        srv = await RawServerSocket.bind(
          InternetAddress.anyIPv4,
          local.port,
          backlog: backlog,
        );
      }
    } else {
      srv = await RawServerSocket.bind(
        _inet(local.ip, local.zone),
        local.port,
        backlog: backlog,
        v6Only: v6Only,
      );
    }
  } catch (e) {
    throw _mapBind(e, 'listen');
  }
  return _IoTcpListener(srv, backlog <= 0 ? 128 : backlog);
}

final class _IoTcpListener implements SysTcpListener {
  _IoTcpListener(this._srv, this._backlog)
    : local = _addrOf(_srv.address, _srv.port) {
    _sub = _srv.listen(
      (s) {
        _ready.add(s);
        // Fila cheia: para de aceitar (o backlog do kernel segura o resto).
        if (_ready.length >= _backlog) _sub.pause();
        _waiters.wakeAll();
      },
      onError: (Object e) {
        _error = e;
        _waiters.wakeAll();
      },
    );
  }

  final RawServerSocket _srv;
  final int _backlog;
  late final StreamSubscription<RawSocket> _sub;
  final _ready = Queue<RawSocket>();
  final _waiters = Waiters();
  late final _deadline = Deadline(_waiters.wakeAll);
  bool _closed = false;
  Object? _error;

  @override
  final SysAddr local;

  @override
  Future<SysTcpConn> accept() => heldIo(() async {
    while (true) {
      if (_closed) throw const SysClosed();
      if (_deadline.expired) throw const SysTimeout();
      if (_ready.isNotEmpty) {
        final s = _ready.removeFirst();
        if (_sub.isPaused && _ready.length < _backlog) _sub.resume();
        try {
          return await _IoTcpConn.create(s, local.ip);
        } on SocketException {
          // O par já desistiu antes do accept: o Go também pula essa.
          unawaited(s.close());
          continue;
        }
      }
      final err = _error;
      if (err != null) {
        _error = null;
        throw _mapIo(err, 'accept');
      }
      await _waiters.wait();
    }
  });

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _deadline.cancel();
    unawaited(_sub.cancel());
    unawaited(_srv.close());
    while (_ready.isNotEmpty) {
      unawaited(_ready.removeFirst().close());
    }
    _waiters.wakeAll();
  }

  @override
  set deadline(DateTime? d) => _deadline.set(d);
}
