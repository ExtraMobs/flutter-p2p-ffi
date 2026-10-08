part of '../../net.dart';

// `UDPConn.ReadMsgUDP`/`WriteMsgUDP` e as formas `AddrPort` (porta de
// `udpsock.go`/`udpsock_posix.go` do Go 1.26.5).
//
// Na VM no linux o socket é da rede FFI (E7): `recvmsg`/`sendmsg` com os
// dados de controle (`IP_TOS`, `IP_PKTINFO`... ligados por
// `syscall.SetsockoptInt` no `SyscallConn`) e as flags do `recvmsg`
// (`MSG_TRUNC` no datagrama truncado). ⚠️ Sem rede FFI (Node, VM fora do
// linux), não há dados de controle: a leitura devolve `oobn` e `flags`
// zero, e uma escrita com `oob` dá `sendmsg: operation not supported`.

/// `ReadMsgUDPAddrPort(b, oob)`.
Future<(Golang.Int, Golang.Int, Golang.Int, netip.AddrPort, GoError?)>
_readMsgUDP(UDPConn c, Slice<Golang.Uint8> b, Slice<Golang.Uint8> oob) async {
  final zero = Golang.Int(0);
  if (c._closed) {
    return (zero, zero, zero, netip.AddrPort(), c._op('read', sys.SysClosed()));
  }
  final fd = c._fd!;
  final buf = Uint8List(b.length);
  try {
    if (fd is sys.SysUdpMsg) {
      final ob = Uint8List(oob.length);
      final (n, oobn, flags, from) = await (fd as sys.SysUdpMsg).readMsg(
        buf,
        ob,
      );
      _copyInto(b, buf, n < buf.length ? n : buf.length);
      _copyInto(oob, ob, oobn);
      return (
        Golang.Int(n),
        Golang.Int(oobn),
        Golang.Int(flags),
        from == null ? netip.AddrPort() : _udpAddrOf(from).addrPort(),
        null,
      );
    }
    final (n, from) = await c._recv(buf);
    _copyInto(b, buf, n);
    return (Golang.Int(n), zero, zero, _udpAddrOf(from).addrPort(), null);
  } on Object catch (e) {
    return (zero, zero, zero, netip.AddrPort(), c._op('read', e));
  }
}

/// `WriteMsgUDP(b, oob, addr)`: `(n, len(oob))`.
Future<(Golang.Int, Golang.Int, GoError?)> _writeMsgUDP(
  UDPConn c,
  Slice<Golang.Uint8> b,
  Slice<Golang.Uint8> oob,
  UDPAddr? addr,
) async {
  final zero = Golang.Int(0);
  GoError fail(GoError err) => _opError('write', c._net, c._laddr, addr, err);
  if (c._closed) return (zero, zero, fail(errClosed));
  final connected = c._peer != null;
  if (connected && addr != null) return (zero, zero, fail(errWriteToConnected));
  if (!connected && addr == null) {
    return (zero, zero, fail(_errMissingAddress));
  }
  final fd = c._fd!;
  final to = addr == null
      ? null
      : _sysAddrOf(addr.ip, addr.port.toInt(), addr.zone);
  try {
    if (fd is sys.SysUdpMsg) {
      final msg = fd as sys.SysUdpMsg;
      if (to != null) {
        final ferr = _familyError(msg.family, to.ip);
        if (ferr != null) return (zero, zero, fail(ferr));
      }
      final (n, oobn) = await msg.writeMsg(_u8(b), _u8(oob), to);
      return (Golang.Int(n), Golang.Int(oobn), null);
    }
    if (oob.length > 0) {
      return (
        zero,
        zero,
        fail(os.newSyscallError(_s('sendmsg'), syscall.eopnotsupp)!),
      );
    }
    final peer = c._peer;
    final n = await fd.writeTo(
      _u8(b),
      to ?? _sysAddrOf(peer!.ip, peer.port.toInt(), peer.zone),
    );
    return (Golang.Int(n), zero, null);
  } on Object catch (e) {
    return (zero, zero, fail(_sysError(e)));
  }
}
