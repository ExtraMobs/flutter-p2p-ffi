part of '../../net.dart';

// Nomes (D4). Com `CGO_ENABLED=0` o Go resolve tudo pelo cliente puro; o
// shim faz assim:
// - `Resolver` com `Dial` ou `PreferGo`: todo lookup pelo cliente DNS do Go
//   (`dns_go.dart`, `lookup_go.dart`: /etc/hosts na ordem do nsswitch,
//   resolv.conf, search, ndots), em toda plataforma com rede (o `Dial` do
//   usuário, inclusive no navegador);
// - `LookupHost`/`IP`/`IPAddr`/`NetIP` dos outros Resolvers: o resolvedor do
//   sistema (`sys.sysLookupIp`: `getaddrinfo` na VM, `dns.lookup` no Node);
//   o `DNSError` dele não traz o servidor;
// - `LookupCNAME`/`SRV`/`MX`/`NS`/`TXT`/`Addr`: sempre o cliente do Go,
//   sobre os sockets do shim (VM e Node iguais);
// - portas: a tabela embutida do Go mais o `/etc/services`.
// No navegador, sem `Dial`, toda consulta dá o erro da rede ausente.

/// `func(ctx context.Context, network, address string) (net.Conn, error)`
/// do campo `Resolver.Dial`: sempre suspende (a cor do campo no g2d é
/// própria, `g2d/services/shimfields.py`).
typedef ResolverDial = Future<(Conn?, GoError?)> Function(
  context.Context?,
  Golang.String,
  Golang.String,
);

/// `net.Resolver`.
final class Resolver extends GoStruct<Resolver> {
  Resolver({bool? preferGo, bool? strictErrors, this.dial})
    : preferGo = preferGo ?? false,
      strictErrors = strictErrors ?? false;

  /// `(*Resolver)(nil)` dentro de uma interface.
  static final Resolver $nil = Resolver()..$nilPtr = true;

  bool preferGo;
  bool strictErrors;
  ResolverDial? dial;

  @override
  String get $goType => 'net.Resolver';
  @override
  List<String> get $ptrMethods => const [
    'LookupAddr',
    'LookupCNAME',
    'LookupHost',
    'LookupIP',
    'LookupIPAddr',
    'LookupMX',
    'LookupNS',
    'LookupNetIP',
    'LookupPort',
    'LookupSRV',
    'LookupTXT',
  ];
  @override
  Resolver $copy() =>
      Resolver(preferGo: preferGo, strictErrors: strictErrors, dial: dial);
  @override
  void $set(Resolver o) {
    preferGo = o.preferGo;
    strictErrors = o.strictErrors;
    dial = o.dial;
  }

  @override
  List<Object?> get $fields => [preferGo, strictErrors, dial];
  @override
  List<String> get $fieldNames => const ['PreferGo', 'StrictErrors', 'Dial'];

  /// `(*Resolver)(nil)` vale como o zero.
  Resolver get _r => $nilPtr ? defaultResolver : this;

  /// Os endereços de IP saem do cliente DNS do Go (senão, do sistema).
  bool get _goIP => _r.dial != null || _r.preferGo;

  /// Sem rede (navegador) e sem `Dial`: o erro da rede ausente.
  GoError? get _noNet => _r.dial == null && !sys.sysNetSupported
      ? _sysError(sys.SysError.unsupported('lookup'))
      : null;

