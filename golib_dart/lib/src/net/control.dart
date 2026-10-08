part of '../../net.dart';

// `Dialer.Control`/`ControlContext` e `ListenConfig.Control` (etapa E2 do
// plano D10) e o único `socket()` do Go do shim ([_goSocket];
// `sock_posix.go`, `ipsock_posix.go`, `sockopt_linux.go`) sobre o socket
// cru da rede FFI (`sys.SysSocket`), na mesma ordem: `socket` →
// `IPV6_V6ONLY` (AF_INET6 que não é bruto, erro ignorado) → `SO_BROADCAST`
// (datagrama e bruto fora do Unix) → `SO_REUSEADDR` (escuta de fluxo e
// seqpacket) → `Control` → `bind` → `listen` ou `connect`. O erro do
// `Control` volta sem embrulho dentro do `OpError`, e o socket é fechado.
//
// - TCP discado com `Control`: o socket conectado vai para o `dart:io` pela
//   ponte (`SysSocket.toTcpConn`); daí em diante é uma conexão como as
//   outras.
// - TCP escutando com `Control`: o listener fica no FFI (laço de
//   `accept4`); cada conexão aceita vai para o `dart:io`.
// - UDP (E7), Unix de todos os tipos (E3–E5, `unix.dart`) e IP bruto (E6,
//   `iprawsock_sock.dart`) na VM no linux: sempre por aqui, com ou sem
//   `Control`; a conexão fica no FFI (`SysSocket.toUdpConn`/`toSockConn`).
// - Sem rede FFI (Node, navegador, VM fora do linux; F4): discar com
//   `Control`/`ControlContext` dá `socket: operation not supported`, e
//   escutar ignora o `Control`.

/// `Dialer.Control` e `ListenConfig.Control`: `func(network, address
/// string, c syscall.RawConn) error`. Síncrono (a cor do campo no g2d é
/// fixa, `g2d/services/shimfields.py`), como o Go o chama.
typedef SocketControl = GoError? Function(
  Golang.String network,
  Golang.String address,
  syscall.RawConn? c,
);

/// `Dialer.ControlContext`: `func(ctx context.Context, network, address
/// string, c syscall.RawConn) error`. Síncrono.
typedef SocketControlContext = GoError? Function(
  context.Context? ctx,
  Golang.String network,
  Golang.String address,
  syscall.RawConn? c,
);

/// O `ctrlCtxFn` do Go.
typedef _CtrlFn = GoError? Function(
  context.Context? ctx,
  String network,
  String address,
  syscall.RawConn c,
);

/// O `ctrlCtxFn` de um `Dialer`: `ControlContext` vence `Control`.
_CtrlFn? _dialerCtrl(Dialer d) {
  final cc = d.controlContext;
  if (cc != null) {
    return (ctx, network, address, c) => cc(ctx, _s(network), _s(address), c);
  }
  final c0 = d.control;
  if (c0 != null) {
    return (_, network, address, c) => c0(_s(network), _s(address), c);
  }
  return null;
}

/// O de um `ListenConfig` (que não tem `ControlContext`).
_CtrlFn? _listenCtrl(SocketControl? c0) => c0 == null
    ? null
    : (_, network, address, c) => c0(_s(network), _s(address), c);

/// Erro que vai como está no `Err` do `OpError` (o do `Control`, o
/// `AddrError` do endereço fora da família, o `SyscallError` de uma opção).
final class _GoErr implements Exception {
  const _GoErr(this.err);
  final GoError err;
}

const _afInet = sys.sysAfInet;
const _afInet6 = sys.sysAfInet6;
const _sockStream = sys.sysSockStream;
const _sockDgram = sys.sysSockDgram;

/// `fd.ctrlNetwork()`: a rede com a família (`tcp4`, `udp6`...).
String _ctrlNetwork(String net, int family) {
  if (_unixNets.contains(net)) return net;
  final last = net[net.length - 1];
  if (last == '4' || last == '6') return net;
  return family == _afInet ? '${net}4' : '${net}6';
}

/// `TCPAddr.family()`/`UDPAddr.family()`: IPv4 (inclusive mapeado) e IP
/// vazio são `AF_INET`.
int _ipFamily(Uint8List ip) =>
    ip.length <= 4 || _isV4Mapped(ip) ? _afInet : _afInet6;

