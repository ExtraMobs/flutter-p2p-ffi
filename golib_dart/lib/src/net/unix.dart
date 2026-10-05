part of '../../net.dart';

// Sockets Unix de fluxo (`unix`): porta de `unixsock.go` e
// `unixsock_posix.go` do Go 1.26 sobre o `sys` da plataforma.
//
// ⚠️ `unixgram` e `unixpacket` não existem (nem o `dart:io` nem o Node têm
// datagrama/seqpacket Unix): toda operação neles devolve o
// `operation not supported` do Go. ⚠️ No navegador, `unix` também.
// ⚠️ `SetUnlinkOnClose(false)` não preserva o arquivo (a plataforma apaga
// o arquivo do socket ao fechá-lo), e `DialUnix` com `laddr` nomeado não
// existe.

/// `*UnixAddr` do caminho de um endereço do `sys`.
UnixAddr _unixAddrOf(sys.SysAddr a, String net) =>
    UnixAddr(name: _s(a.path ?? ''), net: _s(net));

/// `net.UnixConn`: um dos lados de um socket Unix de fluxo.
final class UnixConn extends _NetConn<UnixConn> implements Conn, PacketConn {
  UnixConn._(this._fd, String net, Addr? laddr, Addr? raddr, this._connected)
    : super(net, laddr, raddr);

  /// `(*UnixConn)(nil)` dentro de uma interface.
  static final UnixConn $nil = UnixConn._(null, 'unix', null, null, false)
    ..$nilPtr = true;

  final sys.SysTcpConn? _fd;

  /// `fd.isConnected` do Go: verdadeiro no lado que discou (o aceito não o
  /// é, mesmo num socket de fluxo).
  final bool _connected;

  @override
  String get $goType => 'net.UnixConn';
  @override
  List<String> get $ptrMethods => const [
    'Close',
    'CloseRead',
    'CloseWrite',
    'LocalAddr',
    'Read',
    'ReadFrom',
    'ReadFromUnix',
    'RemoteAddr',
    'SetDeadline',
    'SetReadBuffer',
    'SetReadDeadline',
    'SetWriteBuffer',
    'SetWriteDeadline',
    'Write',
    'WriteTo',
    'WriteToUnix',
  ];
  @override
  UnixConn $copy() => UnixConn._(_fd, _net, _laddr, _raddr, _connected);

  @override
  void _sysClose() => _fd!.close();

  @override
  GoError? _setDeadlines(time.Time t, {bool read = true, bool write = true}) {
    if (_closed) return _opError('set', _net, _laddr, _raddr, errClosed);
    final d = _deadline(t);
    if (read) _fd!.readDeadline = d;
    if (write) _fd!.writeDeadline = d;
    return null;
  }