  /// `lookupIPAddr(ctx, network, host)`: IP literal volta ele mesmo.
  Future<(List<_IPZ>, GoError?)> _lookupIPAddr(
    context.Context? ctx,
    String network,
    String host,
  ) async {
    if (host.isEmpty)
      return (const <_IPZ>[], _newDNSErr(_errNoSuchHost, host) as GoError);
    final (a, perr) = netip.parseAddr(_gs(host));
    if (perr == null)
      return ([(_u8(IP(a.asSlice()).to16()), a.zone().toString())], null);
    if (ctx != null && ctx.err() != null) {
      return (
        const <_IPZ>[],
        _newDNSError(_mapErr(ctx.err())!, _gs(host), _gs('')) as GoError,
      );
    }
    if (_goIP) {
      try {
        final (ips, _) = await _r._goLookupIPCNAMEOrder(
          ctx,
          network,
          host,
          _hostLookupOrder(),
        );
        return (ips, null);
      } on _DnsFailure catch (e) {
        final err = e.err;
        return (
          const <_IPZ>[],
          err is DNSError
              ? err
              : _newDNSError(_mapErr(err)!, _gs(host), _gs('')),
        );
      }
    }
    try {
      final ips = await sys.sysLookupIp(host, network: _family(network));
      return ([for (final ip in ips) (ip, '')], null);
    } on sys.SysDnsError catch (e) {
      return (const <_IPZ>[], _dnsError(e, host) as GoError);
    } on Object catch (e) {
      return (const <_IPZ>[], _sysError(e));
    }
  }

  /// `internetAddrList` sem porta: os IPs de [host] filtrados pela família
  /// de [afnet] (`ip`, `ip4`, `ip6`).
  Future<(List<_IPZ>, GoError?)> _ipList(
    context.Context? ctx,
    String afnet,
    String host,
  ) async {
    final (ips, err) = await _lookupIPAddr(ctx, afnet, host);
    if (err != null) return (ips, err);
    final out = [
      for (final a in ips)
        if (afnet.endsWith('4')
            ? _isV4(a.$1)
            : afnet.endsWith('6')
            ? a.$1.length == 16 && !_isV4Mapped(a.$1)
            : true)
          a,
    ];
    if (out.isEmpty) {
      return (
        out,
        AddrError(err: _s('no suitable address found'), addr: _s(host))
            as GoError,
      );
    }
    return (out, null);
  }

  /// `LookupHost(ctx, host)`.
  Future<(Slice<Golang.String>, GoError?)> lookupHost(
    context.Context? ctx,
    Golang.String host,
  ) async {
    final h = host.toString();
    final nil = Slice<Golang.String>.nil(_strElem);
    if (h.isEmpty) return (nil, _newDNSErr(_errNoSuchHost, h) as GoError);
    final (_, perr) = netip.parseAddr(host);
    if (perr == null) return (Slice.of([host], _strElem), null);
    if (!_goIP) {
      final (ips, err) = await _lookupIPAddr(ctx, 'ip', h);
      if (err != null) return (nil, err);
      return (
        Slice.of([for (final (ip, _) in ips) _ipOf(ip).string()], _strElem),
        null,
      );
    }
    try {
      final addrs = await _r._goLookupHostOrder(ctx, h, _hostLookupOrder());
      return (Slice.of([for (final a in addrs) _gs(a)], _strElem), null);
    } on _DnsFailure catch (e) {
      return (nil, e.err);
    }
  }

  /// `LookupIP(ctx, network, host)`: network `ip`, `ip4` ou `ip6`.
  Future<(Slice<IP>, GoError?)> lookupIP(
    context.Context? ctx,
    Golang.String network,
    Golang.String host,
  ) async {
    final nil = Slice<IP>.nil(_ipElem);
    final (afnet, nerr) = _ipNetwork(network.toString());
    if (nerr != null) return (nil, nerr);
    final h = host.toString();
    if (h.isEmpty) return (nil, _newDNSErr(_errNoSuchHost, h) as GoError);
    final (ips, err) = await _ipList(ctx, afnet, h);
    if (err != null) return (nil, err);
    return (Slice.of([for (final (ip, _) in ips) _ipOf(ip)], _ipElem), null);
  }

