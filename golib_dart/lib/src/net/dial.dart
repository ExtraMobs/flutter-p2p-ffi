part of '../../net.dart';

// `Dial`/`Listen` e a resolução de endereço (porta de `dial.go`,
// `ipsock.go`, `tcpsock.go`, `udpsock.go` do Go 1.26), sobre o `sys`.

// ------------------------------------------------------------ endereços

IP _ipOf(Uint8List b) => IP(Slice.of([for (final x in b) Golang.Uint8(x)], _byteElem));

Uint8List _ipBytes(IP? ip) {
  if (ip == null || ip.length == 0) return Uint8List(0);
  final v4 = ip.to4();
  return _u8(v4.length == 4 ? v4 : ip);
}

TCPAddr? _tcpAddrOf(sys.SysAddr a) =>
    TCPAddr(ip: _ipOf(a.ip), port: Golang.Int(a.port), zone: _s(a.zone));

UDPAddr _udpAddrOf(sys.SysAddr a) =>
    UDPAddr(ip: _ipOf(a.ip), port: Golang.Int(a.port), zone: _s(a.zone));

sys.SysAddr _sysAddrOf(IP? ip, int port, Golang.String zone) =>
    sys.SysAddr(_ipBytes(ip), port, zone.toString());

bool _sameAddr(sys.SysAddr a, UDPAddr b) {
  if (a.port != b.port.toInt()) return false;
  return _ipOf(a.ip).equal(b.ip);
}

/// Família e protocolo da rede (`parseNetwork` do Go, só o que o shim faz).
(String, GoError?) _network(String network, {required bool packet}) {
  const stream = {'tcp', 'tcp4', 'tcp6'};
  const dgram = {'udp', 'udp4', 'udp6'};
  if (stream.contains(network) || dgram.contains(network)) return (network, null);
  // Sockets Unix: `unix.dart` (sem a rede FFI, `unixgram`/`unixpacket`
  // falham lá com `operation not supported`).
  if (_unixNets.contains(network)) return (network, null);
  // Redes IP (`ip4:icmp`...) não chegam aqui: `ipconn.dart`.
  return (network, UnknownNetworkError(_s(network)));
}

/// `ip4`/`ip6`/`ip` da rede, para filtrar a resolução.
String _family(String network) => network.endsWith('4')
    ? 'ip4'
    : network.endsWith('6')
    ? 'ip6'
    : 'ip';

bool _fits(Uint8List ip, String family) => switch (family) {
  'ip4' => ip.isEmpty || ip.length == 4 || _isV4Mapped(ip),
  'ip6' => ip.isEmpty || (ip.length == 16 && !_isV4Mapped(ip)),
  _ => true,
};

bool _isV4Mapped(Uint8List ip) {
  if (ip.length != 16) return false;
  for (var i = 0; i < 10; i++) {
    if (ip[i] != 0) return false;
  }
  return ip[10] == 0xff && ip[11] == 0xff;
}

/// `host:port` → lista de (ip, porta, zona) (`resolveAddrList` do Go).
/// `forDial`: host vazio é o próprio host (o Go disca o "não especificado").
Future<(List<sys.SysAddr>, GoError?)> _resolve(
  String network,
  String address, {
  required String op,
  Resolver? resolver,
  context.Context? ctx,
}) async {
  final (host, port, err) = splitHostPort(_s(address));
  if (err != null) return (const <sys.SysAddr>[], err);
  final (p, perr) = await _lookupPort(network, port.toString());
  if (perr != null) return (const <sys.SysAddr>[], perr);
  final family = _family(network);
  final h = host.toString();
  if (h.isEmpty) {
    final any = family == 'ip6' ? Uint8List(16) : family == 'ip4' ? Uint8List(4) : Uint8List(0);
    return ([sys.SysAddr(any, p)], null);
  }
  // IP literal, com zona IPv6 opcional (`fe80::1%eth0`).
  final pct = h.indexOf('%');
  final literal = parseIP(_s(pct < 0 ? h : h.substring(0, pct)));
  if (literal.length != 0) {
    final b = _ipBytes(literal);
    if (!_fits(b, family)) {
      return (const <sys.SysAddr>[], AddrError(err: _s('no suitable address found'), addr: _s(h)) as GoError);
    }
    return ([sys.SysAddr(b, p, pct < 0 ? '' : h.substring(pct + 1))], null);
  }
  // O `Resolver` do Dialer (`d.resolver()`), ou o do sistema.
  final (ips, lerr) = await (resolver ?? defaultResolver)._lookupIPAddr(ctx, network, h);
  if (lerr != null) return (const <sys.SysAddr>[], lerr);
  final out = [for (final (ip, zone) in ips) if (_fits(ip, family)) sys.SysAddr(ip, p, zone)];
  if (out.isEmpty) {
    return (const <sys.SysAddr>[], AddrError(err: _s('no suitable address found'), addr: _s(h)) as GoError);
  }
  // O Go prefere IPv4 quando a rede não diz a família (`forResolve`).
  if (family == 'ip' && op == 'resolve') {
    out.sort((a, b) => (a.ip.length == 4 ? 0 : 1) - (b.ip.length == 4 ? 0 : 1));
  }
  return (out, null);
}

