part of '../../net.dart';

// O socket de IP bruto: `sysDialer.dialIP`/`sysListener.listenIP` de
// `iprawsock_posix.go`, com o `internetSocket` e o `favoriteAddrFamily` de
// `ipsock_posix.go` do Go 1.26, sobre o `sys.sysSocket` (rede FFI). Sem
// ela (Node, navegador, VM fora do linux), `socket: operation not
// supported` (F4). Sem privilégio, o sistema recusa com o mesmo
// `socket: operation not permitted` do Go.

/// `(*IPAddr).family()`.
int _ipFamily(IPAddr? a) {
  if (a == null || a.ip.length <= _iPv4len) return sys.sysAfInet;
  return a.ip.to4().length != 0 ? sys.sysAfInet : sys.sysAfInet6;
}

/// `(*IPAddr).isWildcard()`.
bool _ipWildcard(IPAddr? a) =>
    a == null || a.ip.length == 0 || a.ip.isUnspecified();

/// `favoriteAddrFamily(network, laddr, raddr, mode)`: (família, ipv6only).
/// ⚠️ `supportsIPv4` é sempre verdadeiro.
(int, bool) _favoriteFamily(
  String network,
  IPAddr? laddr,
  IPAddr? raddr, {
  required bool listen,
}) {
  if (network.endsWith('4')) return (sys.sysAfInet, false);
  if (network.endsWith('6')) return (sys.sysAfInet6, true);
  if (listen && _ipWildcard(laddr)) {
    if (sys.sysSupportsIPv4map()) return (sys.sysAfInet6, false);
    return (_ipFamily(laddr), false);
  }
  if (_ipFamily(laddr) == sys.sysAfInet && _ipFamily(raddr) == sys.sysAfInet) {
    return (sys.sysAfInet, false);
  }
  return (sys.sysAfInet6, false);
}

IPAddr? _ipAddrOfSys(sys.SysAddr? a) =>
    a == null ? null : IPAddr(ip: _ipOf(a.ip), zone: _s(a.zone));

/// `dialIP` ([listen] falso) ou `listenIP` até o `*IPConn`: o erro sem o
/// `*OpError`, que quem chama monta.
Future<(IPConn?, GoError?)> _ipSocket(
  String network,
  IPAddr? laddr,
  IPAddr? raddr, {
  required bool listen,
}) async {
  final (afnet, proto, err) = _parseNetwork(network, needsProto: true);
  if (err != null) return (null, err);
  if (!_isIPFamily(afnet)) return (null, UnknownNetworkError(_s(network)));
  if (!sys.sysSockSupported) return (null, _notSupported('socket'));
  final (family, v6only) = _favoriteFamily(afnet, laddr, raddr, listen: listen);
  try {
    final s = await sys.sysSocket(
      family: family,
      sotype: sys.sysSockRaw,
      proto: proto,
      ipv6only: v6only,
      laddr: laddr == null ? null : _sysAddrOf(laddr.ip, 0, laddr.zone),
      raddr: raddr == null ? null : _sysAddrOf(raddr.ip, 0, raddr.zone),
    );
    return (
      IPConn._(s, afnet, _ipAddrOfSys(s.localAddr), _ipAddrOfSys(s.remoteAddr)),
      null,
    );
  } on Object catch (e) {
    return (null, _sysError(e));
  }
}
