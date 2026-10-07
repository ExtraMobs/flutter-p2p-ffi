part of '../../net.dart';

// Sockets Unix (`unix`, `unixgram`, `unixpacket`): `UnixListener` e os
// dials/listens, porta de `unixsock.go`, `unixsock_posix.go` e do
// `socket()` de `sock_posix.go` do Go 1.26. A conexão está em
// `unix_conn.dart`; as mensagens com dados de controle, em `unix_msg.dart`.
//
// Com a rede FFI (VM no linux, `sys.sysSockSupported`) tudo é o socket do
// sistema, como no Go: os três tipos, autobind (`Listen("unix", "")`),
// `laddr` nomeado, nomes abstratos, `SetUnlinkOnClose(false)`. Sem ela (Node,
// VM fora do linux), só `unix` sobre a conexão de fluxo da plataforma
// (autobind e `SetUnlinkOnClose(false)` emulados no Node); ⚠️ `unixgram`,
// `unixpacket` e `laddr` nomeado no dial dão `operation not supported`
// (decisões F4/F5). ⚠️ No navegador, `unix` também.

/// `(*UnixAddr)(nil)` também como `null`.
UnixAddr? _nilUnix(UnixAddr? a) => a == null || a.$nilPtr ? null : a;

/// `SOCK_*` da rede Unix.
int _unixSotype(String net) => switch (net) {
  'unixgram' => sys.sysSockDgram,
  'unixpacket' => sys.sysSockSeqpacket,
  _ => sys.sysSockStream,
};