// ------------------------------------------------------------ Dialer

/// `net.Dialer`. `Control`/`ControlContext` montam o socket pela rede FFI
/// (`control.dart`); sem ela (Node, navegador), discar com eles falha com
/// `socket: operation not supported` (F4).
final class Dialer extends GoStruct<Dialer> {
  Dialer({
    time.Duration? timeout,
    time.Time? deadline,
    this.localAddr,
    bool? dualStack,
    time.Duration? fallbackDelay,
    time.Duration? keepAlive,
    KeepAliveConfig? keepAliveConfig,
    this.resolver,
    this.cancel,
    this.control,
    this.controlContext,
  }) : timeout = timeout ?? time.Duration(),
       deadline = deadline ?? time.Time(),
       dualStack = dualStack ?? false,
       fallbackDelay = fallbackDelay ?? time.Duration(),
       keepAlive = keepAlive ?? time.Duration(),
       keepAliveConfig = keepAliveConfig ?? KeepAliveConfig();

  /// `(*Dialer)(nil)` dentro de uma interface.
  static final Dialer $nil = Dialer()..$nilPtr = true;

  time.Duration timeout;
  time.Time deadline;
  Addr? localAddr;
  bool dualStack;

  /// `FallbackDelay`: espera da família reserva no "Happy Eyeballs" da rede
  /// `tcp` (zero: 300 ms; negativo: desligado).
  time.Duration fallbackDelay;
  time.Duration keepAlive;
  KeepAliveConfig keepAliveConfig;

  /// `Resolver`: quem resolve os nomes (nil: o `DefaultResolver`).
  Resolver? resolver;
  Chan<EmptyStruct>? cancel;

  /// `Control`: chamado com o socket criado, antes do `bind`/`connect`.
  SocketControl? control;

  /// `ControlContext`: como [control], com o `ctx` do `DialContext`; vence
  /// [control] quando os dois existem.
  SocketControlContext? controlContext;

  @override
  String get $goType => 'net.Dialer';
  @override
  List<String> get $ptrMethods => const ['Dial', 'DialContext'];
  @override
  Dialer $copy() => Dialer(
    timeout: timeout,
    deadline: deadline.$copy(),
    localAddr: localAddr,
    dualStack: dualStack,
    fallbackDelay: fallbackDelay,
    keepAlive: keepAlive,
    keepAliveConfig: keepAliveConfig.$copy(),
    resolver: resolver,
    cancel: cancel,
    control: control,
    controlContext: controlContext,
  );
  @override
  void $set(Dialer o) {
    timeout = o.timeout;
    deadline.$set(o.deadline);
    localAddr = o.localAddr;
    dualStack = o.dualStack;
    fallbackDelay = o.fallbackDelay;
    keepAlive = o.keepAlive;
    keepAliveConfig.$set(o.keepAliveConfig);
    resolver = o.resolver;
    cancel = o.cancel;
    control = o.control;
    controlContext = o.controlContext;
  }

