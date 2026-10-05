part of 'sys_js.dart';

/// ⚠️ Datagramas recebidos e ainda não lidos: o Node empurra `message` sem
/// contrapressão; acima disto, descarta (como um buffer de socket cheio).
const _maxQueuedDatagrams = 4096;

Future<SysUdpConn> _listenUdp(SysAddr local, bool v6Only) async {
  if (local.ip.isEmpty) {
    try {
      return await _bindUdp('udp6', '::', local.port, v6Only);
    } on SysError catch (e) {
      // Sem IPv6: `udp4` em `0.0.0.0`, como o Go.
      if (e.code != 'EAFNOSUPPORT' && e.code != 'EADDRNOTAVAIL') rethrow;
      return _bindUdp('udp4', '0.0.0.0', local.port, false);
    }
  }
  final v4 = local.ip.length == 4;
  return _bindUdp(
    v4 ? 'udp4' : 'udp6',
    _host(local.ip, local.zone),
    local.port,
    v6Only,
  );
}

Future<_NodeUdpConn> _bindUdp(
  String type,
  String host,
  int port,
  bool v6Only,
) async {
  final opts = <String, JSAny?>{'type': type.toJS, 'reuseAddr': false.toJS};
  if (v6Only) opts['ipv6Only'] = true.toJS;
  final s = _dgram.callMethod<JSObject>('createSocket'.toJS, _obj(opts));
  final c = _NodeUdpConn(s, type == 'udp6');
  final ready = Completer<JSAny?>();
  c._onBindError = (e) {
    if (!ready.isCompleted) ready.complete(e ?? 'error'.toJS);
  };
  s.callMethod<JSAny?>(
    'bind'.toJS,
    _obj({'port': port.toJS, 'address': host.toJS, 'exclusive': true.toJS}),
    (() {
      if (!ready.isCompleted) ready.complete(null);
    }).toJS,
  );
  final err = await ready.future;
  c._onBindError = null;
  if (err != null) {
    try {
      s.callMethod<JSAny?>('close'.toJS);
    } catch (_) {}
    throw _mapNodeBind(err, 'socket');
  }
  final a = s.callMethod<JSObject>('address'.toJS);
  c.local = _addr(a['address'], a['port']);
  return c;
}

final class _NodeUdpConn implements SysUdpConn {
  _NodeUdpConn(this._s, this._v6) {
    _on(
      _s,
      'message',
      ((JSAny? msg, JSObject rinfo) {
        if (_closed || _queue.length >= _maxQueuedDatagrams) return;
        _queue.add((_bytes(msg), _addr(rinfo['address'], rinfo['port'])));
        _readers.wakeAll();
      }).toJS,
    );
    _on(
      _s,
      'error',
      ((JSAny? e) {
        final f = _onBindError;
        if (f != null) return f(e);
        _error = e;
        _readers.wakeAll();
      }).toJS,
    );
  }

  final JSObject _s;
  final bool _v6;
  final _mu = FdMutex();
  final _queue = Queue<(Uint8List, SysAddr)>();
  final _readers = Waiters();
  final _writers = Waiters();
  late final _rd = Deadline(_readers.wakeAll);
  late final _wd = Deadline(_writers.wakeAll);
  bool _closed = false;
  JSAny? _error;
  void Function(JSAny?)? _onBindError;

  @override
  SysAddr local = SysAddr(Uint8List(0), 0);

  @override
  Future<(int, SysAddr)> readFrom(Uint8List buf) => heldIo(() async {
    if (!await _mu.rwlock(true)) throw const SysClosed();
    try {
      while (true) {
        if (_closed) throw const SysClosed();
        if (_rd.expired) throw const SysTimeout();
        if (_queue.isNotEmpty) {
          final (data, from) = _queue.removeFirst();
          final n = data.length < buf.length ? data.length : buf.length;
          buf.setRange(0, n, data);
          return (n, from);
        }
        final err = _error;
        if (err != null) {
          _error = null;
          throw _mapNode(err, 'recvfrom');
        }
        await _readers.wait();
      }
    } finally {
      _mu.rwunlock(true);
    }
  });

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => heldIo(() async {
    if (!await _mu.rwlock(false)) throw const SysClosed();
    try {
      if (_closed) throw const SysClosed();
      if (_wd.expired) throw const SysTimeout();
      // IPv4 num socket IPv6 vai mapeado; mapeado num socket IPv4, puro.
      final ip = _v6 ? ipTo16(to.ip) : (ipTo4(to.ip) ?? to.ip);
      var finished = false;
      JSAny? failure;
      _s.callMethod<JSAny?>(
        'send'.toJS,
        Uint8List.fromList(data).toJS,
        to.port.toJS,
        _host(ip, to.zone).toJS,
        ((JSAny? e) {
          finished = true;
          failure = e;
          _writers.wakeAll();
        }).toJS,
      );
      while (!finished) {
        if (_closed) throw const SysClosed();
        if (_wd.expired) throw const SysTimeout();
        await _writers.wait();
      }
      if (failure != null) throw _mapNode(failure, 'sendto');
      return data.length;
    } finally {
      _mu.rwunlock(false);
    }
  });

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _mu.close();
    _rd.cancel();
    _wd.cancel();
    _queue.clear();
    try {
      _s.callMethod<JSAny?>('close'.toJS);
    } catch (_) {}
    _readers.wakeAll();
    _writers.wakeAll();
  }

  @override
  set readDeadline(DateTime? d) => _rd.set(d);

  @override
  set writeDeadline(DateTime? d) => _wd.set(d);
}
