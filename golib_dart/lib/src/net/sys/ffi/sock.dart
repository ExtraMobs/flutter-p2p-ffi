/// [FfiSock]: o socket genérico ([SysSock]) da rede FFI, porta do `netFD`
/// e do `socket()` de `sock_posix.go` do Go 1.26.5 sobre o [FfiFd]. Serve
/// aos sockets Unix de todos os tipos (`unix`, `unixgram`, `unixpacket`;
/// E3–E5) e ao IP bruto (E6).
///
/// [ffiSocket] segue a sequência do Go: `socket` → opções padrão
/// (`IPV6_V6ONLY` num AF_INET6 que não é bruto, `SO_BROADCAST` em
/// datagrama/bruto fora do Unix) → com `laddr` e sem `raddr`, o listener
/// (`SO_REUSEADDR`, `bind`, `listen` no fluxo/seqpacket; só `bind` no
/// datagrama/bruto); senão o dial (`bind` do `laddr`, `connect`). Os
/// endereços saem do `getsockname`/`getpeername` como no Go (nome Unix
/// abstrato com `@`; sem nome, `@`).
///
/// ⚠️ `Control`/`ControlContext` não entram aqui (etapa E2). ⚠️ Zona IPv6
/// só numérica (`%3`): o nome da interface do `zoneCache` do Go não é
/// procurado.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import '../../../sysffi/sysffi.dart' as sf;
import '../../../syscall/errno_table.dart' show errnoNames;
import '../common.dart';
import 'errors.dart';
import 'fd.dart';

/// [FfiErrno] → o [SysError] do motor (`connect: connection refused`).
SysError sysErrorOfErrno(FfiErrno e) {
  final code = errnoNames[e.errno];
  return code != null
      ? SysError.errno(e.syscall, code, written: e.written)
      : SysError(e.syscall, 'EOTHER', 'errno ${e.errno}', written: e.written);
}

Future<T> _sys<T>(Future<T> Function() op) async {
  try {
    return await op();
  } on FfiErrno catch (e) {
    throw sysErrorOfErrno(e);
  }
}

/// Grava [a] no layout do kernel para [family] (o `sockaddr` do Go) e
/// devolve o tamanho. Nome Unix que não cabe: `EINVAL` de [syscall]; IP de
/// outra família: [SysAddrError].
int _encode(int family, SysAddr a, Pointer<Uint8> out, String syscall) {
  switch (family) {
    case sf.AF_UNIX:
      final n = sf.encodeSockaddr(sf.Sockaddr.unix(a.path ?? ''), out);
      if (n < 0) throw FfiErrno(syscall, -n);
      return n;
    case sf.AF_INET:
      final ip = a.ip.isEmpty ? Uint8List(4) : ipTo4(a.ip);
      if (ip == null) throw SysAddrError('non-IPv4 address', ipToString(a.ip));
      return sf.encodeSockaddr(
        sf.Sockaddr.inet(Uint8List.fromList(ip), a.port),
        out,
      );
    default:
      // `ipToSockaddrInet6`: vazio ou `0.0.0.0` é `::`; IPv4 vira mapeado.
      var ip = a.ip;
      final v4 = ipTo4(ip);
      if (ip.isEmpty || (v4 != null && v4.every((b) => b == 0))) {
        ip = Uint8List(16);
      }
      return sf.encodeSockaddr(
        sf.Sockaddr.inet(
          Uint8List.fromList(ipTo16(ip)),
          a.port,
          scopeId: int.tryParse(a.zone) ?? 0,
        ),
        out,
      );
  }
}

/// O `anyToSockaddr` do Go sobre [len] bytes em [sa] (o resto zerado):
/// família `AF_UNSPEC` (remetente sem nome) é `null`; nome Unix com NUL
/// inicial vira `@` e termina no primeiro NUL.
SysAddr? _decode(Pointer<Uint8> sa, int len) {
  if (len < 2) return null;
  final b = sa.asTypedList(sf.sockaddrStorageSize);
  final family = b[0] | b[1] << 8;
  switch (family) {
    case sf.AF_UNIX:
      final path = Uint8List.fromList(b.sublist(2, 2 + sf.sunPathMax));
      if (path[0] == 0) path[0] = 0x40; // '@'
      final z = path.indexOf(0);
      return SysAddr.unix(
        utf8.decode(z < 0 ? path : path.sublist(0, z), allowMalformed: true),
      );
    case sf.AF_INET || sf.AF_INET6:
      final s = sf.decodeSockaddr(sa, len);
      return SysAddr(s.ip, s.port, s.scopeId == 0 ? '' : '${s.scopeId}');
  }
  return null;
}