/// `net.UnixListener`: um socket Unix de fluxo ou seqpacket escutando (ou,
/// com `Listen("unixgram")`, um datagrama, cujo `Accept` falha como no Go).
final class UnixListener extends GoStruct<UnixListener>
    with io.CloserSync
    implements Listener {
  UnixListener._(this._ln, this._net, this._laddr, this._path);

  /// `(*UnixListener)(nil)` dentro de uma interface.
  static final UnixListener $nil = UnixListener._(null, 'unix', null, '')
    ..$nilPtr = true;

  final sys.SysTcpListener? _ln;
  final String _net;
  final UnixAddr? _laddr;

  /// `fd.laddr.String()` (o `path` do Go): o nome que o arquivo tem.
  final String _path;
  bool _unlink = true;
  bool _unlinked = false;
  bool _closed = false;

  @override
  String get $goType => 'net.UnixListener';
  @override
  List<String> get $ptrMethods => const [
    'Accept',
    'AcceptUnix',
    'Addr',
    'Close',
    'SetDeadline',
    'SetUnlinkOnClose',
  ];
  @override
  UnixListener $copy() => UnixListener._(_ln, _net, _laddr, _path)
    .._unlink = _unlink;
  @override
  void $set(UnixListener o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  GoError _op(String op, GoError err) => _opError(op, _net, null, _laddr, err);

  /// `AcceptUnix()`.
  Future<(UnixConn?, GoError?)> acceptUnix() async {
    if (_closed) return (null, _op('accept', errClosed));
    try {
      final c = await _ln!.accept();
      return (_newUnixConn(c, _net, dialed: false), null);
    } on Object catch (e) {
      return (null, _op('accept', _sysError(e)));
    }
  }

  /// `Accept()`.
  @override
  Future<(Conn?, GoError?)> accept() async {
    final (c, err) = await acceptUnix();
    return (err == null ? c : null, err);
  }

  /// `Addr()`.
  @override
  Addr? addr$() => _laddr;

  /// `Close()`: apaga o arquivo do socket antes de fechar, quando foi o
  /// pacote `net` que o criou (`SetUnlinkOnClose`); nome abstrato não tem
  /// arquivo.
  @override
  GoError? close() {
    if (_closed) return _op('close', errClosed);
    _closed = true;
    final named = _path.isNotEmpty && !_path.startsWith('@');
    if (!_unlinked) {
      _unlinked = true;
      if (_unlink && named) sys.sysUnlinkUnix(_path);
    }
    if (_unlink || !named) {
      _ln!.close();
    } else {
      sys.sysCloseKeepingUnixFile(_path, _ln!.close);
    }
    return null;
  }

  /// `SetDeadline(t)`.
  GoError? setDeadline(time.Time t) {
    if (_closed) return _op('set', errClosed);
    _ln!.deadline = _deadline(t);
    return null;
  }

  /// `SetUnlinkOnClose(unlink)`.
  void setUnlinkOnClose(bool unlink) => _unlink = unlink;
}

// ------------------------------------------------------------ dial/listen

/// As redes Unix do Go.
const _unixNets = {'unix', 'unixgram', 'unixpacket'};

/// `DialUnix(network, laddr, raddr)`.
Future<(UnixConn?, GoError?)> dialUnix(
  Golang.String network,
  UnixAddr? laddr,
  UnixAddr? raddr,
) async {
  final net = network.toString();
  final la = _nilUnix(laddr), ra = _nilUnix(raddr);
  if (!_unixNets.contains(net)) {
    return (null, _opError('dial', net, la, ra, UnknownNetworkError(network)));
  }
  final (c, err) = await _dialUnix(net, la, ra);
  return (c, err == null ? null : _opError('dial', net, la, ra, err));
}

/// `sysDialer.dialUnix` (o `unixSocket` em modo dial): o erro sem o
/// `*OpError`, que quem chama monta.
Future<(UnixConn?, GoError?)> _dialUnix(
  String net,
  UnixAddr? laddr,
  UnixAddr? raddr, {
  DateTime? deadline,
  Future<void>? cancel,
}) async {
  // `isWildcard`: nil ou sem nome.
  final l = laddr == null || laddr.name.length == 0 ? null : laddr;
  final r = raddr == null || raddr.name.length == 0 ? null : raddr;
  final sotype = _unixSotype(net);
  if (r == null && (sotype != sys.sysSockDgram || l == null)) {
    return (null, _errMissingAddress);
  }
  if (!sys.sysSockSupported) {
    // Só o fluxo da plataforma, sem nome do lado que disca.
    if (sotype != sys.sysSockStream || l != null) {
      return (null, _notSupported('socket'));
    }
    try {
      final c = await sys.sysDialUnix(
        r!.name.toString(),
        deadline: deadline,
        cancel: cancel,
      );
      return (_newUnixConn(c, net, dialed: true), null);
    } on Object catch (e) {
      return (null, _sysError(e));
    }
  }
  try {
    final s = await sys.sysSocket(
      family: sys.sysAfUnix,
      sotype: sotype,
      laddr: l == null ? null : sys.SysAddr.unix(l.name.toString()),
      raddr: r == null ? null : sys.SysAddr.unix(r.name.toString()),
      deadline: deadline,
      cancel: cancel,
    );
    return (_newUnixConn(s, net, dialed: true), null);
  } on Object catch (e) {
    return (null, _sysError(e));
  }
}

/// `ListenUnix(network, laddr)`.
Future<(UnixListener?, GoError?)> listenUnix(
  Golang.String network,
  UnixAddr? laddr,
) async {
  final net = network.toString();
  final la = _nilUnix(laddr);
  if (net != 'unix' && net != 'unixpacket') {
    return (
      null,
      _opError('listen', net, null, la, UnknownNetworkError(network)),
    );
  }
  if (la == null) {
    return (null, _opError('listen', net, null, null, _errMissingAddress));
  }
  final (ln, err) = await _listenUnix(net, la);
  return (ln, err == null ? null : _opError('listen', net, null, la, err));
}

/// `sysListener.listenUnix`: o erro sem o `*OpError`. Nome vazio é o
/// autobind do linux (um nome abstrato de 5 dígitos hexadecimais).
Future<(UnixListener?, GoError?)> _listenUnix(String net, UnixAddr la) async {
  final sotype = _unixSotype(net);
  if (!sys.sysSockSupported) {
    if (sotype != sys.sysSockStream) return (null, _notSupported('socket'));
    try {
      final ln = await sys.sysListenUnix(la.name.toString());
      final path = ln.local.path ?? '';
      return (UnixListener._(ln, net, _unixAddrOf(ln.local, net), path), null);
    } on Object catch (e) {
      return (null, _sysError(e));
    }
  }
  try {
    final s = await sys.sysSocket(
      family: sys.sysAfUnix,
      sotype: sotype,
      laddr: sys.SysAddr.unix(la.name.toString()),
    );
    final local = s.localAddr;
    return (
      UnixListener._(
        s,
        net,
        local == null ? null : _unixAddrOf(local, _sotypeToNet(sotype)),
        local?.path ?? '',
      ),
      null,
    );
  } on Object catch (e) {
    return (null, _sysError(e));
  }
}

/// `ListenUnixgram(network, laddr)`.
Future<(UnixConn?, GoError?)> listenUnixgram(
  Golang.String network,
  UnixAddr? laddr,
) async {
  final net = network.toString();
  final la = _nilUnix(laddr);
  if (net != 'unixgram') {
    return (
      null,
      _opError('listen', net, null, la, UnknownNetworkError(network)),
    );
  }
  if (la == null) {
    return (null, _opError('listen', net, null, null, _errMissingAddress));
  }
  final (c, err) = await _listenUnixgram(net, la);
  return (c, err == null ? null : _opError('listen', net, null, la, err));
}

/// `sysListener.listenUnixgram` (também o `ListenPacket` de `unix` e
/// `unixpacket`, que no Go devolve um `UnixConn` sobre o socket
/// escutando): o erro sem o `*OpError`.
Future<(UnixConn?, GoError?)> _listenUnixgram(String net, UnixAddr la) async {
  if (!sys.sysSockSupported) return (null, _notSupported('socket'));
  try {
    final s = await sys.sysSocket(
      family: sys.sysAfUnix,
      sotype: _unixSotype(net),
      laddr: sys.SysAddr.unix(la.name.toString()),
    );
    return (_newUnixConn(s, net, dialed: false), null);
  } on Object catch (e) {
    return (null, _sysError(e));
  }
}
