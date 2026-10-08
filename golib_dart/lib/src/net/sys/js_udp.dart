part of 'sys_js.dart';

/// ⚠️ Datagramas recebidos e ainda não lidos: o Node empurra `message` sem
/// contrapressão; acima disto, descarta (como um buffer de socket cheio).
const _maxQueuedDatagrams = 4096;

/// `DialUDP`: socket em [local] com `dgram.connect` para [remote] (o
/// `LocalAddr` sai do `connect`, o kernel filtra o par e o ICMP volta).
Future<SysUdpConn> _dialUdp(SysAddr local, SysAddr remote) async {
  final c = await _bindUdp(
    local.ip.length == 4 ? 'udp4' : 'udp6',
    _host(local.ip, local.zone),
    local.port,
    false,
    remote: remote,
  );
  final ip = c._v6 ? ipTo16(remote.ip) : (ipTo4(remote.ip) ?? remote.ip);
  final done = Completer<JSAny?>();
  try {
    c._s.callMethod<JSAny?>(
      'connect'.toJS,
      remote.port.toJS,
      _host(ip, remote.zone).toJS,
      (([JSAny? e]) => done.complete(e)).toJS,
    );
  } catch (e) {
    c.close();
    throw SysError('connect', 'EOTHER', '$e');
  }
  final err = await done.future;
  if (err != null) {
    c.close();
    throw _mapNode(err, 'connect');
  }
  final a = c._s.callMethod<JSObject>('address'.toJS);
  c.local = _addr(a['address'], a['port']);
  return c;
}

