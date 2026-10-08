part of '../../net.dart';

// O socket de IP bruto: `sysDialer.dialIP`/`sysListener.listenIP` de
// `iprawsock_posix.go`, com o `internetSocket` de `ipsock_posix.go` do Go
// 1.26, sobre o `socket()` do Go do shim (`_goSocket`, `control.dart`) e o
// `favoriteAddrFamily` de lá. Sem a rede FFI (Node, navegador, VM fora do
// linux), `socket: operation not supported` (F4). Sem privilégio, o sistema
// recusa com o mesmo `socket: operation not permitted` do Go.

IPAddr? _ipAddrOfSys(sys.SysAddr? a) =>
    a == null ? null : IPAddr(ip: _ipOf(a.ip), zone: _s(a.zone));

/// `dialIP` ([listen] falso) ou `listenIP` até o `*IPConn`: o erro sem o
/// `*OpError`, que quem chama monta. [ctrl]: o `Control` do `Dialer` ou do
/// `ListenConfig`.
Future<(IPConn?, GoError?)> _ipSocket(
  String network,
  IPAddr? laddr,
  IPAddr? raddr, {
  required bool listen,
  context.Context? ctx,
  _CtrlFn? ctrl,
}) async {
  final (afnet, proto, err) = _parseNetwork(network, needsProto: true);
  if (err != null) return (null, err);
  if (!_isIPFamily(afnet)) return (null, UnknownNetworkError(_s(network)));
  if (!sys.sysFfiAvailable) return (null, _notSupported('socket'));
  final la = laddr == null ? null : _sysAddrOf(laddr.ip, 0, laddr.zone);
  final ra = raddr == null ? null : _sysAddrOf(raddr.ip, 0, raddr.zone);
  final (family, v6only) = _favoriteFamily(
    afnet,
    la,
    ra,
    listen ? 'listen' : 'dial',
  );
  try {
    final s = await _goSocket(
      ctx: ctx,
      net: afnet,
      family: family,
      sotype: sys.sysSockRaw,
      proto: proto,
      ipv6only: v6only,
      laddr: la,
      raddr: ra,
      laddrStr: laddr?.string().toString(),
      raddrStr: raddr?.string().toString(),
      ctrl: ctrl,
    );
    final c = s.toSockConn();
    return (
      IPConn._(c, afnet, _ipAddrOfSys(c.localAddr), _ipAddrOfSys(c.remoteAddr)),
      null,
    );
  } on _GoErr catch (e) {
    return (null, e.err);
  } on Object catch (e) {
    return (null, _sysError(e));
  }
}
