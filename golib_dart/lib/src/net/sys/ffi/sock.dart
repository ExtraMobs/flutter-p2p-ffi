/// [FfiSock]: a conexão ([SysSockConn]) de todo socket da rede FFI que não
/// vai para o `dart:io`: o `netFD` do Go 1.26.5 sobre o [FfiFd]. Serve aos
/// sockets Unix de todos os tipos (`unix`, `unixgram`, `unixpacket`;
/// E3–E5), ao IP bruto (E6) e, por baixo do `SysUdpConn`, ao UDP (E7).
///
/// O socket nasce montado pelo `socket()` do Go do shim `net`
/// (`_goSocket`, `src/net/control.dart`) sobre o `SysSocket`
/// (`io_ffi.dart`), que o entrega aqui por `toSockConn`/`toUdpConn`. Os
/// endereços saem do `getsockname`/`getpeername` como no `anyToSockaddr` do
/// Go (nome Unix abstrato com `@`; sem nome, `@`; `AF_UNSPEC` é nil; zona
/// IPv6 pelo nome da interface, como o `zoneCache`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Directory, File, FileSystemException;
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

/// Índice da interface [zone] (nome ou número), 0 se não existe.
int ffiZoneIndex(String zone) {
  if (zone.isEmpty) return 0;
  final n = int.tryParse(zone);
  if (n != null) return n;
  return int.tryParse(_readSys('/sys/class/net/$zone/ifindex')) ?? 0;
}

/// Nome da interface [index] (o número, se não houver nome).
String ffiZoneName(int index) {
  if (index == 0) return '';
  try {
    for (final e in Directory('/sys/class/net').listSync()) {
      final name = e.path.substring(e.path.lastIndexOf('/') + 1);
      if (int.tryParse(_readSys('/sys/class/net/$name/ifindex')) == index) {
        return name;
      }
    }
  } on FileSystemException {
    // sem /sys: o número
  }
  return '$index';
}

String _readSys(String path) {
  try {
    return File(path).readAsStringSync().trim();
  } on FileSystemException {
    return '';
  }
}

/// Grava [a] no layout do kernel para [family] (o `sockaddr` do Go) e
/// devolve o tamanho. Nome Unix que não cabe: `EINVAL` de [syscall]; IP de
/// outra família: [SysAddrError]. Em `AF_INET6`, IP vazio ou `0.0.0.0` é
/// `::`, e IPv4 vai mapeado (`ipToSockaddrInet6`).
int ffiEncodeSockaddr(
  int family,
  SysAddr a,
  Pointer<Uint8> out,
  String syscall,
) {
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
      var ip = a.ip;
      final v4 = ipTo4(ip);
      if (ip.isEmpty || (v4 != null && v4.every((b) => b == 0))) {
        ip = Uint8List(16);
      }
      return sf.encodeSockaddr(
        sf.Sockaddr.inet(
          Uint8List.fromList(ipTo16(ip)),
          a.port,
          scopeId: ffiZoneIndex(a.zone),
        ),
        out,
      );
  }
}

/// [a] como [sf.Sockaddr] da [family] (para o `FfiFd.connect`), com as
/// regras e os erros de [ffiEncodeSockaddr].
sf.Sockaddr ffiSockaddr(int family, SysAddr a, String syscall) {
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  try {
    final len = ffiEncodeSockaddr(family, a, sa, syscall);
    if (family == sf.AF_UNIX) return sf.Sockaddr.unix(a.path ?? '');
    return sf.decodeSockaddr(sa, len);
  } finally {
    sf.libcAlloc.free(sa);
  }
}

/// O `anyToSockaddr` do Go sobre [len] bytes em [sa] (o resto zerado):
/// família `AF_UNSPEC` (remetente sem nome) é `null`; nome Unix com NUL
/// inicial vira `@` e termina no primeiro NUL.
SysAddr? ffiDecodeSockaddr(Pointer<Uint8> sa, int len) {
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
      return SysAddr(s.ip, s.port, ffiZoneName(s.scopeId));
  }
  return null;
}

/// `getsockname` de [fd] no formato do Go, ou `null`.
SysAddr? ffiLocalAddr(FfiFd fd) =>
    fd.isClosed ? null : _name(fd.fd, sf.getsockname);

/// `getpeername` de [fd] no formato do Go, ou `null` (sem par).
SysAddr? ffiPeerAddr(FfiFd fd) =>
    fd.isClosed ? null : _name(fd.fd, sf.getpeername);

