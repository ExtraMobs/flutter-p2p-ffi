part of '../../net.dart';

// As consultas do resolvedor puro do Go (`dnsclient_unix.go`, `lookup.go`)
// sobre o cliente de `dns_go.dart`: endereços (arquivos e DNS na ordem do
// nsswitch, A/AAAA em paralelo, nome canônico), PTR, SRV, MX, NS e TXT.

/// Endereço resolvido: IP (4 ou 16 bytes) e zona.
typedef _IPZ = (Uint8List, String);

/// `splitHostZone`.
(String, String) _splitHostZone(String s) {
  final i = s.lastIndexOf('%');
  return i > 0 ? (s.substring(0, i), s.substring(i + 1)) : (s, '');
}

/// `goLookupIPFiles(name)`: (endereços do `/etc/hosts`, nome canônico).
Future<(List<_IPZ>, String)> _goLookupIPFiles(String name) async {
  final (addr, canonical) = _lookupStaticHost(name);
  final addrs = <_IPZ>[];
  for (final h in addr) {
    final (host, zone) = _splitHostZone(h);
    final ip = parseIP(_gs(host));
    if (ip.length != 0) addrs.add((_u8(ip), zone));
  }
  await _sortByRFC6724(addrs);
  return (addrs, canonical);
}

extension on Resolver {
  /// `goLookupHostOrder`: os endereços em texto.
  Future<List<String>> _goLookupHostOrder(
    context.Context? ctx,
    String name,
    _HostLookupOrder order,
  ) async {
    if (order == _HostLookupOrder.filesDNS || order == _HostLookupOrder.files) {
      final (addrs, _) = _lookupStaticHost(name);
      if (addrs.isNotEmpty) return addrs;
      if (order == _HostLookupOrder.files)
        throw _DnsFailure(_newDNSErr(_errNoSuchHost, name));
    }
    final (ips, _) = await _goLookupIPCNAMEOrder(ctx, 'ip', name, order);
    return [for (final (ip, _) in ips) _ipOf(ip).string().toString()];
  }

  /// `goLookupIPCNAMEOrder`: (endereços, nome canônico).
  Future<(List<_IPZ>, String)> _goLookupIPCNAMEOrder(
    context.Context? ctx,
    String network,
    String name,
    _HostLookupOrder order,
  ) async {
    if (order == _HostLookupOrder.filesDNS || order == _HostLookupOrder.files) {
      final (addrs, canonical) = await _goLookupIPFiles(name);
      if (addrs.isNotEmpty) return (addrs, canonical);
      if (order == _HostLookupOrder.files)
        throw _DnsFailure(_newDNSErr(_errNoSuchHost, name));
    }
    if (!_isDomainName(name))
      throw _DnsFailure(_newDNSErr(_errNoSuchHost, name));
    final conf = _systemDNSConfig();
    var qtypes = [dns.rrTypeA, dns.rrTypeAAAA];
    if (network == 'CNAME') qtypes.add(dns.rrTypeCNAME);
    if (network.endsWith('4')) qtypes = [dns.rrTypeA];
    if (network.endsWith('6')) qtypes = [dns.rrTypeAAAA];
    Future<(_DnsResult?, GoError?)> query(String fqdn, int qtype) async {
      try {
        return (await _tryOneName(ctx, conf, fqdn, qtype), null);
      } on _DnsFailure catch (e) {
        return (null, e.err);
      }
    }

    final addrs = <_IPZ>[];
    var cname = '';
    GoError? lastErr;
    for (final fqdn in conf.nameList(name)) {
      // Sem `single-request`, as consultas saem juntas (goroutines no Go).
      final pending = conf.singleRequest
          ? null
          : [for (final t in qtypes) query(fqdn, t)];
      var hitStrictError = false;
      for (var k = 0; k < qtypes.length; k++) {
        final (res, err) = pending != null
            ? await pending[k]
            : await query(fqdn, qtypes[k]);
        if (err != null) {
          if (err is Error && err.temporary() && this.strictErrors) {
            hitStrictError = true;
            lastErr = err;
          } else if (lastErr == null || fqdn == '$name.') {
            lastErr = err; // prefere o erro do nome original
          }
          continue;
        }
        final (p, server) = res!;
        for (final r in p.answers.records) {
          try {
            switch (r.type) {
              case dns.rrTypeA:
                addrs.add((r.a, ''));
                if (cname.isEmpty && r.name.isNotEmpty) cname = r.name;
              case dns.rrTypeAAAA:
                addrs.add((r.aaaa, ''));
                if (cname.isEmpty && r.name.isNotEmpty) cname = r.name;
              case dns.rrTypeCNAME:
                final c = r.target;
                if (cname.isEmpty && c.isNotEmpty) cname = c;
            }
          } on FormatException {
            lastErr = _dnsErr('cannot unmarshal DNS message', name, server);
            break;
          }
        }
        if (p.answers.broken)
          lastErr = _dnsErr('cannot unmarshal DNS message', name, server);
      }
      if (hitStrictError) {
        // Um erro com StrictErrors descarta tudo (pilha dupla pela metade).
        addrs.clear();
        break;
      }
      if (addrs.isNotEmpty || network == 'CNAME' && cname.isNotEmpty) break;
    }
    if (lastErr is DNSError) lastErr.name = _gs(name);
    await _sortByRFC6724(addrs);
    if (addrs.isEmpty && !(network == 'CNAME' && cname.isNotEmpty)) {
      if (order == _HostLookupOrder.dnsFiles) {
        final (fa, canonical) = await _goLookupIPFiles(name);
        if (fa.isNotEmpty) return (fa, canonical);
      }
      if (lastErr != null) throw _DnsFailure(lastErr);
    }
    return (addrs, cname);
  }