/// `favoriteAddrFamily(network, laddr, raddr, mode)` do Go no linux, com a
/// pilha do processo medida como o `ipStackCapabilities` dele.
(int, bool) _favoriteFamily(
  String net,
  sys.SysAddr? laddr,
  sys.SysAddr? raddr,
  String mode,
) {
  switch (net[net.length - 1]) {
    case '4':
      return (_afInet, false);
    case '6':
      return (_afInet6, true);
  }
  if (mode == 'listen' && (laddr == null || laddr.isUnspecified)) {
    final st = sys.sysIpStack();
    if (st.ipv4MappedIPv6 || !st.ipv4) return (_afInet6, false);
    if (laddr == null) return (_afInet, false);
    return (_ipFamily(laddr.ip), false);
  }
  if ((laddr == null || _ipFamily(laddr.ip) == _afInet) &&
      (raddr == null || _ipFamily(raddr.ip) == _afInet)) {
    return (_afInet, false);
  }
  return (_afInet6, false);
}

/// `ipToSockaddr(family, ip, ...)`: o `AddrError` do IP que não cabe na
/// família (IPv6 num socket `AF_INET`), ou `null`.
GoError? _familyError(int family, Uint8List ip) {
  if (family != _afInet || ip.isEmpty) return null;
  final v = _ipOf(ip);
  if (v.to4().length == 4) return null;
  return AddrError(err: _s('non-IPv4 address'), addr: v.string());
}

/// `listenerBacklog()`: o `somaxconn` do sistema (como o Go no linux).
int _listenerBacklog() {
  final text = sys.sysReadFile('/proc/sys/net/core/somaxconn');
  final n = int.tryParse(text?.trim().split(RegExp(r'\s+')).first ?? '');
  // `syscall.SOMAXCONN` sem o arquivo; acima de 2^16 o Go só limita em
  // 2^32 - 1 (kernel >= 4.1).
  return n == null || n <= 0 ? 4096 : n;
}

/// O `socket()` do Go (`sock_posix.go`), o único do shim: devolve o socket
/// com `bind`/`listen` (escuta: só [laddr], fluxo ou seqpacket), só `bind`
/// (datagrama com [laddr] e sem [raddr]) ou `bind`/`connect` (discagem e IP
/// bruto) feitos. [laddrStr]/[raddrStr] são o `String()` que o `Control`
/// recebe. Erros: [_GoErr], `SysError` (`socket`, `bind`, `listen`,
/// `connect`), `SysAddrError`, `SysTimeout`, `SysCanceled`.
Future<sys.SysSocket> _goSocket({
  required context.Context? ctx,
  required String net,
  required int family,
  required int sotype,
  int proto = 0,
  bool ipv6only = false,
  sys.SysAddr? laddr,
  sys.SysAddr? raddr,
  String? laddrStr,
  String? raddrStr,
  _CtrlFn? ctrl,
  DateTime? deadline,
  Future<void>? cancel,
}) async {
  // O `Close` do Go é síncrono: o `bind`/`connect` logo depois tem de ver
  // o socket anterior fechado.
  await sys.sysClosesSettled();
  final s = sys.sysSocket(family, sotype, proto);
  try {
    // `setDefaultSockopts` (erro do `IPV6_V6ONLY` ignorado, como no Go).
    if (family == sys.sysAfInet6 && sotype != sys.sysSockRaw) {
      s.setsockoptInt(
        41 /* IPPROTO_IPV6 */,
        26 /* IPV6_V6ONLY */,
        ipv6only ? 1 : 0,
      );
    }
    if ((sotype == sys.sysSockDgram || sotype == sys.sysSockRaw) &&
        family != sys.sysAfUnix) {
      _sockopt(s.setsockoptInt(1 /* SOL_SOCKET */, 6 /* SO_BROADCAST */, 1));
    }
    void control(String address) {
      if (ctrl == null) return;
      final err = ctrl(
        ctx,
        _ctrlNetwork(net, family),
        address,
        _RawConn(s, net, null, null, () => false),
      );
      if (err != null) throw _GoErr(err);
    }

    void check(sys.SysAddr a) {
      final err = _familyError(family, a.ip);
      if (err != null) throw _GoErr(err);
    }

    if (laddr != null && raddr == null) {
      var la = laddr;
      var laStr = laddrStr ?? '';
      if (sotype == sys.sysSockStream || sotype == sys.sysSockSeqpacket) {
        // `listenStream`.
        _sockopt(s.setsockoptInt(1, 2 /* SO_REUSEADDR */, 1));
        check(la);
        control(laStr);
        s.bind(la);
        s.listen(_listenerBacklog());
        return s;
      }
      if (sotype == sys.sysSockDgram) {
        // `listenDatagram`: multicast UDP escuta no "não especificado" da
        // família.
        if (family != sys.sysAfUnix && _ipOf(la.ip).isMulticast()) {
          _sockopt(s.setsockoptInt(1, 2 /* SO_REUSEADDR */, 1));
          la = sys.SysAddr(
            family == _afInet ? Uint8List(4) : Uint8List(16),
            la.port,
            la.zone,
          );
          laStr =
              (family == _afInet
                      ? UDPAddr(ip: iPv4zero, port: Golang.Int(la.port))
                      : UDPAddr(ip: iPv6unspecified, port: Golang.Int(la.port)))
                  .string()
                  .toString();
        }
        check(la);
        control(laStr);
        s.bind(la);
        return s;
      }
      // IP bruto: o `dial` só com o endereço local.
    }
    // `dial`.
    control(raddr != null ? raddrStr ?? '' : laddrStr ?? '');
    if (laddr != null) {
      check(laddr);
      s.bind(laddr);
    }
    if (raddr != null) {
      check(raddr);
      await s.connect(raddr, deadline: deadline, cancel: cancel);
    }
    return s;
  } catch (_) {
    s.close();
    rethrow;
  }
}