  /// `Read(b)` síncrono: o socket só lê suspendendo.
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> b) =>
      syncOfAsync('UnixConn.Read');

  /// `Read(b)`: até `len(b)` bytes; EOF quando o outro lado fecha a escrita.
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> b) async {
    if (_closed) return (Golang.Int(0), _op('read', sys.SysClosed()));
    if (b.length == 0) return (Golang.Int(0), null);
    final buf = Uint8List(b.length < _maxRead ? b.length : _maxRead);
    try {
      final n = await _fd!.read(buf);
      if (n == 0) return (Golang.Int(0), io.eof);
      _copyInto(b, buf, n);
      return (Golang.Int(n), null);
    } on Object catch (e) {
      return (Golang.Int(0), _op('read', e));
    }
  }

  /// `Write(b)` síncrono: o socket só escreve suspendendo.
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> b) =>
      syncOfAsync('UnixConn.Write');

  /// `Write(b)`: escreve tudo (ou para no erro, com o que já foi).
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> b) async {
    if (_closed) return (Golang.Int(0), _op('write', sys.SysClosed()));
    if (b.length == 0) return (Golang.Int(0), null);
    try {
      final n = await _fd!.write(_u8(b));
      return (Golang.Int(n), null);
    } on Object catch (e) {
      return (
        Golang.Int(e is sys.SysException ? e.written : 0),
        _op('write', e),
      );
    }
  }

  /// `ReadFromUnix(b)`: num socket de fluxo o `recvfrom` não traz nome, e o
  /// endereço devolvido é nil, como no Go. O `ReadFrom` do Go embrulha até
  /// o EOF num `*OpError` (ao contrário do `Read`).
  Future<(Golang.Int, UnixAddr?, GoError?)> readFromUnix(
    Slice<Golang.Uint8> b,
  ) async {
    final (n, err) = await read$async(b);
    if (err == null) {
      // O `recvfrom` traz o nome do par quando ele tem nome (o lado que
      // discou vê o caminho do listener); sem nome, o Go devolve nil.
      final r = _raddr;
      final named =
          r is UnixAddr && r.name.length != 0 && r.name.toString() != '@';
      return (n, named ? r : null, null);
    }
    return (
      n,
      null,
      err == io.eof ? _opError('read', _net, _laddr, _raddr, io.eof) : err,
    );
  }

  /// `ReadFrom(b)` (`net.PacketConn`).
  @override
  Future<(Golang.Int, Addr?, GoError?)> readFrom(Slice<Golang.Uint8> b) async {
    final (n, a, err) = await readFromUnix(b);
    return (n, a, err);
  }

  /// `WriteToUnix(b, addr)`: um socket de fluxo não tem `sendto`.
  Future<(Golang.Int, GoError?)> writeToUnix(
    Slice<Golang.Uint8> b,
    UnixAddr? addr,
  ) async {
    final nil = addr == null || addr.$nilPtr;
    final err = _writeToError(nil ? null : addr);
    return (
      Golang.Int(0),
      _opError('write', _net, _laddr, nil ? null : addr, err),
    );
  }

  /// `WriteTo(b, addr)` (`net.PacketConn`): addr precisa ser `*UnixAddr`.
  @override
  Future<(Golang.Int, GoError?)> writeTo(
    Slice<Golang.Uint8> b,
    Addr? addr,
  ) async {
    // `addr` nil (interface nil) falha a asserção de tipo do Go: `EINVAL`.
    if (addr is! UnixAddr) {
      return (
        Golang.Int(0),
        _opError(
          'write',
          _net,
          _laddr,
          addr,
          _Errno('EINVAL', 'invalid argument'),
        ),
      );
    }
    return writeToUnix(b, addr);
  }

  /// O erro do `writeTo` do Go: o lado que discou recusa na hora; o aceito
  /// chega ao `sendto`, que num socket de fluxo conectado dá `EISCONN`.
  GoError _writeToError(UnixAddr? addr) {
    if (_connected) return errWriteToConnected;
    if (addr == null) return _errMissingAddress;
    if (addr.net != _s(_net)) {
      return _Errno('EAFNOSUPPORT', 'address family not supported by protocol');
    }
    return os.newSyscallError(
      _s('sendto'),
      _Errno('EISCONN', 'transport endpoint is already connected'),
    )!;
  }

  /// `CloseRead()`.
  GoError? closeRead() {
    if (_closed) return _opError('close', _net, _laddr, _raddr, errClosed);
    _fd!.closeRead();
    return null;
  }

  /// `CloseWrite()`: o outro lado lê EOF.
  GoError? closeWrite() {
    if (_closed) return _opError('close', _net, _laddr, _raddr, errClosed);
    _fd!.closeWrite();
    return null;
  }
}

UnixConn _newUnixConn(sys.SysTcpConn c, String net, {required bool dialed}) =>
    UnixConn._(
      c,
      net,
      _unixAddrOf(c.local, net),
      _unixAddrOf(c.remote, net),
      dialed,
    );

/// `net.UnixListener`.
final class UnixListener extends GoStruct<UnixListener>
    with io.CloserSync
    implements Listener {
  UnixListener._(this._ln, this._net, this._laddr, {bool unlink = true})
    : _unlink = unlink;

  /// `(*UnixListener)(nil)` dentro de uma interface.
  static final UnixListener $nil = UnixListener._(null, 'unix', null)
    ..$nilPtr = true;

  final sys.SysTcpListener? _ln;
  final String _net;
  final UnixAddr? _laddr;
  bool _unlink;
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
  UnixListener $copy() => UnixListener._(_ln, _net, _laddr, unlink: _unlink);
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
  /// pacote `net` que o criou (`SetUnlinkOnClose`).
  @override
  GoError? close() {
    if (_closed) return _op('close', errClosed);
    _closed = true;
    if (!_unlinked) {
      _unlinked = true;
      final path = _laddr?.name.toString() ?? '';
      if (_unlink && !path.startsWith('@')) sys.sysUnlinkUnix(path);
    }
    _ln!.close();
    return null;
  }

  /// `SetDeadline(t)`.
  GoError? setDeadline(time.Time t) {
    if (_closed) return _op('set', errClosed);
    _ln!.deadline = _deadline(t);
    return null;
  }

  /// `SetUnlinkOnClose(unlink)`. ⚠️ `false` não preserva o arquivo: a
  /// plataforma (VM e Node) apaga o arquivo do socket ao fechá-lo.
  void setUnlinkOnClose(bool unlink) => _unlink = unlink;
}