  /// `goLookupPTR(ctx, addr, order)`.
  Future<List<String>> _goLookupPTR(
    context.Context? ctx,
    String addr,
    _HostLookupOrder order,
  ) async {
    if (order == _HostLookupOrder.files || order == _HostLookupOrder.filesDNS) {
      final names = _lookupStaticAddr(addr);
      if (names.isNotEmpty) return names;
      if (order == _HostLookupOrder.files)
        throw _DnsFailure(_newDNSErr(_errNoSuchHost, addr));
    }
    final arpa = _reverseaddr(addr);
    final _DnsResult res;
    try {
      res = await _lookupDNS(ctx, arpa, dns.rrTypePTR);
    } on _DnsFailure catch (e) {
      final err = e.err;
      if (err is DNSError &&
          err.isNotFound &&
          order == _HostLookupOrder.dnsFiles) {
        final names = _lookupStaticAddr(addr);
        if (names.isNotEmpty) return names;
      }
      rethrow;
    }
    final (p, server) = res;
    return _decode(p, dns.rrTypePTR, addr, server, (r) => r.target);
  }

  /// `goLookupSRV`: (nome do primeiro registro, registros ordenados).
  Future<(String, List<SRV>)> _goLookupSRV(
    context.Context? ctx,
    String service,
    String proto,
    String name,
  ) async {
    final target = service.isEmpty && proto.isEmpty
        ? name
        : '_$service._$proto.$name';
    final (p, server) = await _lookupDNS(ctx, target, dns.rrTypeSRV);
    var cname = '';
    final srvs = _decode(p, dns.rrTypeSRV, name, server, (r) {
      if (cname.isEmpty && r.name.isNotEmpty) cname = r.name;
      final (prio, weight, port, t) = r.srv;
      return SRV(
        target: _latin(t),
        port: Golang.Uint16(port),
        priority: Golang.Uint16(prio),
        weight: Golang.Uint16(weight),
      );
    });
    _sortSRV(srvs);
    return (cname, srvs);
  }

  /// `goLookupMX`.
  Future<List<MX>> _goLookupMX(context.Context? ctx, String name) async {
    final (p, server) = await _lookupDNS(ctx, name, dns.rrTypeMX);
    final mxs = _decode(p, dns.rrTypeMX, name, server, (r) {
      final (pref, host) = r.mx;
      return MX(host: _latin(host), pref: Golang.Uint16(pref));
    });
    _sortMX(mxs);
    return mxs;
  }

  /// `goLookupNS`.
  Future<List<NS>> _goLookupNS(context.Context? ctx, String name) async {
    final (p, server) = await _lookupDNS(ctx, name, dns.rrTypeNS);
    return _decode(
      p,
      dns.rrTypeNS,
      name,
      server,
      (r) => NS(host: _latin(r.target)),
    );
  }

  /// `goLookupTXT`: as character-strings de cada registro concatenadas.
  Future<List<Golang.String>> _goLookupTXT(
    context.Context? ctx,
    String name,
  ) async {
    final (p, server) = await _lookupDNS(ctx, name, dns.rrTypeTXT);
    return _decode(p, dns.rrTypeTXT, name, server, (r) {
      final b = BytesBuilder();
      for (final s in r.txt) {
        b.add(s);
      }
      return Golang.String.fromBytes(b.takeBytes());
    });
  }
}

/// Os registros de [qtype] da resposta, lidos por [f]; registro malformado
/// é o `*DNSError` "cannot unmarshal DNS message".
List<T> _decode<T>(
  dns.DnsMessage p,
  int qtype,
  String name,
  String server,
  T Function(dns.DnsRR) f,
) {
  final out = <T>[];
  for (final r in _answersOf(p, qtype, name, server)) {
    try {
      out.add(f(r));
    } on FormatException {
      throw _DnsFailure(_dnsErr('cannot unmarshal DNS message', name, server));
    }
  }
  return out;
}

/// Nome do fio (um caractere por byte) como string Go.
Golang.String _latin(String s) =>
    Golang.String.fromBytes(Uint8List.fromList(s.codeUnits));