  @override
  List<Object?> get $fields => [
    timeout,
    deadline,
    localAddr,
    dualStack,
    fallbackDelay,
    keepAlive,
    keepAliveConfig,
    resolver,
    cancel,
    control,
    controlContext,
  ];
  @override
  List<String> get $fieldNames => const [
    'Timeout',
    'Deadline',
    'LocalAddr',
    'DualStack',
    'FallbackDelay',
    'KeepAlive',
    'KeepAliveConfig',
    'Resolver',
    'Cancel',
    'Control',
    'ControlContext',
  ];

  /// `Dial(network, address)`.
  Future<(Conn?, GoError?)> dial(Golang.String network, Golang.String address) =>
      dialContext(context.background(), network, address);

  /// O prazo mais cedo entre `Deadline`, `Timeout` e o do `ctx`.
  DateTime? _when(context.Context? ctx) {
    DateTime? d = _deadline(deadline);
    if (timeout.toInt() > 0) {
      final t = DateTime.now().toUtc().add(Duration(microseconds: timeout.toInt() ~/ 1000));
      if (d == null || t.isBefore(d)) d = t;
    }
    if (ctx != null) {
      final (cd, ok) = ctx.deadline();
      if (ok) {
        final t = _deadline(cd);
        if (t != null && (d == null || t.isBefore(d))) d = t;
      }
    }
    return d;
  }

  /// `DialContext(ctx, network, address)`.
  Future<(Conn?, GoError?)> dialContext(
    context.Context? ctx,
    Golang.String network,
    Golang.String address,
  ) async {
    final net = network.toString();
    if (_isIPNetwork(net)) {
      return _dialIPNetwork(net, address.toString(), localAddr, ctx: ctx, ctrl: _dialerCtrl(this));
    }
    final (_, nerr) = _network(net, packet: false);
    if (nerr != null) return (null, _opError('dial', net, null, null, nerr));
    if (_unixNets.contains(net)) {
      // `resolveAddrList`: discar exige endereço.
      if (address.length == 0) {
        return (null, _opError('dial', net, null, null, _errMissingAddress));
      }
      final (ua, uerr) = resolveUnixAddr(network, address);
      if (uerr != null) return (null, _opError('dial', net, null, null, uerr));
      final la = localAddr;
      final cancel = _cancelOf(ctx, this.cancel);
      try {
        final (c, err) = await _dialUnix(
          net,
          la is UnixAddr ? _nilUnix(la) : null,
          ua,
          deadline: _when(ctx),
          cancel: cancel.future,
          ctx: ctx,
          ctrl: _dialerCtrl(this),
        );
        return (c, err == null ? null : _opError('dial', net, la, ua, err));
      } finally {
        cancel.stop();
      }
    }
    final (addrs, rerr) = await _resolve(net, address.toString(), op: 'dial', resolver: resolver, ctx: ctx);
    if (rerr != null) return (null, _opError('dial', net, null, null, rerr));
    final sd = _SysDialer(this, ctx, net, _when(ctx));
    final cancel = _cancelOf(ctx, this.cancel);
    try {
      // `dualStack()`: só a rede `tcp` disca as duas famílias em paralelo.
      final (primaries, fallbacks) = fallbackDelay.toInt() >= 0 && net == 'tcp'
          ? _partitionByFamily(addrs)
          : (addrs, const <sys.SysAddr>[]);
      return await sd.dialParallel(cancel, primaries, fallbacks);
    } finally {
      cancel.stop();
    }
  }
}

Addr _addrFor(String net, sys.SysAddr a) =>
    net.startsWith('udp') ? _udpAddrOf(a) : _tcpAddrOf(a)!;

/// O cancelamento do `Dial`: `ctx.Done()` ou o `Dialer.Cancel` fechado, sem
/// contar como goroutine bloqueada (o detector de deadlock não o vê).
final class _Cancel {
  final _c = Completer<void>();
  final _stops = <void Function()>[];
  bool get done => _c.isCompleted;
  Future<void> get future => _c.future;
  void fire() {
    if (!_c.isCompleted) _c.complete();
  }

  void stop() {
    for (final s in _stops) {
      s();
    }
  }
}

