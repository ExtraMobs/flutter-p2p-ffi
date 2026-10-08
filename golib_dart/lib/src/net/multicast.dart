part of '../../net.dart';

// `ListenMulticastUDP` (porta de `udpsock.go`, `udpsock_posix.go`,
// `sockoptip4_linux.go` e `sockoptip6_posix.go` do Go 1.26.5). O socket é o
// do `ListenUDP` (com grupo multicast, o `listenDatagram` escuta no não
// especificado da família com `SO_REUSEADDR`); as opções vão por
// `setsockopt` com as estruturas do linux: no fd real (rede FFI), pelo
// `setRawOption` do `dart:io`, ou pelo `dgram` do Node
// ([sys.SysMulticastOpts]).

/// `net.ListenMulticastUDP(network, ifi, gaddr)`.
Future<(UDPConn?, GoError?)> listenMulticastUDP(
  Golang.String network,
  Interface? ifi,
  UDPAddr? gaddr,
) async {
  final net = network.toString();
  if (!const {'udp', 'udp4', 'udp6'}.contains(net)) {
    return (
      null,
      _opError('listen', net, null, gaddr, UnknownNetworkError(network)),
    );
  }
  if (gaddr == null || gaddr.ip.length == 0) {
    return (null, _opError('listen', net, null, gaddr, _errMissingAddress));
  }
  final (c, err) = await listenUDP(network, gaddr);
  if (err != null) return (null, err);
  final idx = ifi == null ? 0 : ifi.index.toInt();
  final ip4 = gaddr.ip.to4();
  final jerr = ip4.length == 4
      ? _listenIPv4MulticastUDP(c!, ifi != null, idx, _u8(ip4))
      : _listenIPv6MulticastUDP(c!, ifi != null, idx, _u8(gaddr.ip));
  if (jerr != null) {
    c.close();
    return (null, _opError('listen', net, null, gaddr, jerr));
  }
  return (c, null);
}

/// `listenIPv4MulticastUDP`: `IP_MULTICAST_IF` (com interface),
/// `IP_MULTICAST_LOOP` desligado e `IP_ADD_MEMBERSHIP` (`ip_mreqn`).
GoError? _listenIPv4MulticastUDP(
  UDPConn c,
  bool hasIfi,
  int idx,
  Uint8List group,
) {
  Uint8List mreqn(Uint8List addr) => Uint8List(12)
    ..setRange(0, 4, addr)
    ..buffer.asByteData().setInt32(8, idx, Endian.little);
  if (hasIfi) {
    final err = _mcastSetsockopt(c, 0, 32, mreqn(Uint8List(4)));
    if (err != null) return err;
  }
  return _mcastSetsockopt(c, 0, 34, _int32(0)) ??
      _mcastSetsockopt(c, 0, 35, mreqn(group));
}

/// `listenIPv6MulticastUDP`: `IPV6_MULTICAST_IF` (com interface),
/// `IPV6_MULTICAST_LOOP` desligado e `IPV6_JOIN_GROUP` (`ipv6_mreq`).
GoError? _listenIPv6MulticastUDP(
  UDPConn c,
  bool hasIfi,
  int idx,
  Uint8List group,
) {
  if (hasIfi) {
    final err = _mcastSetsockopt(c, 41, 17, _int32(idx));
    if (err != null) return err;
  }
  final mreq = Uint8List(20)
    ..setRange(0, 16, group)
    ..buffer.asByteData().setUint32(16, idx, Endian.little);
  return _mcastSetsockopt(c, 41, 19, _int32(0)) ??
      _mcastSetsockopt(c, 41, 20, mreq);
}

Uint8List _int32(int v) =>
    Uint8List(4)..buffer.asByteData().setInt32(0, v, Endian.little);

/// `setsockopt` no socket de [c], com o erro do Go
/// (`wrapSyscallError("setsockopt", err)`).
GoError? _mcastSetsockopt(UDPConn c, int level, int opt, Uint8List v) {
  final fd = c._fd;
  final r = fd is sys.SysRawFd
      ? ssys.sysSetsockopt((fd as sys.SysRawFd).rawFd, level, opt, v)
      : fd is sys.SysSockopts
      ? (fd as sys.SysSockopts).rawSetsockopt(level, opt, v)
      : fd is sys.SysMulticastOpts
      ? (fd as sys.SysMulticastOpts).multicastSetsockopt(level, opt, v)
      : -95; // EOPNOTSUPP
  return r < 0 ? os.newSyscallError(_s('setsockopt'), syscall.Errno(-r)) : null;
}