  /// `LookupIPAddr(ctx, host)`.
  Future<(Slice<IPAddr>, GoError?)> lookupIPAddr(
    context.Context? ctx,
    Golang.String host,
  ) async {
    final (ips, err) = await _lookupIPAddr(ctx, 'ip', host.toString());
    if (err != null) return (Slice<IPAddr>.nil(_ipAddrElem), err);
    return (
      Slice.of([
        for (final (ip, z) in ips) IPAddr(ip: _ipOf(ip), zone: _gs(z)),
      ], _ipAddrElem),
      null,
    );
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
      final (a, ok) = netip.addrFromSlice(ips[i]);
      if (ok) out.add(a);
    }
    return (Slice.of(out, _netipElem), null);
  }

  /// `LookupPort(ctx, network, service)`.
  Future<(Golang.Int, GoError?)> lookupPort(
    context.Context? ctx,
    Golang.String network,
    Golang.String service,
  ) => _lookupPortGo(network, service);

  /// `LookupCNAME(ctx, host)`: o nome canônico (pela consulta A/AAAA).
  Future<(Golang.String, GoError?)> lookupCNAME(
    context.Context? ctx,
    Golang.String host,
  ) async {
    final no = _noNet;
    if (no != null) return (Golang.String(), no);
    try {
      final (_, cname) = await _r._goLookupIPCNAMEOrder(
        ctx,
        'CNAME',
        host.toString(),
        _hostLookupOrder(),
      );
      if (!_isDomainName(cname)) {
        return (
          Golang.String(),
          DNSError(err: _s(_errMalformedDNSRecordsDetail), name: host)
              as GoError,
        );
      }
      return (_latin(cname), null);
    } on _DnsFailure catch (e) {
      return (Golang.String(), e.err);
    }
  }

  /// `LookupSRV(ctx, service, proto, name)`: (nome do alvo, registros por
  /// prioridade e embaralhados pelo peso).
  Future<(Golang.String, Slice<SRV?>, GoError?)> lookupSRV(
    context.Context? ctx,
    Golang.String service,
    Golang.String proto,
    Golang.String name,
  ) async {
    final nil = Slice<SRV?>.nil(_srvElem);
    final no = _noNet;
    if (no != null) return (Golang.String(), nil, no);
    try {
      final (cname, srvs) = await _r._goLookupSRV(
        ctx,
        service.toString(),
        proto.toString(),
        name.toString(),
      );
      if (cname.isNotEmpty && !_isDomainName(cname)) {
        return (
          Golang.String(),
          nil,
          DNSError(err: _s('SRV header name is invalid'), name: name)
              as GoError,
        );
      }
      final ok = [
        for (final s in srvs)
          if (_isDomainName(s.target.toString())) s,
      ];
      final out = Slice<SRV?>.of(ok, _srvElem);
      if (ok.length != srvs.length) {
        return (
          _latin(cname),
          out,
          DNSError(err: _s(_errMalformedDNSRecordsDetail), name: name)
              as GoError,
        );
      }
      return (_latin(cname), out, null);
    } on _DnsFailure catch (e) {
      return (Golang.String(), nil, e.err);
    }
  }

  /// `LookupMX(ctx, name)`: por preferência; host que não é nome nem IP sai.
  Future<(Slice<MX?>, GoError?)> lookupMX(
    context.Context? ctx,
    Golang.String name,
  ) async {
    final nil = Slice<MX?>.nil(_mxElem);
    final no = _noNet;
    if (no != null) return (nil, no);
    try {
      final mxs = await _r._goLookupMX(ctx, name.toString());
      final ok = <MX>[];
      for (final mx in mxs) {
        final h = mx.host.toString();
        if (!_isDomainName(h)) {
          final (ip, err) = netip.parseAddr(
            _gs(h.endsWith('.') ? h.substring(0, h.length - 1) : h),
          );
          if (err != null || ip.zone().length != 0) continue;
        }
        ok.add(mx);
      }
      final out = Slice<MX?>.of(ok, _mxElem);
      if (ok.length != mxs.length) {
        return (
          out,
          DNSError(err: _s(_errMalformedDNSRecordsDetail), name: name)
              as GoError,
        );
      }
      return (out, null);
    } on _DnsFailure catch (e) {
      return (nil, e.err);
    }
  }

  /// `LookupNS(ctx, name)`.
  Future<(Slice<NS?>, GoError?)> lookupNS(
    context.Context? ctx,
    Golang.String name,
  ) async {
    final nil = Slice<NS?>.nil(_nsElem);
    final no = _noNet;
    if (no != null) return (nil, no);
    try {
      final nss = await _r._goLookupNS(ctx, name.toString());
      final ok = [
        for (final n in nss)
          if (_isDomainName(n.host.toString())) n,
      ];
      final out = Slice<NS?>.of(ok, _nsElem);
      if (ok.length != nss.length) {
        return (
          out,
          DNSError(err: _s(_errMalformedDNSRecordsDetail), name: name)
              as GoError,
        );
      }
      return (out, null);
    } on _DnsFailure catch (e) {
      return (nil, e.err);
    }
  }

  /// `LookupTXT(ctx, name)`: cada registro com as strings concatenadas.
  Future<(Slice<Golang.String>, GoError?)> lookupTXT(
    context.Context? ctx,
    Golang.String name,
  ) async {
    final nil = Slice<Golang.String>.nil(_strElem);
    final no = _noNet;
    if (no != null) return (nil, no);
    try {
      final txts = await _r._goLookupTXT(ctx, name.toString());
      return (txts.isEmpty ? nil : Slice.of(txts, _strElem), null);
    } on _DnsFailure catch (e) {
      return (nil, e.err);
    }
  }

  /// `LookupAddr(ctx, addr)`: os nomes do IP (`/etc/hosts` e PTR).
  Future<(Slice<Golang.String>, GoError?)> lookupAddr(
    context.Context? ctx,
    Golang.String addr,
  ) async {
    final nil = Slice<Golang.String>.nil(_strElem);
    final no = _noNet;
    if (no != null) return (nil, no);
    try {
      final names = await _r._goLookupPTR(
        ctx,
        addr.toString(),
        _hostLookupOrder(),
      );
      final ok = [
        for (final n in names)
          if (_isDomainName(n)) _latin(n),
      ];
      final out = Slice.of(ok, _strElem);
      if (ok.length != names.length) {
        return (
          out,
          DNSError(err: _s(_errMalformedDNSRecordsDetail), name: addr)
              as GoError,
        );
      }
      return (out, null);
    } on _DnsFailure catch (e) {
      return (nil, e.err);
    }
  }
}