/// `getsockname`/`getpeername` de [fd] no formato do Go, ou `null`.
SysAddr? _name(int fd, int Function(int, Pointer<Uint8>, Pointer<Uint32>) f) {
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  final len = sf.libcAlloc<Uint32>()..value = sf.sockaddrStorageSize;
  try {
    sa
        .asTypedList(sf.sockaddrStorageSize)
        .fillRange(0, sf.sockaddrStorageSize, 0);
    if (f(fd, sa, len) < 0) return null;
    return ffiDecodeSockaddr(sa, len.value);
  } finally {
    sf.libcAlloc.free(sa);
    sf.libcAlloc.free(len);
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

/// [SysSockConn] sobre um [FfiFd], com o fd real para o `SyscallConn`
/// ([SysRawFd]).
final class FfiSock implements SysSockConn, SysRawFd, SysWritev {
  /// A conexão do socket [fd] já montado (`bind`, `listen` ou `connect`
  /// feitos): endereços pelo `getsockname`/`getpeername`. [raddr]: o
  /// destino do `connect` feito (o `fd.isConnected` do Go), que vale como
  /// par quando o `getpeername` não responde, como no `netFD.dial`.
  factory FfiSock.of(FfiFd fd, int family, int sotype, {SysAddr? raddr}) =>
      FfiSock._(
        fd,
        family,
        sotype,
        _name(fd.fd, sf.getsockname),
        raddr == null ? null : _name(fd.fd, sf.getpeername) ?? raddr,
        connected: raddr != null,
      );

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

  /// `writev(2)`, como o `poll.FD.Writev` do Go: no fluxo, a parcial
  /// avança os iovecs e repete; datagrama, seqpacket e bruto mandam uma
  /// mensagem só.
  @override
  Future<int> writev(List<Uint8List> chunks) => _sys(() async {
    final total = chunks.fold(0, (t, c) => t + c.length);
    final data = sf.libcAlloc<Uint8>(total);
    final iov = sf.libcAlloc<sf.IoVec>(chunks.length);
    try {
      var o = 0;
      for (var i = 0; i < chunks.length; i++) {
        final c = chunks[i];
        (data + o).asTypedList(c.length).setAll(0, c);
        (iov + i).ref
          ..base = (data + o).cast()
          ..len = c.length;
        o += c.length;
      }
      var n = 0, first = 0;
      while (n < total) {
        final int r;
        try {
          r = await _fd.io(
            sf.POLLOUT,
            'writev',
            (fd) => sf.writev(fd, iov + first, chunks.length - first),
          );
        } on FfiErrno catch (e) {
          throw FfiErrno('writev', e.errno, written: n);
        } on SysTimeout {
          throw SysTimeout(n);
        } on SysClosed {
          throw SysClosed(n);
        }
        n += r;
        if (!_stream) break;
        var k = r; // consome k bytes dos iovecs
        while (first < chunks.length && k >= (iov + first).ref.len) {
          k -= (iov + first).ref.len;
          first++;
        }
        if (k > 0) {
          final v = (iov + first).ref;
          v
            ..base = (v.base.cast<Uint8>() + k).cast()
            ..len = v.len - k;
        }
      }
      return n;
    } finally {
      sf.libcAlloc.free(data);
      sf.libcAlloc.free(iov);
    }
  });

  @override
  Future<(int, SysAddr?)> readFrom(Uint8List buf) => _sys(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>();
    try {
      final n = await _fd.io(sf.POLLIN, 'recvfrom', (fd) {
        sa
            .asTypedList(sf.sockaddrStorageSize)
            .fillRange(0, sf.sockaddrStorageSize, 0);
        len.value = sf.sockaddrStorageSize;
        return sf.recvfrom(fd, buf, 0, sa, len);
      });
      return (n, ffiDecodeSockaddr(sa, len.value));
    } finally {
      sf.libcAlloc.free(sa);
      sf.libcAlloc.free(len);
    }
  });

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => _sys(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    try {
      final salen = ffiEncodeSockaddr(family, to, sa, 'sendto');
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
    Uint8List oob, [
    int flags = 0,
  ]) => _sys(() async {
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
      return (
        n,
        oobn,
        m.hdr.ref.flags,
        ffiDecodeSockaddr(m.name, m.hdr.ref.namelen),
      );
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
          final salen = to == null
              ? 0
              : ffiEncodeSockaddr(family, to, m.name, 'sendmsg');
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
  Future<SysSockConn> accept() => _sys(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>();
    try {
      final int nfd;
      try {
        nfd = await _fd.io(sf.POLLIN, 'accept4', (fd) {
          while (true) {
            sa
                .asTypedList(sf.sockaddrStorageSize)
                .fillRange(0, sf.sockaddrStorageSize, 0);
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
        ffiDecodeSockaddr(sa, len.value),
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