_Cancel _cancelOf(context.Context? ctx, Chan<EmptyStruct>? ch) {
  final c = _Cancel();
  void watch(Chan<EmptyStruct>? done) {
    if (done == null) return;
    if (done.$recvReady()) {
      c.fire();
      return;
    }
    c._stops.add(done.$registerRecvWaiter((_, _) => c.fire()));
  }

  if (ctx != null) {
    if (ctx.err() != null) c.fire();
    watch(ctx.done());
  }
  watch(ch);
  return c;
}

/// `net.Dial(network, address)`.
Future<(Conn?, GoError?)> dial(Golang.String network, Golang.String address) =>
    Dialer().dial(network, address);

/// `net.DialTimeout(network, address, timeout)`.
Future<(Conn?, GoError?)> dialTimeout(
  Golang.String network,
  Golang.String address,
  time.Duration timeout,
) => Dialer(timeout: timeout).dial(network, address);

/// `net.DialTCP(network, laddr, raddr)`.
Future<(TCPConn?, GoError?)> dialTCP(
  Golang.String network,
  TCPAddr? laddr,
  TCPAddr? raddr,
) async {
  final net = network.toString();
  if (!const {'tcp', 'tcp4', 'tcp6'}.contains(net)) {
    return (null, _opError('dial', net, laddr, raddr, UnknownNetworkError(network)));
  }
  if (raddr == null) {
    return (null, _opError('dial', net, laddr, null, _errMissingAddress));
  }
  try {
    final fd = await sys.sysDialTcp(
      _sysAddrOf(raddr.ip, raddr.port.toInt(), raddr.zone),
      local: laddr == null ? null : _sysAddrOf(laddr.ip, laddr.port.toInt(), laddr.zone),
    );
    return (_newTCPConn(fd, net), null);
  } on Object catch (e) {
    return (null, _opError('dial', net, laddr, raddr, _sysError(e)));
  }
}

/// `net.DialUDP(network, laddr, raddr)`.
Future<(UDPConn?, GoError?)> dialUDP(
  Golang.String network,
  UDPAddr? laddr,
  UDPAddr? raddr,
) async {
  final net = network.toString();
  if (!const {'udp', 'udp4', 'udp6'}.contains(net)) {
    return (null, _opError('dial', net, laddr, raddr, UnknownNetworkError(network)));
  }
  if (raddr == null) {
    return (null, _opError('dial', net, laddr, null, _errMissingAddress));
  }
  final r = _sysAddrOf(raddr.ip, raddr.port.toInt(), raddr.zone);
  if (sys.sysFfiAvailable) {
    try {
      final fd = await _udpGo(
        context.background(),
        net,
        laddr == null ? null : _sysAddrOf(laddr.ip, laddr.port.toInt(), laddr.zone),
        r,
        null,
      );
      final peer = (fd as sys.SysUdpMsg).remote;
      return (UDPConn._(fd, net, _udpAddrOf(fd.local), _udpAddrOf(peer ?? r)), null);
    } on _GoErr catch (e) {
      return (null, _opError('dial', net, laddr, raddr, e.err));
    } on Object catch (e) {
      return (null, _opError('dial', net, laddr, raddr, _sysError(e)));
    }
  }
  try {
    final local = laddr != null
        ? _sysAddrOf(laddr.ip, laddr.port.toInt(), laddr.zone)
        : sys.SysAddr(r.ip.length == 4 ? Uint8List(4) : Uint8List(16), 0);
    final fd = await sys.sysDialUdp(local, r);
    return (UDPConn._(fd, net, _udpAddrOf(fd.local), _udpAddrOf(r)), null);
  } on Object catch (e) {
    return (null, _opError('dial', net, laddr, raddr, _sysError(e)));
  }
}

// ------------------------------------------------------------ Listen

/// `net.ListenConfig`. `Control` monta o socket pela rede FFI
/// (`control.dart`); sem ela (Node, navegador), é ignorado (F4).
final class ListenConfig extends GoStruct<ListenConfig> {
  ListenConfig({
    this.control,
    time.Duration? keepAlive,
    KeepAliveConfig? keepAliveConfig,
  }) : keepAlive = keepAlive ?? time.Duration(),
       keepAliveConfig = keepAliveConfig ?? KeepAliveConfig();

  /// `(*ListenConfig)(nil)` dentro de uma interface.
  static final ListenConfig $nil = ListenConfig()..$nilPtr = true;