/// `parseNetwork` do `LookupIP`: só `ip`, `ip4`, `ip6` (com `:proto`).
(String, GoError?) _ipNetwork(String network) {
  final i = network.lastIndexOf(':');
  final afnet = i < 0 ? network : network.substring(0, i);
  const ips = {'ip', 'ip4', 'ip6'};
  if (i < 0) {
    const known = {
      'tcp',
      'tcp4',
      'tcp6',
      'udp',
      'udp4',
      'udp6',
      'ip',
      'ip4',
      'ip6',
      'unix',
      'unixgram',
      'unixpacket',
    };
    if (!known.contains(network) || !ips.contains(network))
      return ('', UnknownNetworkError(_gs(network)));
    return (network, null);
  }
  if (!ips.contains(afnet)) return ('', UnknownNetworkError(_gs(network)));
  return (afnet, null);
}

Future<(Golang.Int, GoError?)> _lookupPortGo(
  Golang.String network,
  Golang.String service,
) => lookupPort(network, service);

/// `net.DefaultResolver`.
final Resolver defaultResolver = Resolver();

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);
final _ipElem = Elem<IP>(24, () => IP(Slice.nil(_byteElem)), pointers: true);
final _ipAddrElem = Elem<IPAddr>(40, IPAddr.new, pointers: true, value: true);
final _netipElem = Elem<netip.Addr>(
  24,
  netip.Addr.new,
  pointers: true,
  value: true,
);