/// `getsockname`/`getpeername` de [fd] no formato do Go, ou `null`.
SysAddr? _name(int fd, int Function(int, Pointer<Uint8>, Pointer<Uint32>) f) {
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  final len = sf.libcAlloc<Uint32>()..value = sf.sockaddrStorageSize;
  try {
    if (f(fd, sa, len) < 0) return null;
    return _decode(sa, len.value);
  } finally {
    sf.libcAlloc.free(sa);
    sf.libcAlloc.free(len);
  }
}

bool? _v4map;

/// `supportsIPv4map` do Go: um socket AF_INET6 com `IPV6_V6ONLY` desligado
/// aceita `::ffff:127.0.0.1`. Medido uma vez por isolate.
bool ffiSupportsIPv4map() => _v4map ??= () {
  final fd = sf.socket(sf.AF_INET6, sf.SOCK_STREAM | sf.SOCK_CLOEXEC, 0);
  if (fd < 0) return false;
  try {
    if (sf.setsockoptInt(fd, sf.IPPROTO_IPV6, sf.IPV6_V6ONLY, 0) < 0) {
      return false;
    }
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    try {
      final ip = Uint8List(16)
        ..[10] = 0xff
        ..[11] = 0xff
        ..[12] = 127
        ..[15] = 1;
      final n = sf.encodeSockaddr(sf.Sockaddr.inet(ip, 0), sa);
      return sf.bind(fd, sa, n) == 0;
    } finally {
      sf.libcAlloc.free(sa);
    }
  } finally {
    sf.close(fd);
  }
}();

/// Abre um socket como o `socket()` do Go (ver a documentação da library).
/// [laddr] sem [raddr] é listener (com [backlog] no fluxo/seqpacket); com
/// [raddr], dial ([deadline] e [cancel] valem para o `connect`). Erros:
/// [SysError] com a syscall do Go (`socket`, `setsockopt`, `bind`,
/// `listen`, `connect`), [SysAddrError], [SysTimeout], [SysCanceled].
Future<SysSock> ffiSocket({
  required int family,
  required int sotype,
  int proto = 0,
  bool ipv6only = false,
  SysAddr? laddr,
  SysAddr? raddr,
  int backlog = 4096,
  DateTime? deadline,
  Future<void>? cancel,
}) => _sys(() async {
  if (deadline != null && !deadline.isAfter(DateTime.now())) {
    throw const SysTimeout();
  }
  await FfiFd.closesSettled();
  final fd = FfiFd.socket(family, sotype, proto);
  try {
    // `setDefaultSockopts`.
    if (family == sf.AF_INET6 && sotype != sf.SOCK_RAW) {
      sf.setsockoptInt(fd.fd, sf.IPPROTO_IPV6, sf.IPV6_V6ONLY, ipv6only ? 1 : 0);
    }
    if ((sotype == sf.SOCK_DGRAM || sotype == sf.SOCK_RAW) &&
        family != sf.AF_UNIX) {
      _check(
        sf.setsockoptInt(fd.fd, sf.SOL_SOCKET, sf.SO_BROADCAST, 1),
        'setsockopt',
      );
    }
    if (laddr != null && raddr == null) {
      final stream = sotype == sf.SOCK_STREAM || sotype == sf.SOCK_SEQPACKET;
      if (stream) {
        _check(
          sf.setsockoptInt(fd.fd, sf.SOL_SOCKET, sf.SO_REUSEADDR, 1),
          'setsockopt',
        );
      }
      _bind(fd.fd, family, laddr);
      if (stream) _check(sf.listen(fd.fd, backlog), 'listen');
      return FfiSock._(
        fd,
        family,
        sotype,
        _name(fd.fd, sf.getsockname),
        null,
        connected: false,
      );
    }
    if (laddr != null) _bind(fd.fd, family, laddr);
    if (raddr == null) {
      return FfiSock._(
        fd,
        family,
        sotype,
        _name(fd.fd, sf.getsockname),
        null,
        connected: false,
      );
    }
    final to = _sockaddrOf(family, raddr, 'connect');
    await fd.connect(to, deadline: deadline, cancel: cancel);
    return FfiSock._(
      fd,
      family,
      sotype,
      _name(fd.fd, sf.getsockname),
      _name(fd.fd, sf.getpeername) ?? raddr,
      connected: true,
    );
  } catch (_) {
    fd.close();
    rethrow;
  }
});

void _check(int r, String syscall) {
  if (r < 0) throw FfiErrno(syscall, -r);
}

void _bind(int fd, int family, SysAddr a) {
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  try {
    final len = _encode(family, a, sa, 'bind');
    _check(sf.bind(fd, sa, len), 'bind');
  } finally {
    sf.libcAlloc.free(sa);
  }
}

