part of '../../net.dart';

// Nomes (D4): o resolver do sistema para IP e TXT (`sys.sysLookupIp`,
// `sys.sysLookupTxt`), e as portas por nome da tabela embutida do Go.
// ⚠️ `LookupAddr`/`CNAME`/`MX`/`NS`/`SRV` e o `Resolver.Dial` próprio não
// existem no shim (viram `Unsupported` na transpilação); o `DNSError` não
// traz o servidor (`Server` vazio), porque o resolver do sistema não o diz.

/// `services` do Go (`lookup.go`): a tabela embutida de portas por nome.
/// ⚠️ O `/etc/services` não é lido.
const _services = <String, Map<String, int>>{
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

/// `lookupPort`: número (com a checagem de faixa do Go) ou nome.
Future<(int, GoError?)> _lookupPort(String network, String service) async {
  final proto = network.startsWith('udp') ? 'udp' : network.startsWith('tcp') ? 'tcp' : '';
  if (service.isEmpty) return (0, null);
  // `parsePort`: dígitos (sinal opcional); fora de 0..65535 é erro.
  var s = service, neg = false;
  if (s.startsWith('+') || s.startsWith('-')) {
    neg = s[0] == '-';
    s = s.substring(1);
  }
  if (s.isNotEmpty && s.codeUnits.every((c) => c >= 0x30 && c <= 0x39)) {
    var n = 0;
    for (final c in s.codeUnits) {
      n = n * 10 + c - 0x30;
      if (n > 0xffff) break;
    }
    if (neg || n > 0xffff) {
      return (0, AddrError(err: _s('invalid port'), addr: _s(service)) as GoError);
    }
    return (n, null);
  }
  final port = _services[proto]?[service.toLowerCase()];
  if (port != null) return (port, null);
  return (
    0,
    DNSError(err: _s('unknown port'), name: _s('$network/$service'), isNotFound: true) as GoError,
  );
}

/// `net.LookupPort(network, service)`.
Future<(Golang.Int, GoError?)> lookupPort(Golang.String network, Golang.String service) async {
  final (p, err) = await _lookupPort(network.toString(), service.toString());
  return (Golang.Int(p), err);
}

/// `net.Resolver`. ⚠️ Sem `Dial` próprio: é sempre o resolver do sistema.
final class Resolver extends GoStruct<Resolver> {
  Resolver({bool? preferGo, bool? strictErrors})
    : preferGo = preferGo ?? false,
      strictErrors = strictErrors ?? false;

  /// `(*Resolver)(nil)` dentro de uma interface.
  static final Resolver $nil = Resolver()..$nilPtr = true;

  bool preferGo;
  bool strictErrors;

  @override
  String get $goType => 'net.Resolver';
  @override
  List<String> get $ptrMethods => const [
    'LookupHost',
    'LookupIP',
    'LookupIPAddr',
    'LookupNetIP',
    'LookupPort',
    'LookupTXT',
  ];
  @override
  Resolver $copy() => Resolver(preferGo: preferGo, strictErrors: strictErrors);
  @override
  void $set(Resolver o) {
    preferGo = o.preferGo;
    strictErrors = o.strictErrors;
  }

  @override
  List<Object?> get $fields => [preferGo, strictErrors];
  @override
  List<String> get $fieldNames => const ['PreferGo', 'StrictErrors'];

  /// Os IPs de host (IP literal volta ele mesmo), ou o `*DNSError`.
  Future<(List<Uint8List>, GoError?)> _ips(String host, String family) async {
    if (host.isEmpty) {
      return (const <Uint8List>[], DNSError(err: _s('no such host'), name: _s(host), isNotFound: true) as GoError);
    }
    final literal = parseIP(_s(host));
    if (literal != null && literal.length != 0) return ([_ipBytes(literal)], null);
    try {
      final ips = await sys.sysLookupIp(host, network: family);
      return (ips, null);
    } on sys.SysDnsError catch (e) {
      return (const <Uint8List>[], _dnsError(e, host) as GoError);
    } on Object catch (e) {
      return (const <Uint8List>[], _sysError(e));
    }
  }

  /// `LookupHost(ctx, host)`.
  Future<(Slice<Golang.String>, GoError?)> lookupHost(context.Context? ctx, Golang.String host) async {
    final (ips, err) = await _ips(host.toString(), 'ip');
    if (err != null) return (Slice<Golang.String>.nil(_strElem), err);
    return (Slice.of([for (final ip in ips) _ipOf(ip).string()], _strElem), null);
  }

  /// `LookupIP(ctx, network, host)`: network `ip`, `ip4` ou `ip6`.
  Future<(Slice<IP>, GoError?)> lookupIP(
    context.Context? ctx,
    Golang.String network,
    Golang.String host,
  ) async {
    final net = network.toString();
    if (!const {'ip', 'ip4', 'ip6'}.contains(net)) {
      return (Slice<IP>.nil(_ipElem), UnknownNetworkError(network) as GoError);
    }
    final (ips, err) = await _ips(host.toString(), net);
    if (err != null) return (Slice<IP>.nil(_ipElem), err);
    return (Slice.of([for (final ip in ips) _ipOf(ip)], _ipElem), null);
  }

  /// `LookupIPAddr(ctx, host)`.
  Future<(Slice<IPAddr>, GoError?)> lookupIPAddr(context.Context? ctx, Golang.String host) async {
    final (ips, err) = await _ips(host.toString(), 'ip');
    if (err != null) return (Slice<IPAddr>.nil(_ipAddrElem), err);
    return (Slice.of([for (final ip in ips) IPAddr(ip: _ipOf(ip))], _ipAddrElem), null);
  }

  /// `LookupNetIP(ctx, network, host)`.
  Future<(Slice<netip.Addr>, GoError?)> lookupNetIP(
    context.Context? ctx,
    Golang.String network,
    Golang.String host,
  ) async {
    final (ips, err) = await lookupIP(ctx, network, host);
    if (err != null) return (Slice<netip.Addr>.nil(_netipElem), err);
    final out = <netip.Addr>[];
    for (var i = 0; i < ips.length; i++) {
      final (a, _) = netip.addrFromSlice(ips[i]);
      out.add(a);
    }
    return (Slice.of(out, _netipElem), null);
  }

  /// `LookupPort(ctx, network, service)`.
  Future<(Golang.Int, GoError?)> lookupPort(
    context.Context? ctx,
    Golang.String network,
    Golang.String service,
  ) => _lookupPortGo(network, service);

  /// `LookupTXT(ctx, name)`: cada registro com as strings concatenadas.
  Future<(Slice<Golang.String>, GoError?)> lookupTXT(context.Context? ctx, Golang.String name) async {
    try {
      final txt = await sys.sysLookupTxt(name.toString());
      return (Slice.of([for (final t in txt) _s(t)], _strElem), null);
    } on sys.SysDnsError catch (e) {
      return (Slice<Golang.String>.nil(_strElem), _dnsError(e, name.toString()) as GoError);
    } on Object catch (e) {
      return (Slice<Golang.String>.nil(_strElem), _sysError(e));
    }
  }
}

Future<(Golang.Int, GoError?)> _lookupPortGo(Golang.String network, Golang.String service) =>
    lookupPort(network, service);

/// `net.DefaultResolver`.
final Resolver defaultResolver = Resolver();

/// `net.LookupHost(host)`.
Future<(Slice<Golang.String>, GoError?)> lookupHost(Golang.String host) =>
    defaultResolver.lookupHost(context.background(), host);

/// `net.LookupIP(host)`.
Future<(Slice<IP>, GoError?)> lookupIP(Golang.String host) =>
    defaultResolver.lookupIP(context.background(), _s('ip'), host);

/// `net.LookupTXT(name)`.
Future<(Slice<Golang.String>, GoError?)> lookupTXT(Golang.String name) =>
    defaultResolver.lookupTXT(context.background(), name);

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);
final _ipElem = Elem<IP>(24, () => IP(Slice.nil(_byteElem)), pointers: true);
final _ipAddrElem = Elem<IPAddr>(40, IPAddr.new, pointers: true, value: true);
final _netipElem = Elem<netip.Addr>(24, netip.Addr.new, pointers: true, value: true);