  /// `Control`: chamado com o socket criado, antes do `bind`.
  SocketControl? control;
  time.Duration keepAlive;
  KeepAliveConfig keepAliveConfig;

  @override
  String get $goType => 'net.ListenConfig';
  @override
  List<String> get $ptrMethods => const ['Listen', 'ListenPacket'];
  @override
  ListenConfig $copy() => ListenConfig(
    control: control,
    keepAlive: keepAlive,
    keepAliveConfig: keepAliveConfig.$copy(),
  );
  @override
  void $set(ListenConfig o) {
    control = o.control;
    keepAlive = o.keepAlive;
    keepAliveConfig.$set(o.keepAliveConfig);
  }

  @override
  List<Object?> get $fields => [control, keepAlive, keepAliveConfig];
  @override
  List<String> get $fieldNames => const [
    'Control',
    'KeepAlive',
    'KeepAliveConfig',
  ];

  /// `Listen(ctx, network, address)`.
  Future<(Listener?, GoError?)> listen(
    context.Context? ctx,
    Golang.String network,
    Golang.String address,
  ) async {
    final net = network.toString();
    if (_isIPNetwork(net)) {
      final (_, err) = await _listenIPNetwork(net, address.toString(), packet: false);
      return (null, err);
    }
    final (_, nerr) = _network(net, packet: false);
    if (_unixNets.contains(net)) {
      // `sl.listenUnix` para as três redes (no `unixgram`, o `Accept`
      // falha como no Go).
      final (ua, uerr) = resolveUnixAddr(network, address);
      if (uerr != null) return (null, _opError('listen', net, null, null, uerr));
      final (ln, err) = await _listenUnix(net, ua!, ctx: ctx, ctrl: _listenCtrl(control));
      return (ln, err == null ? null : _opError('listen', net, null, ua, err));
    }
    if (nerr != null || !net.startsWith('tcp')) {
      return (null, _opError('listen', net, null, null, nerr ?? UnknownNetworkError(network)));
    }
    final (addrs, rerr) = await _resolve(net, address.toString(), op: 'listen');
    if (rerr != null) return (null, _opError('listen', net, null, null, rerr));
    final a = addrs.first;
    final ctrl = _listenCtrl(control);
    try {
      final ln = ctrl != null && sys.sysFfiAvailable
          ? await _listenTcpGo(ctx, net, a, ctrl, emptyHost: _emptyHost(address.toString()))
          : await sys.sysListenTcp(a);
      return (
        TCPListener._(ln, net, _tcpAddrOf(ln.local), keepAlive, keepAliveConfig.$copy()) as Listener,
        null,
      );
    } on _GoErr catch (e) {
      return (null, _opError('listen', net, null, _tcpAddrOf(a), e.err));
    } on Object catch (e) {
      return (null, _opError('listen', net, null, _tcpAddrOf(a), _sysError(e)));
    }
  }

  /// `ListenPacket(ctx, network, address)`.
  Future<(PacketConn?, GoError?)> listenPacket(
    context.Context? ctx,
    Golang.String network,
    Golang.String address,
  ) async {
    final net = network.toString();
    if (_isIPNetwork(net)) {
      final (c, err) = await _listenIPNetwork(net, address.toString(), packet: true, ctx: ctx, ctrl: _listenCtrl(control));
      return (c as PacketConn?, err);
    }
    final (_, nerr) = _network(net, packet: true);
    if (_unixNets.contains(net)) {
      // `sl.listenUnixgram` para as três redes (`unix`: um `UnixConn` sobre
      // o socket escutando, como no Go).
      final (ua, uerr) = resolveUnixAddr(network, address);
      if (uerr != null) return (null, _opError('listen', net, null, null, uerr));
      final (c, err) = await _listenUnixgram(net, ua!, ctx: ctx, ctrl: _listenCtrl(control));
      return (c, err == null ? null : _opError('listen', net, null, ua, err));
    }
    if (nerr != null || !net.startsWith('udp')) {
      return (null, _opError('listen', net, null, null, nerr ?? UnknownNetworkError(network)));
    }
    final (addrs, rerr) = await _resolve(net, address.toString(), op: 'listen');
    if (rerr != null) return (null, _opError('listen', net, null, null, rerr));
    final a = addrs.first;
    try {
      final fd = sys.sysFfiAvailable
          ? await _udpGo(ctx, net, a, null, _listenCtrl(control), emptyHost: _emptyHost(address.toString()))
          : await sys.sysListenUdp(a);
      return (UDPConn._(fd, net, _udpAddrOf(fd.local), null) as PacketConn, null);
    } on _GoErr catch (e) {
      return (null, _opError('listen', net, null, _udpAddrOf(a), e.err));
    } on Object catch (e) {
      return (null, _opError('listen', net, null, _udpAddrOf(a), _sysError(e)));
    }
  }
}