/// [a] como [sf.Sockaddr] da [family] (para o `FfiFd.connect`).
sf.Sockaddr _sockaddrOf(int family, SysAddr a, String syscall) {
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  try {
    final len = _encode(family, a, sa, syscall);
    if (family == sf.AF_UNIX) return sf.Sockaddr.unix(a.path ?? '');
    return sf.decodeSockaddr(sa, len);
  } finally {
    sf.libcAlloc.free(sa);
  }
}

/// Memória nativa de uma mensagem (`msghdr`, `iovec`, nome, dados e
/// controle), liberada de uma vez.
final class _Msg {
  _Msg(int dataLen, int oobLen)
    : _mem = sf.libcAlloc<Uint8>(
        sizeOf<sf.MsgHdr>() +
            sizeOf<sf.IoVec>() +
            sf.sockaddrStorageSize +
            _round(dataLen) +
            _round(oobLen) +
            16,
      ) {
    final base = _mem.address;
    hdr = Pointer.fromAddress(base);
    iov = Pointer.fromAddress(base + sizeOf<sf.MsgHdr>());
    name = Pointer.fromAddress(iov.address + sizeOf<sf.IoVec>());
    data = Pointer.fromAddress(name.address + sf.sockaddrStorageSize);
    control = Pointer.fromAddress(data.address + _round(dataLen));
  }

  static int _round(int n) => (n + 7) & ~7;

  final Pointer<Uint8> _mem;
  late final Pointer<sf.MsgHdr> hdr;
  late final Pointer<sf.IoVec> iov;
  late final Pointer<Uint8> name;
  late final Pointer<Uint8> data;
  late final Pointer<Uint8> control;

  void free() => sf.libcAlloc.free(_mem);
}

/// [SysSock] sobre um [FfiFd].
final class FfiSock implements SysSock {
  FfiSock._(
    this._fd,
    this.family,
    this.sotype,
    this.localAddr,
    this.remoteAddr, {
    required bool connected,
  }) : isConnected = connected;

  final FfiFd _fd;

  @override
  final int family;
  @override
  final int sotype;
  @override
  final bool isConnected;
  @override
  final SysAddr? localAddr;
  @override
  final SysAddr? remoteAddr;

  /// O número do fd (`-1` depois do [close]).
  int get fd => _fd.fd;

  SysAddr get _none =>
      family == sf.AF_UNIX ? SysAddr.unix('') : SysAddr(Uint8List(0), 0);

  @override
  SysAddr get local => localAddr ?? _none;
  @override
  SysAddr get remote => remoteAddr ?? _none;

  bool get _stream => sotype == sf.SOCK_STREAM;

  @override
  Future<int> read(Uint8List buf) {
    if (buf.isEmpty) return Future.value(0);
    return _sys(() => _fd.read(buf));
  }

  @override
  Future<int> write(Uint8List data) {
    if (_stream) return _sys(() => _fd.write(data));
    // Datagrama, seqpacket e bruto: uma mensagem por `write` (inclusive a
    // vazia, que no seqpacket o par lê como EOF).
    return _sys(
      () => _fd.io(
        sf.POLLOUT,
        'write',
        (fd) => sf.sendto(fd, data, sf.MSG_NOSIGNAL, nullptr, 0),
      ),
    );
  }