// ------------------------------------------------------------ dial/listen

/// As redes Unix do Go, e quais o shim faz.
const _unixNets = {'unix', 'unixgram', 'unixpacket'};

/// `unixgram`/`unixpacket`: sem datagrama nem seqpacket Unix na plataforma.
GoError? _unixUnsupported(String net) =>
    net == 'unix' ? null : _notSupported('socket');

/// `DialUnix(network, laddr, raddr)`.
Future<(UnixConn?, GoError?)> dialUnix(
  Golang.String network,
  UnixAddr? laddr,
  UnixAddr? raddr,
) async {
  final net = network.toString();
  if (!_unixNets.contains(net)) {
    return (null, _opError('dial', net, laddr, raddr, UnknownNetworkError(network)));
  }
  final (c, err) = await _dialUnix(net, laddr, raddr);
  return (c, err);
}

Future<(UnixConn?, GoError?)> _dialUnix(
  String net,
  UnixAddr? laddr,
  UnixAddr? raddr, {
  DateTime? deadline,
  Future<void>? cancel,
}) async {
  if (raddr == null || raddr.name.length == 0) {
    return (null, _opError('dial', net, laddr, raddr, _errMissingAddress));
  }
  final unsupported = _unixUnsupported(net);
  if (unsupported != null) {
    return (null, _opError('dial', net, laddr, raddr, unsupported));
  }
  // ⚠️ `laddr` nomeado (bind do lado que disca) não existe no shim.
  if (laddr != null && laddr.name.length != 0) {
    return (null, _opError('dial', net, laddr, raddr, _notSupported('socket')));
  }
  try {
    final c = await sys.sysDialUnix(
      raddr.name.toString(),
      deadline: deadline,
      cancel: cancel,
    );
    return (_newUnixConn(c, net, dialed: true), null);
  } on Object catch (e) {
    return (null, _opError('dial', net, null, raddr, _sysError(e)));
  }
}

/// `ListenUnix(network, laddr)`.
Future<(UnixListener?, GoError?)> listenUnix(
  Golang.String network,
  UnixAddr? laddr,
) async {
  final net = network.toString();
  if (net != 'unix' && net != 'unixpacket') {
    return (null, _opError('listen', net, null, laddr, UnknownNetworkError(network)));
  }
  final (ln, err) = await _listenUnix(net, laddr);
  return (ln, err);
}

Future<(UnixListener?, GoError?)> _listenUnix(
  String net,
  UnixAddr? laddr,
) async {
  if (laddr == null || laddr.name.length == 0) {
    return (null, _opError('listen', net, null, laddr, _errMissingAddress));
  }
  final unsupported = _unixUnsupported(net);
  if (unsupported != null) {
    return (null, _opError('listen', net, null, laddr, unsupported));
  }
  try {
    final ln = await sys.sysListenUnix(laddr.name.toString());
    return (UnixListener._(ln, net, _unixAddrOf(ln.local, net)), null);
  } on Object catch (e) {
    return (null, _opError('listen', net, null, laddr, _sysError(e)));
  }
}

/// `ListenUnixgram(network, laddr)`: ⚠️ sem datagrama Unix na plataforma.
Future<(UnixConn?, GoError?)> listenUnixgram(
  Golang.String network,
  UnixAddr? laddr,
) async {
  final net = network.toString();
  if (net != 'unixgram') {
    return (null, _opError('listen', net, null, laddr, UnknownNetworkError(network)));
  }
  return (null, _opError('listen', net, null, laddr, _notSupported('socket')));
}