/// `net.Listen(network, address)`.
Future<(Listener?, GoError?)> listen(Golang.String network, Golang.String address) =>
    ListenConfig().listen(context.background(), network, address);

/// `net.ListenPacket(network, address)`.
Future<(PacketConn?, GoError?)> listenPacket(Golang.String network, Golang.String address) =>
    ListenConfig().listenPacket(context.background(), network, address);

/// `net.ListenTCP(network, laddr)`.
Future<(TCPListener?, GoError?)> listenTCP(Golang.String network, TCPAddr? laddr) async {
  final net = network.toString();
  if (!const {'tcp', 'tcp4', 'tcp6'}.contains(net)) {
    return (null, _opError('listen', net, null, laddr, UnknownNetworkError(network)));
  }
  final a = laddr == null
      ? sys.SysAddr(Uint8List(net == 'tcp4' ? 4 : net == 'tcp6' ? 16 : 0), 0)
      : _sysAddrOf(laddr.ip, laddr.port.toInt(), laddr.zone);
  try {
    final ln = await sys.sysListenTcp(a);
    return (TCPListener._(ln, net, _tcpAddrOf(ln.local)), null);
  } on Object catch (e) {
    return (null, _opError('listen', net, null, laddr, _sysError(e)));
  }
}

/// `net.ListenUDP(network, laddr)`.
Future<(UDPConn?, GoError?)> listenUDP(Golang.String network, UDPAddr? laddr) async {
  final net = network.toString();
  if (!const {'udp', 'udp4', 'udp6'}.contains(net)) {
    return (null, _opError('listen', net, null, laddr, UnknownNetworkError(network)));
  }
  final a = laddr == null
      ? sys.SysAddr(Uint8List(net == 'udp4' ? 4 : net == 'udp6' ? 16 : 0), 0)
      : _sysAddrOf(laddr.ip, laddr.port.toInt(), laddr.zone);
  try {
    final fd = sys.sysFfiAvailable
        ? await _udpGo(context.background(), net, a, null, null)
        : await sys.sysListenUdp(a);
    return (UDPConn._(fd, net, _udpAddrOf(fd.local), null), null);
  } on _GoErr catch (e) {
    return (null, _opError('listen', net, null, laddr, e.err));
  } on Object catch (e) {
    return (null, _opError('listen', net, null, laddr, _sysError(e)));
  }
}

// ------------------------------------------------------------ Resolve*Addr

/// `net.ResolveTCPAddr(network, address)`.
Future<(TCPAddr?, GoError?)> resolveTCPAddr(Golang.String network, Golang.String address) async {
  final net = network.toString();
  if (!const {'tcp', 'tcp4', 'tcp6', ''}.contains(net)) return (null, UnknownNetworkError(network) as GoError);
  final (addrs, err) = await _resolve(net.isEmpty ? 'tcp' : net, address.toString(), op: 'resolve');
  if (err != null) return (null, err);
  return (_tcpAddrOf(addrs.first), null);
}

/// `net.ResolveUDPAddr(network, address)`.
Future<(UDPAddr?, GoError?)> resolveUDPAddr(Golang.String network, Golang.String address) async {
  final net = network.toString();
  if (!const {'udp', 'udp4', 'udp6', ''}.contains(net)) return (null, UnknownNetworkError(network) as GoError);
  final (addrs, err) = await _resolve(net.isEmpty ? 'udp' : net, address.toString(), op: 'resolve');
  if (err != null) return (null, err);
  return (_udpAddrOf(addrs.first), null);
}