  @override
  Future<(int, SysAddr?)> readFrom(Uint8List buf) => _sys(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>();
    try {
      final n = await _fd.io(sf.POLLIN, 'recvfrom', (fd) {
        sa.asTypedList(sf.sockaddrStorageSize).fillRange(0, sf.sockaddrStorageSize, 0);
        len.value = sf.sockaddrStorageSize;
        return sf.recvfrom(fd, buf, 0, sa, len);
      });
      return (n, _decode(sa, len.value));
    } finally {
      sf.libcAlloc.free(sa);
      sf.libcAlloc.free(len);
    }
  });

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => _sys(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    try {
      final salen = _encode(family, to, sa, 'sendto');
      await _fd.io(
        sf.POLLOUT,
        'sendto',
        (fd) => sf.sendto(fd, data, sf.MSG_NOSIGNAL, sa, salen),
      );
      return data.length;
    } finally {
      sf.libcAlloc.free(sa);
    }
  });

  /// O tipo do socket pelo `SO_TYPE` (o `Recvmsg`/`SendmsgN` do Go pergunta
  /// ao sistema antes de pôr o byte fictício).
  int _soType() {
    final (t, err) = sf.getsockoptInt(_fd.fd, sf.SOL_SOCKET, sf.SO_TYPE);
    if (err != 0) throw FfiErrno('getsockopt', err);
    return t;
  }

  @override
  Future<(int, int, int, SysAddr?)> readMsg(
    Uint8List buf,
    Uint8List oob,
    int flags,
  ) => _sys(() async {
    if (_fd.isClosed) throw const SysClosed();
    var dataLen = buf.length;
    if (oob.isNotEmpty && buf.isEmpty && _soType() != sf.SOCK_DGRAM) {
      dataLen = 1; // byte fictício
    }
    final m = _Msg(dataLen, oob.length);
    try {
      final n = await _fd.io(sf.POLLIN, 'recvmsg', (fd) {
        m.name
            .asTypedList(sf.sockaddrStorageSize)
            .fillRange(0, sf.sockaddrStorageSize, 0);
        m.iov.ref
          ..base = m.data.cast()
          ..len = dataLen;
        m.hdr.ref
          ..name = m.name.cast()
          ..namelen = sf.sockaddrStorageSize
          ..iov = m.iov
          ..iovlen = 1
          ..control = oob.isEmpty ? nullptr : m.control.cast()
          ..controllen = oob.length
          ..flags = 0;
        return sf.recvmsg(fd, m.hdr, flags);
      });
      final copy = n < buf.length ? n : buf.length;
      if (copy > 0) buf.setRange(0, copy, m.data.asTypedList(copy));
      final oobn = m.hdr.ref.controllen;
      if (oobn > 0) oob.setRange(0, oobn, m.control.asTypedList(oobn));
      return (n, oobn, m.hdr.ref.flags, _decode(m.name, m.hdr.ref.namelen));
    } finally {
      m.free();
    }
  });

  @override
  Future<(int, int)> writeMsg(Uint8List data, Uint8List oob, SysAddr? to) =>
      _sys(() async {
        if (_fd.isClosed) throw const SysClosed();
        var dataLen = data.length;
        if (oob.isNotEmpty && data.isEmpty && _soType() != sf.SOCK_DGRAM) {
          dataLen = 1; // byte fictício
        }
        final m = _Msg(dataLen, oob.length);
        try {
          final salen = to == null ? 0 : _encode(family, to, m.name, 'sendmsg');
          if (data.isNotEmpty) m.data.asTypedList(data.length).setAll(0, data);
          if (oob.isNotEmpty) m.control.asTypedList(oob.length).setAll(0, oob);
          final n = await _fd.io(sf.POLLOUT, 'sendmsg', (fd) {
            m.iov.ref
              ..base = m.data.cast()
              ..len = dataLen;
            m.hdr.ref
              ..name = to == null ? nullptr : m.name.cast()
              ..namelen = salen
              ..iov = m.iov
              ..iovlen = 1
              ..control = oob.isEmpty ? nullptr : m.control.cast()
              ..controllen = oob.length
              ..flags = 0;
            return sf.sendmsg(fd, m.hdr, sf.MSG_NOSIGNAL);
          });
          return (oob.isNotEmpty && data.isEmpty ? 0 : n, oob.length);
        } finally {
          m.free();
        }
      });

  @override
  Future<SysSock> accept() => _sys(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>();
    try {
      final int nfd;
      try {
        nfd = await _fd.io(sf.POLLIN, 'accept4', (fd) {
          while (true) {
            sa.asTypedList(sf.sockaddrStorageSize).fillRange(0, sf.sockaddrStorageSize, 0);
            len.value = sf.sockaddrStorageSize;
            final r = sf.accept4(
              fd,
              sa,
              len,
              sf.SOCK_NONBLOCK | sf.SOCK_CLOEXEC,
            );
            if (r != -sf.ECONNABORTED) return r;
          }
        });
      } on FfiErrno catch (e) {
        throw FfiErrno('accept4', e.errno);
      }
      final c = FfiFd.adopt(nfd);
      return FfiSock._(
        c,
        family,
        sotype,
        _name(nfd, sf.getsockname),
        _decode(sa, len.value),
        connected: false,
      );
    } finally {
      sf.libcAlloc.free(sa);
      sf.libcAlloc.free(len);
    }
  });

  @override
  void close() => _fd.close();

  @override
  void closeWrite() {
    if (!_fd.isClosed) sf.shutdown(_fd.fd, sf.SHUT_WR);
  }

  @override
  void closeRead() {
    if (!_fd.isClosed) sf.shutdown(_fd.fd, sf.SHUT_RD);
  }

  @override
  set readDeadline(DateTime? d) => _fd.readDeadline = d;

  @override
  set writeDeadline(DateTime? d) => _fd.writeDeadline = d;

  @override
  set deadline(DateTime? d) => _fd.readDeadline = d;

  // Opções de TCP: um socket Unix ou bruto não as tem (o shim só as chama
  // em `TCPConn`).
  @override
  void setNoDelay(bool v) {}
  @override
  void setKeepAlive(bool v) {}
  @override
  void setLinger(int sec) {}
  @override
  void setKeepAliveIdle(int secs) {}
  @override
  void setKeepAliveInterval(int secs) {}
  @override
  void setKeepAliveCount(int n) {}
}