Future<SysUdpConn> _listenUdp(SysAddr local, bool v6Only) async {
  // `listenDatagram`: grupo multicast escuta no não especificado da
  // família, com `SO_REUSEADDR`.
  if (local.ip.isNotEmpty && _isMulticast(local.ip)) {
    final v4 = ipTo4(local.ip) != null;
    return _bindUdp(
      v4 ? 'udp4' : 'udp6',
      v4 ? '0.0.0.0' : '::',
      local.port,
      v6Only,
      reuseAddr: true,
    );
  }
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
  bool v6Only, {
  SysAddr? remote,
  bool reuseAddr = false,
}) async {
  final opts = <String, JSAny?>{'type': type.toJS, 'reuseAddr': reuseAddr.toJS};
  if (v6Only) opts['ipv6Only'] = true.toJS;
  final s = _dgram.callMethod<JSObject>('createSocket'.toJS, _obj(opts));
  final c = remote == null
      ? _NodeUdpConn(s, type == 'udp6')
      : _NodeUdpConnected(s, type == 'udp6', remote);
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

final class _NodeUdpConn implements SysUdpConn, SysMulticastOpts {
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
  Future<(int, SysAddr)> readFrom(Uint8List buf) async {
    final (n, _, from) = await _recv(buf, 'recvfrom');
    return (n, from);
  }

  /// Um datagrama: (copiado, tamanho inteiro, origem). O erro guardado do
  /// evento `error` sai aqui com [syscall].
  Future<(int, int, SysAddr)> _recv(Uint8List buf, String syscall) =>
      heldIo(() async {
        if (!await _mu.rwlock(true)) throw const SysClosed();
        try {
          while (true) {
            if (_closed) throw const SysClosed();
            if (_rd.expired) throw const SysTimeout();
            if (_queue.isNotEmpty) {
              final (data, from) = _queue.removeFirst();
              final n = data.length < buf.length ? data.length : buf.length;
              buf.setRange(0, n, data);
              return (n, data.length, from);
            }
            final err = _error;
            if (err != null) {
              _error = null;
              throw _mapNode(err, syscall);
            }
            await _readers.wait();
          }
        } finally {
          _mu.rwunlock(true);
        }
      });

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => _send(data, to, 'sendto');

  /// Um datagrama para [to] (`null`: o par do socket conectado).
  Future<int> _send(Uint8List data, SysAddr? to, String syscall) =>
      heldIo(() async {
        if (!await _mu.rwlock(false)) throw const SysClosed();
        try {
          if (_closed) throw const SysClosed();
          if (_wd.expired) throw const SysTimeout();
          // IPv4 num socket IPv6 vai mapeado; mapeado num socket IPv4, puro.
          var finished = false;
          JSAny? failure;
          final cb = ((JSAny? e) {
            finished = true;
            failure = e;
            _writers.wakeAll();
          }).toJS;
          final bytes = Uint8List.fromList(data).toJS;
          if (to == null) {
            _s.callMethod<JSAny?>('send'.toJS, bytes, cb);
          } else {
            final ip = _v6 ? ipTo16(to.ip) : (ipTo4(to.ip) ?? to.ip);
            _s.callMethod<JSAny?>(
              'send'.toJS,
              bytes,
              to.port.toJS,
              _host(ip, to.zone).toJS,
              cb,
            );
          }
          while (!finished) {
            if (_closed) throw const SysClosed();
            if (_wd.expired) throw const SysTimeout();
            await _writers.wait();
          }
          if (failure != null) throw _mapNode(failure, syscall);
          return data.length;
        } finally {
          _mu.rwunlock(false);
        }
      });

  @override
  int multicastSetsockopt(int level, int opt, Uint8List value) {
    if (_closed) return -9; // EBADF
    final bd = ByteData.sublistView(value);
    int at(int off) => bd.getInt32(off, Endian.little);
    // O endereço da interface de índice [i] (`::%nome` no IPv6), ou `null`.
    String? iface(int i, {required bool v6}) {
      for (final ifc in _interfacesSync()) {
        if (ifc.index != i) continue;
        if (v6) return '::%${ifc.name}';
        for (final (ip, _) in ifc.addrs) {
          final v4 = ipTo4(ip);
          if (v4 != null) return ipToSystemString(v4);
        }
      }
      return null;
    }

    String addr(int from, int len) =>
        ipToSystemString(Uint8List.sublistView(value, from, from + len));
    try {
      switch ((level, opt)) {
        case (0, 34) || (41, 19): // IP_MULTICAST_LOOP, IPV6_MULTICAST_LOOP
          _s.callMethod<JSAny?>('setMulticastLoopback'.toJS, (at(0) != 0).toJS);
        case (0, 32) ||
            (41, 17): // IP_MULTICAST_IF (ip_mreqn), IPV6_MULTICAST_IF
          final i = opt == 32 ? at(8) : at(0);
          final a = i == 0 ? null : iface(i, v6: level == 41);
          if (i != 0 && a == null) return -19; // ENODEV
          if (a != null) {
            _s.callMethod<JSAny?>('setMulticastInterface'.toJS, a.toJS);
          }
        case (0, 35) || (41, 20): // IP_ADD_MEMBERSHIP, IPV6_JOIN_GROUP
          final v6 = level == 41;
          final i = v6 ? at(16) : at(8);
          final a = i == 0 ? null : iface(i, v6: v6);
          if (i != 0 && a == null) return -19; // ENODEV
          final group = addr(0, v6 ? 16 : 4).toJS;
          if (a == null) {
            _s.callMethod<JSAny?>('addMembership'.toJS, group);
          } else {
            _s.callMethod<JSAny?>('addMembership'.toJS, group, a.toJS);
          }
        default:
          return -92; // ENOPROTOOPT
      }
      return 0;
    } catch (e) {
      // O Node lança `Error: addMembership EINVAL`: o errno vem do texto.
      final code = RegExp(r'\bE[A-Z0-9]+\b').firstMatch('$e')?.group(0);
      return -(SysError('setsockopt', code ?? 'EINVAL', '').errno ?? 22);
    }
  }

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

/// Socket com `dgram.connect` (`DialUDP`): `Read`/`Write` do Go. O
/// `ECONNREFUSED` do ICMP chega como evento `error` e fica guardado, como o
/// erro pendente do socket no linux, para a próxima leitura ou escrita.
final class _NodeUdpConnected extends _NodeUdpConn implements SysUdpMsg {
  _NodeUdpConnected(super._s, super._v6, this.remote);

  @override
  final SysAddr remote;

  @override
  int get family => _v6 ? sysAfInet6 : sysAfInet;

  @override
  Future<int> recv(Uint8List buf) async => (await _recv(buf, 'read')).$1;

  @override
  Future<int> send(Uint8List data) {
    final err = _error;
    if (err != null) {
      _error = null;
      return Future.error(_mapNode(err, 'write'));
    }
    return _send(data, null, 'write');
  }

  @override
  Future<(int, int, int, SysAddr?)> readMsg(
    Uint8List buf,
    Uint8List oob,
  ) async {
    final (n, size, from) = await _recv(buf, 'recvmsg');
    return (n, 0, size > n ? 0x20 : 0, from); // MSG_TRUNC
  }

  @override
  Future<(int, int)> writeMsg(
    Uint8List data,
    Uint8List oob,
    SysAddr? to,
  ) async {
    // ⚠️ sem dados de controle no Node.
    if (oob.isNotEmpty) throw SysError.unsupported('sendmsg');
    return (await _send(data, to, 'sendmsg'), 0);
  }
}

bool _isMulticast(Uint8List ip) {
  final v4 = ipTo4(ip);
  return v4 != null ? v4[0] & 0xf0 == 0xe0 : ip.length == 16 && ip[0] == 0xff;
}
