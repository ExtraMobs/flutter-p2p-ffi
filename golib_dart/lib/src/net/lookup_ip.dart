part of '../../net.dart';

// Os IPs de um nome para o `Resolver` (`lookupIPAddr`/`internetAddrList` do
// Go): o cliente DNS do Go com `Dial`/`PreferGo`, senão o resolvedor do
// sistema. Extensão para o `Resolver` caber em `lookup.dart`.

extension _ResolverIP on Resolver {
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
    // `lookupGroup.DoChan(network + "\0" + host)`: a consulta roda num ctx
    // que só guarda os valores (o cancelamento de um não derruba os outros).
    final group = _lookupGroups[_r] ??= {};
    final key = '$network\x00$host';
    var f = group[key];
    if (f != null) {
      f.dups++;
    } else {
      final (gctx, gcancel) = context.withCancel(
        ctx == null ? context.background() : context.withoutCancel(ctx),
      );
      final fl = f = group[key] = _Flight(gcancel);
      final run = _lookupIPRaw(gctx, network, host);
      run.whenComplete(() {
        if (identical(group[key], fl)) group.remove(key);
        fl.cancel();
      }).ignore();
      fl.done.complete(run);
    }
    final stop = _cancelOf(ctx, null);
    final res = await Future.any([
      f.done.future,
      stop.future.then((_) => null),
    ]);
    stop.stop();
    if (res != null) return res;
    // `ForgetUnshared`: sozinho, a consulta é esquecida e cancelada.
    if (f.dups == 0 && identical(group[key], f)) {
      group.remove(key);
      f.cancel();
    }
    return (
      const <_IPZ>[],
      _newDNSError(_mapErr(ctx!.err())!, _gs(host), _gs('')) as GoError,
    );
  }

  /// O `lookupIP` do `Resolver`, sem o `singleflight`.
  Future<(List<_IPZ>, GoError?)> _lookupIPRaw(
    context.Context? ctx,
    String network,
    String host,
  ) async {
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
}

/// O `singleflight.Group` (`lookupGroup`) de cada `Resolver`.
final _lookupGroups = Expando<Map<String, _Flight>>();

/// Uma consulta em voo do `singleflight`: [dups] conta quem se juntou.
final class _Flight {
  _Flight(this.cancel);
  final context.CancelFunc cancel;
  final done = Completer<(List<_IPZ>, GoError?)?>();
  int dups = 0;
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

/// O `lookupPort` do pacote (dentro do `Resolver` o nome é o método).
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
