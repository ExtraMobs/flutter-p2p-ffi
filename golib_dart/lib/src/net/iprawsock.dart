part of '../../net.dart';

// IP bruto (`iprawsock.go`, `parseNetwork` de `dial.go`, `lookupProtocol`
// de `lookup.go`/`lookup_unix.go` e `internetAddrList`/`forResolve` de
// `ipsock.go` do Go 1.26): a rede (`ip`, `ip4:icmp`, `ip6:58`...), o
// endereço e o `DialIP`/`ListenIP`. O socket (`SOCK_RAW` pela rede FFI) está
// em `iprawsock_sock.dart`; a conexão, em `ipconn.dart`.

/// `maxProtoLength`: `len("RSVP-E2E-IGNORE") + 10`.
const _maxProtoLength = 25;

/// `protocols` do Go, completado pelo `/etc/protocols` na primeira consulta.
final _protocols = <String, int>{
  'icmp': 1,
  'igmp': 2,
  'tcp': 6,
  'udp': 17,
  'ipv6-icmp': 58,
};

bool _protocolsRead = false;

/// `readProtocolsOnce`: nome e apelidos de cada linha do `/etc/protocols`
/// (sem sobrescrever o que já está na tabela).
void _readProtocols() {
  if (_protocolsRead) return;
  _protocolsRead = true;
  final text = sys.sysReadFile('/etc/protocols');
  if (text == null) return;
  for (var line in text.split('\n')) {
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash);
    final f = line
        .split(RegExp('[ \r\t\n]'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (f.length < 2) continue;
    final (proto, _, ok) = _dtoi(_s(f[1]));
    if (!ok) continue;
    _protocols.putIfAbsent(f[0], () => proto);
    for (final alias in f.skip(2)) {
      _protocols.putIfAbsent(alias, () => proto);
    }
  }
}

/// `lookupProtocol(ctx, name)`: o nome em minúsculas ASCII na tabela.
(int, GoError?) _lookupProtocol(String name) {
  _readProtocols();
  final n = _s(name).length;
  final lower = String.fromCharCodes([
    for (final c in name.codeUnits) c >= 0x41 && c <= 0x5a ? c + 0x20 : c,
  ]);
  final proto = _protocols[lower];
  if (proto == null || n > _maxProtoLength) {
    return (
      0,
      AddrError(err: _s('unknown IP protocol specified'), addr: _s(name)),
    );
  }
  return (proto, null);
}

/// `parseNetwork(ctx, network, needsProto)` do Go: (rede sem o protocolo,
/// protocolo IP, erro).
(String, int, GoError?) _parseNetwork(
  String network, {
  required bool needsProto,
}) {
  final i = network.lastIndexOf(':');
  if (i < 0) {
    switch (network) {
      case 'tcp' || 'tcp4' || 'tcp6' || 'udp' || 'udp4' || 'udp6':
        break;
      case 'ip' || 'ip4' || 'ip6':
        if (needsProto) return ('', 0, UnknownNetworkError(_s(network)));
      case 'unix' || 'unixgram' || 'unixpacket':
        break;
      default:
        return ('', 0, UnknownNetworkError(_s(network)));
    }
    return (network, 0, null);
  }
  final afnet = network.substring(0, i);
  if (_isIPFamily(afnet)) {
    final protostr = network.substring(i + 1);
    var (proto, j, ok) = _dtoi(_s(protostr));
    if (!ok || j != _s(protostr).length) {
      final GoError? err;
      (proto, err) = _lookupProtocol(protostr);
      if (err != null) return ('', 0, err);
    }
    return (afnet, proto, null);
  }
  return ('', 0, UnknownNetworkError(_s(network)));
}

bool _isIPFamily(String afnet) =>
    afnet == 'ip' || afnet == 'ip4' || afnet == 'ip6';

/// A rede é de IP bruto (`ip`, `ip4`, `ip6`, com ou sem `:protocolo`).
bool _isIPNetwork(String network) {
  final i = network.lastIndexOf(':');
  return _isIPFamily(i < 0 ? network : network.substring(0, i));
}

/// `internetAddrList` para `ip`/`ip4`/`ip6`: o endereço é só o host.
Future<(List<IPAddr>, GoError?)> _ipAddrList(String afnet, String addr) async {
  if (addr.isEmpty) return ([IPAddr()], null);
  final (found, err) = await defaultResolver._lookupIPAddr(null, afnet, addr);
  if (err != null) return (const <IPAddr>[], err);
  final ips = [for (final (ip, z) in found) IPAddr(ip: _ipOf(ip), zone: _s(z))];
  // Issue 18806 do Go: `::` sozinho também tenta 0.0.0.0.
  if (ips.length == 1 && ips[0].ip.equal(iPv6unspecified)) {
    ips.add(IPAddr(ip: iPv4zero));
  }
  final out = [
    for (final a in ips)
      if (afnet.endsWith('4')
          ? a.ip.to4().length != 0
          : afnet.endsWith('6')
          ? a.ip.length == 16 && a.ip.to4().length == 0
          : true)
        a,
  ];
  if (out.isEmpty) {
    return (
      const <IPAddr>[],
      AddrError(err: _errNoSuitableAddress.error(), addr: _s(addr)) as GoError,
    );
  }
  return (out, null);
}

/// `addrList.forResolve`: IPv6 se a rede é `ip` e o endereço tem `:`,
/// senão IPv4; na falta, o primeiro.
IPAddr _forResolve(String network, String addr, List<IPAddr> addrs) {
  final want6 = network == 'ip' && addr.contains(':');
  for (final a in addrs) {
    if ((a.ip.to4().length != 0) != want6) return a;
  }
  return addrs.first;
}

/// `net.ResolveIPAddr(network, address)`.
Future<(IPAddr?, GoError?)> resolveIPAddr(
  Golang.String network,
  Golang.String address,
) async {
  var net = network.toString();
  if (net.isEmpty) net = 'ip'; // curinga do Go 1.0
  final (afnet, _, err) = _parseNetwork(net, needsProto: false);
  if (err != null) return (null, err);
  if (!_isIPFamily(afnet))
    return (null, UnknownNetworkError(_s(net)) as GoError);
  final (addrs, aerr) = await _ipAddrList(afnet, address.toString());
  if (aerr != null) return (null, aerr);
  return (_forResolve(net, address.toString(), addrs), null);
}

/// `(*IPAddr)(nil)` também como `null`.
IPAddr? _nilIP(IPAddr? a) => a == null || a.$nilPtr ? null : a;

/// `net.DialIP(network, laddr, raddr)`.
Future<(IPConn?, GoError?)> dialIP(
  Golang.String network,
  IPAddr? laddr,
  IPAddr? raddr,
) async {
  final net = network.toString();
  final la = _nilIP(laddr), ra = _nilIP(raddr);
  if (ra == null) {
    return (null, _opError('dial', net, la, null, _errMissingAddress));
  }
  final (c, err) = await _ipSocket(net, la, ra, listen: false);
  return (c, err == null ? null : _opError('dial', net, la, ra, err));
}

/// `net.ListenIP(network, laddr)`.
Future<(IPConn?, GoError?)> listenIP(
  Golang.String network,
  IPAddr? laddr,
) async {
  final net = network.toString();
  final la = _nilIP(laddr) ?? IPAddr();
  final (c, err) = await _ipSocket(net, la, null, listen: true);
  return (c, err == null ? null : _opError('listen', net, null, la, err));
}

/// `Dialer.DialContext` com rede IP: resolve como o Go e disca o primeiro.
Future<(Conn?, GoError?)> _dialIPNetwork(
  String net,
  String address,
  Addr? la, {
  context.Context? ctx,
  _CtrlFn? ctrl,
}) async {
  final (afnet, _, err) = _parseNetwork(net, needsProto: true);
  if (err != null) return (null, _opError('dial', net, null, null, err));
  if (address.isEmpty) {
    return (null, _opError('dial', net, null, null, _errMissingAddress));
  }
  final (addrs, rerr) = await _ipAddrList(afnet, address);
  if (rerr != null) return (null, _opError('dial', net, null, null, rerr));
  if (la != null && la is! IPAddr) {
    final mismatch = AddrError(
      err: _s('mismatched local address type'),
      addr: la.string(),
    );
    return (null, _opError('dial', net, null, null, mismatch));
  }
  final ra = addrs.first;
  final (c, serr) = await _ipSocket(
    net,
    _nilIP(la as IPAddr?),
    ra,
    listen: false,
    ctx: ctx,
    ctrl: ctrl,
  );
  if (serr != null) return (null, _opError('dial', net, la, ra, serr));
  return (c as Conn?, null);
}

/// `ListenConfig.Listen` (sempre `unexpected address type`, como no Go) e
/// `ListenPacket` com rede IP.
Future<(IPConn?, GoError?)> _listenIPNetwork(
  String net,
  String address, {
  required bool packet,
  context.Context? ctx,
  _CtrlFn? ctrl,
}) async {
  final (afnet, _, err) = _parseNetwork(net, needsProto: true);
  if (err != null) return (null, _opError('listen', net, null, null, err));
  final (addrs, rerr) = await _ipAddrList(afnet, address);
  if (rerr != null) return (null, _opError('listen', net, null, null, rerr));
  final la = addrs.firstWhere(
    (a) => a.ip.to4().length != 0,
    orElse: () => addrs.first,
  );
  if (!packet) {
    final unexpected = AddrError(
      err: _s('unexpected address type'),
      addr: _s(address),
    );
    return (null, _opError('listen', net, null, la, unexpected));
  }
  final (c, serr) = await _ipSocket(
    net,
    la,
    null,
    listen: true,
    ctx: ctx,
    ctrl: ctrl,
  );
  return (c, serr == null ? null : _opError('listen', net, null, la, serr));
}
