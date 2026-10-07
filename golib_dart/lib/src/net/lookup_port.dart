part of '../../net.dart';

// Portas por nome (`lookup.go`, `port.go`, `port_unix.go`) e as funções de
// pacote `net.Lookup*` (sobre o `DefaultResolver`).

/// `services` do Go (`lookup.go`): a tabela embutida de portas por nome,
/// completada pelo `/etc/services` (`_readServices`).
final _services = <String, Map<String, int>>{
  'udp': {'domain': 53},
  'tcp': {
    'ftp': 21,
    'ftps': 990,
    'gopher': 70,
    'http': 80,
    'https': 443,
    'imap2': 143,
    'imap3': 220,
    'imaps': 993,
    'pop3': 110,
    'pop3s': 995,
    'smtp': 25,
    'submissions': 465,
    'ssh': 22,
    'telnet': 23,
  },
};

/// `maxPortBufSize`: nome de serviço mais longo que isso não é achado.
const _maxPortBufSize = 25;

/// `parsePort(service)`: (porta, precisa consultar o nome).
(int, bool) _parsePort(String service) {
  if (service.isEmpty) return (0, false);
  const max = 0xffffffff, cutoff = 1 << 30;
  var neg = false;
  if (service[0] == '+') {
    service = service.substring(1);
  } else if (service[0] == '-') {
    neg = true;
    service = service.substring(1);
  }
  var n = 0;
  for (final d in service.runes) {
    if (d < 0x30 || d > 0x39) return (0, true);
    if (n >= cutoff) {
      n = max;
      break;
    }
    n = n * 10 + d - 0x30;
    if (n > max) {
      n = max;
      break;
    }
  }
  int port;
  if (!neg && n >= cutoff) {
    port = cutoff - 1;
  } else if (neg && n > cutoff) {
    port = cutoff;
  } else {
    port = n;
  }
  return (neg ? -port : port, false);
}

/// `lookupPortMapWithNetwork`.
(int, GoError?) _lookupPortMapWithNetwork(
  String network,
  String errNetwork,
  String service,
) {
  final m = _services[network];
  if (m == null) {
    return (
      0,
      DNSError(err: _s('unknown network'), name: _s('$errNetwork/$service')),
    );
  }
  final port = service.length <= _maxPortBufSize
      ? m[_lowerAscii(service)]
      : null;
  if (port != null) return (port, null);
  return (0, _newDNSError(_errUnknownPort, _s('$errNetwork/$service'), _s('')));
}

/// `goLookupPort` (`lookupPortMap` depois do `/etc/services`).
(int, GoError?) _goLookupPort(String network, String service) {
  _readServices();
  switch (network) {
    case 'ip':
      final (p, err) = _lookupPortMapWithNetwork('tcp', 'ip', service);
      if (err == null) return (p, null);
      return _lookupPortMapWithNetwork('udp', 'ip', service);
    case 'tcp' || 'tcp4' || 'tcp6':
      return _lookupPortMapWithNetwork('tcp', 'tcp', service);
    case 'udp' || 'udp4' || 'udp6':
      return _lookupPortMapWithNetwork('udp', 'udp', service);
  }
  return (
    0,
    DNSError(err: _s('unknown network'), name: _s('$network/$service')),
  );
}

/// `Resolver.LookupPort(ctx, network, service)`.
Future<(int, GoError?)> _lookupPort(String network, String service) async {
  var (port, needsLookup) = _parsePort(service);
  if (needsLookup) {
    switch (network) {
      case 'tcp' || 'tcp4' || 'tcp6' || 'udp' || 'udp4' || 'udp6' || 'ip':
        break;
      case '':
        network = 'ip';
      default:
        return (
          0,
          AddrError(err: _s('unknown network'), addr: _s(network)) as GoError,
        );
    }
    final (p, err) = _goLookupPort(network, service);
    if (err != null) return (0, err);
    port = p;
  }
  if (port < 0 || port > 65535) {
    return (
      0,
      AddrError(err: _s('invalid port'), addr: _s(service)) as GoError,
    );
  }
  return (port, null);
}

/// `net.LookupPort(network, service)`.
Future<(Golang.Int, GoError?)> lookupPort(
  Golang.String network,
  Golang.String service,
) async {
  final (p, err) = await _lookupPort(network.toString(), service.toString());
  return (Golang.Int(p), err);
}

/// `net.LookupHost(host)`.
Future<(Slice<Golang.String>, GoError?)> lookupHost(Golang.String host) =>
    defaultResolver.lookupHost(context.background(), host);

/// `net.LookupIP(host)`.
Future<(Slice<IP>, GoError?)> lookupIP(Golang.String host) async {
  final (addrs, err) = await defaultResolver.lookupIPAddr(
    context.background(),
    host,
  );
  if (err != null) return (Slice<IP>.nil(_ipElem), err);
  return (
    Slice.of([for (var i = 0; i < addrs.length; i++) addrs[i].ip], _ipElem),
    null,
  );
}

/// `net.LookupTXT(name)`.
Future<(Slice<Golang.String>, GoError?)> lookupTXT(Golang.String name) =>
    defaultResolver.lookupTXT(context.background(), name);

/// `net.LookupCNAME(host)`.
Future<(Golang.String, GoError?)> lookupCNAME(Golang.String host) =>
    defaultResolver.lookupCNAME(context.background(), host);

/// `net.LookupSRV(service, proto, name)`.
Future<(Golang.String, Slice<SRV?>, GoError?)> lookupSRV(
  Golang.String service,
  Golang.String proto,
  Golang.String name,
) => defaultResolver.lookupSRV(context.background(), service, proto, name);

/// `net.LookupMX(name)`.
Future<(Slice<MX?>, GoError?)> lookupMX(Golang.String name) =>
    defaultResolver.lookupMX(context.background(), name);

/// `net.LookupNS(name)`.
Future<(Slice<NS?>, GoError?)> lookupNS(Golang.String name) =>
    defaultResolver.lookupNS(context.background(), name);

/// `net.LookupAddr(addr)`.
Future<(Slice<Golang.String>, GoError?)> lookupAddr(Golang.String addr) =>
    defaultResolver.lookupAddr(context.background(), addr);
