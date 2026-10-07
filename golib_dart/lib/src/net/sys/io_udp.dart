part of 'sys_io.dart';

Future<SysUdpConn> _listenUdp(SysAddr local) async {
  RawDatagramSocket s;
  Future<RawDatagramSocket> bind(InternetAddress a) =>
      // Sem SO_REUSEADDR (o padrão do `dart:io` é ligar): o Go só liga em
      // multicast, e com ele dois binds na mesma porta não dariam EADDRINUSE.
      RawDatagramSocket.bind(a, local.port, reuseAddress: false);
  try {
    if (local.ip.isEmpty) {
      try {
        s = await bind(InternetAddress.anyIPv6);
      } on SocketException catch (e) {
        final code = _errnoNames[e.osError?.errorCode ?? 0];
        if (code != 'EAFNOSUPPORT' && code != 'EADDRNOTAVAIL') rethrow;
        s = await bind(InternetAddress.anyIPv4);
      }
    } else {
      s = await bind(_inet(local.ip, local.zone));
    }
  } catch (e) {
    throw _mapBind(e, 'socket');
  }
  return _IoUdpConn(s);
}

/// UDP com o mesmo `PollDesc`/`FdMutex` do TCP (`internal/poll`).
final class _IoUdpConn implements SysUdpConn, SysSockopts {
  _IoUdpConn(this._socket)
    : _pd = PollDesc.datagram(_socket),
      local = _addrOf(_socket.address, _socket.port),
      _v6 = _socket.address.type == InternetAddressType.IPv6;

  final RawDatagramSocket _socket;
  final PollDesc _pd;
  final _mu = FdMutex();
  final bool _v6;

  @override
  final SysAddr local;

  @override
  Future<(int, SysAddr)> readFrom(Uint8List buf) => heldIo(() async {
    if (!await _mu.rwlock(true)) throw const SysClosed();
    try {
      while (true) {
        if (_mu.isClosed) throw const SysClosed();
        if (_pd.readExpired) throw const SysTimeout();
        if (_pd.readable) {
          final Datagram? d;
          try {
            d = _socket.receive();
          } catch (e) {
            throw _mapIo(e, 'recvfrom');
          }
          if (d != null) {
            final n = d.data.length < buf.length ? d.data.length : buf.length;
            buf.setRange(0, n, d.data);
            return (n, _addrOf(d.address, d.port));
          }
          _pd.readable = false;
        }
        final err = _pd.ioError;
        if (err != null) throw _mapIo(err, 'recvfrom');
        if (_pd.evicted) throw const SysClosed();
        await _pd.waitRead();
      }
    } finally {
      _mu.rwunlock(true);
    }
  });

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => heldIo(() async {
    if (!await _mu.rwlock(false)) throw const SysClosed();
    try {
      // IPv4 num socket IPv6 vai mapeado; mapeado num socket IPv4, puro.
      final ip = _v6 ? ipTo16(to.ip) : (ipTo4(to.ip) ?? to.ip);
      final dest = _inet(ip, to.zone);
      while (true) {
        if (_mu.isClosed) throw const SysClosed();
        if (_pd.writeExpired) throw const SysTimeout();
        final err = _pd.ioError;
        if (err != null) throw _mapIo(err, 'sendto');
        final int n;
        try {
          n = _socket.send(data, dest, to.port);
        } catch (e) {
          throw _mapIo(e, 'sendto');
        }
        // ⚠️ `send` devolve 0 tanto para "buffer cheio" quanto para o
        // datagrama vazio; o vazio não é reenviado.
        if (n > 0 || data.isEmpty) return data.length;
        if (_pd.evicted) throw const SysClosed();
        await _pd.waitWrite();
      }
    } finally {
      _mu.rwunlock(false);
    }
  });

  @override
  int rawSetsockopt(int level, int opt, Uint8List value) => _mu.isClosed
      ? -sf.EBADF
      : _ioSetsockopt(_socket.setRawOption, level, opt, value);

  @override
  int rawGetsockopt(int level, int opt, Uint8List out) => _mu.isClosed
      ? -sf.EBADF
      : _ioGetsockopt(_socket.getRawOption, level, opt, out);

  @override
  void close() {
    if (!_mu.close()) return;
    _pd.evict();
    unawaited(_pd.close());
    _socket.close();
  }

  @override
  set readDeadline(DateTime? d) => _pd.setReadDeadline(d);

  @override
  set writeDeadline(DateTime? d) => _pd.setWriteDeadline(d);
}