/// `os.NewSyscallError("setsockopt", err)` de uma opção que falhou.
void _sockopt(int r) {
  if (r < 0)
    throw _GoErr(os.newSyscallError(_s('setsockopt'), syscall.Errno(-r))!);
}

/// `x.String()` de um endereço IP do `sys` na rede [net] (o que o Go passa
/// ao `Control`). [emptyHost]: o host do endereço pedido era vazio (o Go
/// tem `IP` nil e imprime `:porta`).
String _addrString(String net, sys.SysAddr a, {bool emptyHost = false}) {
  final v = emptyHost ? sys.SysAddr(Uint8List(0), a.port) : a;
  return _addrFor(net, v).string().toString();
}

/// O host de `host:porta` é vazio.
bool _emptyHost(String address) {
  final (host, _, err) = splitHostPort(_s(address));
  return err == null && host.length == 0;
}

/// Discagem TCP com `Control` (rede FFI): o socket conectado vai para o
/// `dart:io`.
Future<sys.SysTcpConn> _dialTcpGo(
  context.Context? ctx,
  String net,
  sys.SysAddr? laddr,
  sys.SysAddr raddr,
  _CtrlFn? ctrl, {
  DateTime? deadline,
  Future<void>? cancel,
}) async {
  final (family, v6only) = _favoriteFamily(net, laddr, raddr, 'dial');
  final s = await _goSocket(
    ctx: ctx,
    net: net,
    family: family,
    sotype: _sockStream,
    ipv6only: v6only,
    laddr: laddr,
    raddr: raddr,
    laddrStr: laddr == null ? null : _addrString(net, laddr),
    raddrStr: _addrString(net, raddr),
    ctrl: ctrl,
    deadline: deadline,
    cancel: cancel,
  );
  return s.toTcpConn();
}

/// Socket UDP pela ordem do Go (rede FFI): escuta ([raddr] nulo) ou
/// discagem (conectado).
Future<sys.SysUdpConn> _udpGo(
  context.Context? ctx,
  String net,
  sys.SysAddr? laddr,
  sys.SysAddr? raddr,
  _CtrlFn? ctrl, {
  bool emptyHost = false,
}) async {
  final mode = raddr == null ? 'listen' : 'dial';
  // A escuta sempre tem endereço local (`ListenUDP(net, nil)` é `&UDPAddr{}`).
  final la = laddr ?? (raddr == null ? sys.SysAddr(Uint8List(0), 0) : null);
  final (family, v6only) = _favoriteFamily(net, la, raddr, mode);
  final s = await _goSocket(
    ctx: ctx,
    net: net,
    family: family,
    sotype: _sockDgram,
    ipv6only: v6only,
    laddr: la,
    raddr: raddr,
    laddrStr: la == null
        ? null
        : _addrString(net, la, emptyHost: emptyHost || la.ip.isEmpty),
    raddrStr: raddr == null ? null : _addrString(net, raddr),
    ctrl: ctrl,
  );
  return s.toUdpConn();
}

/// Escuta TCP com `Control` (rede FFI): o listener fica no FFI.
Future<sys.SysTcpListener> _listenTcpGo(
  context.Context? ctx,
  String net,
  sys.SysAddr laddr,
  _CtrlFn ctrl, {
  bool emptyHost = false,
}) async {
  final (family, v6only) = _favoriteFamily(net, laddr, null, 'listen');
  final s = await _goSocket(
    ctx: ctx,
    net: net,
    family: family,
    sotype: _sockStream,
    ipv6only: v6only,
    laddr: laddr,
    laddrStr: _addrString(net, laddr, emptyHost: emptyHost),
    ctrl: ctrl,
  );
  return s.toTcpListener();
}
