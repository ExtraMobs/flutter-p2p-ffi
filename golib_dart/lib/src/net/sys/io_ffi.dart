part of 'sys_io.dart';

// Rede FFI na VM (etapas E2–E7 do plano D10): o socket cru que o `net`
// monta na ordem do `socket()` do Go ([SysSocket]; o único `socket()` do
// shim é o `_goSocket` de `src/net/control.dart`), o listener de fluxo que
// fica no FFI (laço de `accept4`; cada conexão aceita vai para o `dart:io`
// pela ponte) e as opções de socket das conexões do `dart:io`
// ([SysSockopts]). Os sockets que ficam no FFI (Unix, IP bruto, UDP) viram
// um `FfiSock` (`ffi/sock.dart`), que também faz os `sockaddr` do Go.

/// Socket cru da libc (não bloqueante, `close-on-exec`). Sem rede FFI (VM
/// fora do linux), falha como o Go em js/wasm (F4).
SysSocket sysSocket(int family, int sotype, int proto) {
  if (!ffi.sysFfiAvailable) throw SysError.unsupported('socket');
  try {
    return _FfiSocket(ffi.FfiFd.socket(family, sotype, proto), family, sotype);
  } on ffi.FfiErrno catch (e) {
    throw _ffiError(e);
  }
}

/// Espera os `close` adiados (listener do `dart:io`, fd do FFI): o
/// `socket()` do Go vem depois de um `Close` síncrono.
Future<void> sysClosesSettled() async {
  if (_pendingCloses.isNotEmpty) await _closesSettled();
  if (ffi.sysFfiAvailable) await ffi.FfiFd.closesSettled();
}

/// O `ipStackCapabilities.probe` do Go (linux): IPv4 se um socket
/// `AF_INET` abre; IPv6 se um `AF_INET6` com `IPV6_V6ONLY=1` faz `bind` em
/// `::1`; IPv4 mapeado se um com `IPV6_V6ONLY=0` faz `bind` em
/// `::ffff:127.0.0.1`. Medido uma vez por isolate.
SysIpStack sysIpStack() => _ipStack ??= _probeIpStack();

SysIpStack? _ipStack;

SysIpStack _probeIpStack() {
  if (!ffi.sysFfiAvailable) {
    return const SysIpStack(ipv4: true, ipv6: false, ipv4MappedIPv6: false);
  }
  var v4 = false;
  final s = sf.socket(sf.AF_INET, sf.SOCK_STREAM | sf.SOCK_CLOEXEC, 6);
  if (s >= 0) {
    sf.close(s);
    v4 = true;
  }
  bool probe(Uint8List ip, int v6only) {
    final fd = sf.socket(sf.AF_INET6, sf.SOCK_STREAM | sf.SOCK_CLOEXEC, 6);
    if (fd < 0) return false;
    try {
      sf.setsockoptInt(fd, sf.IPPROTO_IPV6, sf.IPV6_V6ONLY, v6only);
      return _bindRaw(fd, sf.Sockaddr.inet(ip, 0)) == 0;
    } finally {
      sf.close(fd);
    }
  }

  return SysIpStack(
    ipv4: v4,
    ipv6: probe(Uint8List(16)..[15] = 1, 1),
    ipv4MappedIPv6: probe(ipTo16(Uint8List.fromList([127, 0, 0, 1])), 0),
  );
}

int _bindRaw(int fd, sf.Sockaddr a) {
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  try {
    final len = sf.encodeSockaddr(a, sa);
    if (len < 0) return len;
    return sf.bind(fd, sa, len);
  } finally {
    sf.libcAlloc.free(sa);
  }
}

/// errno cru → erro do motor.
SysError _ffiError(ffi.FfiErrno e) => SysError.errno(
  e.syscall,
  errnoNames[e.errno] ?? 'EOTHER',
  written: e.written,
);

/// Repassa as falhas do FFI como erros do motor (prazo e fechamento já são
/// do motor).
Future<T> _ffiIo<T>(Future<T> Function() op) async {
  try {
    return await op();
  } on ffi.FfiErrno catch (e) {
    throw _ffiError(e);
  }
}

/// `TCP_NODELAY` ligado, como o `newTCPConn` do Go (erro ignorado).
void _noDelay(int fd) => sf.setsockoptInt(fd, sf.IPPROTO_TCP, 1, 1);

final class _FfiSocket implements SysSocket {
  _FfiSocket(this._fd, this.family, this.sotype);

  final ffi.FfiFd _fd;

  @override
  final int family;

  @override
  final int sotype;

  /// O destino do [connect] feito, ou `null`.
  SysAddr? _connectedTo;

  @override
  int get rawFd => _fd.fd;

  @override
  bool get rawReadExpired => _fd.readExpired;

  @override
  bool get rawWriteExpired => _fd.writeExpired;

  @override
  Future<void> rawWaitRead() => _fd.waitRead();

  @override
  Future<void> rawWaitWrite() => _fd.waitWrite();

  @override
  int setsockoptInt(int level, int opt, int value) {
    if (_fd.isClosed) return -sf.EBADF;
    return sf.setsockoptInt(_fd.fd, level, opt, value);
  }

  @override
  void bind(SysAddr local) {
    if (_fd.isClosed) throw const SysClosed();
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    try {
      final len = ffi.ffiEncodeSockaddr(family, local, sa, 'bind');
      final r = sf.bind(_fd.fd, sa, len);
      if (r < 0) throw ffi.FfiErrno('bind', -r);
    } on ffi.FfiErrno catch (e) {
      throw _ffiError(e);
    } finally {
      sf.libcAlloc.free(sa);
    }
  }

  @override
  void listen(int backlog) {
    if (_fd.isClosed) throw const SysClosed();
    final r = sf.listen(_fd.fd, backlog);
    if (r < 0) throw _ffiError(ffi.FfiErrno('listen', -r));
  }

  @override
  Future<void> connect(
    SysAddr remote, {
    DateTime? deadline,
    Future<void>? cancel,
  }) async {
    if (deadline != null && !deadline.isAfter(DateTime.now())) {
      throw const SysTimeout();
    }
    if (_pendingCloses.isNotEmpty) await _closesSettled();
    await _ffiIo(
      () => _fd.connect(
        ffi.ffiSockaddr(family, remote, 'connect'),
        deadline: deadline,
        cancel: cancel,
      ),
    );
    _connectedTo = remote;
  }

  @override
  SysAddr? localAddr() => ffi.ffiLocalAddr(_fd);

  @override
  SysAddr? remoteAddr() => ffi.ffiPeerAddr(_fd);

  @override
  Future<SysTcpConn> toTcpConn() => heldIo(() async {
    _noDelay(_fd.fd);
    final local = localAddr();
    final RawSocket raw;
    try {
      raw = await ffi.ffiToRawSocket(_fd);
    } on ffi.FfiErrno catch (e) {
      throw _ffiError(e);
    }
    return _IoTcpConn.create(raw, local?.ip);
  });

  @override
  SysTcpListener toTcpListener() {
    final local = localAddr() ?? SysAddr(Uint8List(0), 0);
    return _FfiTcpListener(_fd, local);
  }

  @override
  SysUdpConn toUdpConn() => _FfiUdpConn(toSockConn() as ffi.FfiSock);

  @override
  SysSockConn toSockConn() =>
      ffi.FfiSock.of(_fd, family, sotype, raddr: _connectedTo);

  @override
  void close() => _fd.close();
}

/// Listener de fluxo no FFI (`ListenConfig.Control`): o laço de `accept4`
/// fica aqui; cada conexão aceita vai para o `dart:io` pela ponte.
final class _FfiTcpListener implements SysTcpListener, SysRawFd {
  _FfiTcpListener(this._fd, this.local);

  final ffi.FfiFd _fd;

  @override
  final SysAddr local;

  @override
  Future<SysTcpConn> accept() => heldIo(() async {
    while (true) {
      final (c, _) = await _ffiIo(_fd.accept);
      try {
        _noDelay(c.fd);
        final sa = c.localAddr();
        final raw = await ffi.ffiToRawSocket(c);
        return await _IoTcpConn.create(raw, sa?.ip);
      } on ffi.FfiErrno catch (e) {
        // O par desistiu entre o `accept` e a ponte: o Go também pula.
        if (e.errno == sf.ENOTCONN) continue;
        throw _ffiError(e);
      } on SocketException {
        continue;
      }
    }
  });

  @override
  void close() => _fd.close();

  @override
  set deadline(DateTime? d) => _fd.readDeadline = d;

  @override
  int get rawFd => _fd.fd;

  @override
  bool get rawReadExpired => _fd.readExpired;

  @override
  bool get rawWriteExpired => _fd.writeExpired;

  @override
  Future<void> rawWaitRead() => _fd.waitRead();

  @override
  Future<void> rawWaitWrite() => _fd.waitWrite();
}

/// Uma opção de socket pelo `dart:io` (`setRawOption`/`getRawOption`): o
/// descritor virtual das conexões que ele possui.
int _ioSetsockopt(
  void Function(RawSocketOption) set,
  int level,
  int opt,
  Uint8List value,
) {
  try {
    set(RawSocketOption(level, opt, value));
    return 0;
  } catch (e) {
    return -_ioErrno(e);
  }
}

int _ioGetsockopt(
  Uint8List Function(RawSocketOption) get,
  int level,
  int opt,
  Uint8List out,
) {
  try {
    final v = get(RawSocketOption(level, opt, out));
    final n = v.length < out.length ? v.length : out.length;
    out.setRange(0, n, v);
    return n;
  } catch (e) {
    return -_ioErrno(e);
  }
}

/// O errno (numeração do linux) de uma falha do `dart:io`; `EINVAL` se não
/// tiver número. ⚠️ Fora do linux, só os da tabela do SO têm equivalente.
int _ioErrno(Object e) {
  final n = switch (e) {
    OSError(:final errorCode) => errorCode,
    SocketException(:final osError) => osError?.errorCode ?? 0,
    _ => 0,
  };
  return errnoNumbers[_errnoNames[n] ?? ''] ?? sf.EINVAL;
}
