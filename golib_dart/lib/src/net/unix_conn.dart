part of '../../net.dart';

// `net.UnixConn` (`unixsock.go`/`unixsock_posix.go` do Go 1.26) sobre o
// `sys` da plataforma. Com a rede FFI (VM no linux) a conexão é um
// `sys.SysSockConn` de qualquer tipo (`unix`, `unixgram`, `unixpacket`) e tudo
// é o `netFD` do Go; sem ela (Node, VM fora do linux), só fluxo, sobre a
// conexão de fluxo da plataforma, com o resto emulado ou recusado com
// `operation not supported` (`unix_msg.dart`).

/// `*UnixAddr` do caminho de um endereço do `sys`.
UnixAddr _unixAddrOf(sys.SysAddr a, String net) =>
    UnixAddr(name: _s(a.path ?? ''), net: _s(net));

/// `sotypeToNet` do Go.
String _sotypeToNet(int sotype) => switch (sotype) {
  sys.sysSockDgram => 'unixgram',
  sys.sysSockSeqpacket => 'unixpacket',
  _ => 'unix',
};

/// `net.UnixConn`: um socket Unix conectado, aceito ou de datagrama.
final class UnixConn extends _NetConn<UnixConn>
    implements Conn, PacketConn, syscall.Conn {
  UnixConn._(this._fd, String net, Addr? laddr, Addr? raddr, this._connected)
    : super(net, laddr, raddr);

  /// `(*UnixConn)(nil)` dentro de uma interface.
  static final UnixConn $nil = UnixConn._(null, 'unix', null, null, false)
    ..$nilPtr = true;

  /// A conexão da plataforma; com a rede FFI, um [sys.SysSockConn].
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
    'ReadMsgUnix',
    'RemoteAddr',
    'SetDeadline',
    'SetReadBuffer',
    'SetReadDeadline',
    'SetWriteBuffer',
    'SetWriteDeadline',
    'SyscallConn',
    'Write',
    'WriteMsgUnix',
    'WriteTo',
    'WriteToUnix',
  ];
  @override
  UnixConn $copy() => UnixConn._(_fd, _net, _laddr, _raddr, _connected);

  /// O socket genérico (rede FFI), ou `null` (fluxo da plataforma).
  sys.SysSockConn? get _sock {
    final fd = _fd;
    return fd is sys.SysSockConn ? fd : null;
  }

  /// `SOCK_*` do socket.
  int get _sotype => _sock?.sotype ?? sys.sysSockStream;

  /// `ZeroReadIsEOF` do Go: 0 bytes é EOF fora do datagrama.
  bool get _zeroIsEof => _sotype != sys.sysSockDgram;

  @override
  void _sysClose() => _fd!.close();

  /// Com a rede FFI, o fd real do socket; sem ela, o descritor virtual
  /// (`rawconn.dart`).
  @override
  Object? get _sysSocket => _fd;

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

  /// `Read(b)`: até `len(b)` bytes (um datagrama/mensagem, truncado, fora
  /// do fluxo); EOF quando o outro lado fecha a escrita (ou, no seqpacket,
  /// manda uma mensagem vazia).
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> b) async {
    if (_closed) return (Golang.Int(0), _op('read', sys.SysClosed()));
    if (b.length == 0) return (Golang.Int(0), null);
    final buf = Uint8List(b.length < _maxRead ? b.length : _maxRead);
    try {
      final n = await _fd!.read(buf);
      if (n == 0 && _zeroIsEof) return (Golang.Int(0), io.eof);
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

  /// `Write(b)`: escreve tudo no fluxo; uma mensagem no datagrama e no
  /// seqpacket (inclusive a vazia).
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> b) async {
    if (_closed) return (Golang.Int(0), _op('write', sys.SysClosed()));
    if (b.length == 0 && _sotype == sys.sysSockStream) {
      return (Golang.Int(0), null);
    }
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

  /// `ReadFromUnix(b)`: o remetente com nome vira o endereço; sem nome,
  /// nil. Ao contrário do `Read`, até o EOF volta num `*OpError`.
  Future<(Golang.Int, UnixAddr?, GoError?)> readFromUnix(
    Slice<Golang.Uint8> b,
  ) async {
    final sock = _sock;
    if (sock == null) return _readFromStream(this, b);
    if (_closed) return (Golang.Int(0), null, _op('read', sys.SysClosed()));
    final buf = Uint8List(b.length);
    try {
      final (n, from) = await sock.readFrom(buf);
      _copyInto(b, buf, n);
      final name = from?.path ?? '';
      final addr = name.isEmpty
          ? null
          : UnixAddr(name: _s(name), net: _s(_sotypeToNet(_sotype)));
      if (n == 0 && _zeroIsEof) {
        return (
          Golang.Int(0),
          addr,
          _opError('read', _net, _laddr, _raddr, io.eof),
        );
      }
      return (Golang.Int(n), addr, null);
    } on Object catch (e) {
      return (Golang.Int(0), null, _op('read', e));
    }
  }

  /// `ReadFrom(b)` (`net.PacketConn`).
  @override
  Future<(Golang.Int, Addr?, GoError?)> readFrom(Slice<Golang.Uint8> b) async {
    final (n, a, err) = await readFromUnix(b);
    return (n, a, err);
  }

  /// `WriteToUnix(b, addr)`: `sendto` para `addr`.
  Future<(Golang.Int, GoError?)> writeToUnix(
    Slice<Golang.Uint8> b,
    UnixAddr? addr,
  ) async {
    final to = addr == null || addr.$nilPtr ? null : addr;
    if (_closed) {
      return (Golang.Int(0), _opError('write', _net, _laddr, to, errClosed));
    }
    final sock = _sock;
    final GoError err;
    if (_connected) {
      err = errWriteToConnected;
    } else if (to == null) {
      err = _errMissingAddress;
    } else if (to.net.toString() != _sotypeToNet(_sotype)) {
      err = syscall.eafnosupport;
    } else if (sock == null) {
      // Fluxo da plataforma, aceito: o `sendto` com destino num socket de
      // fluxo conectado.
      err = os.newSyscallError(_s('sendto'), syscall.eisconn)!;
    } else {
      try {
        final n = await sock.writeTo(_u8(b), sys.SysAddr.unix('${to.name}'));
        return (Golang.Int(n), null);
      } on Object catch (e) {
        return (
          Golang.Int(0),
          _opError('write', _net, _laddr, to, _sysError(e)),
        );
      }
    }
    return (Golang.Int(0), _opError('write', _net, _laddr, to, err));
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
        _opError('write', _net, _laddr, addr, syscall.einval),
      );
    }
    return writeToUnix(b, addr);
  }

  /// `ReadMsgUnix(b, oob)`: `(n, oobn, flags, addr, err)` (`unix_msg.dart`).
  Future<(Golang.Int, Golang.Int, Golang.Int, UnixAddr?, GoError?)> readMsgUnix(
    Slice<Golang.Uint8> b,
    Slice<Golang.Uint8> oob,
  ) => _readMsgUnix(this, b, oob);

  /// `WriteMsgUnix(b, oob, addr)`: `(n, oobn, err)` (`unix_msg.dart`).
  Future<(Golang.Int, Golang.Int, GoError?)> writeMsgUnix(
    Slice<Golang.Uint8> b,
    Slice<Golang.Uint8> oob,
    UnixAddr? addr,
  ) => _writeMsgUnix(this, b, oob, addr);

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

/// `newUnixConn` do Go: os endereços do socket, com a rede pelo tipo dele.
UnixConn _newUnixConn(sys.SysTcpConn c, String net, {required bool dialed}) {
  if (c is sys.SysSockConn) {
    final n = _sotypeToNet(c.sotype);
    final l = c.localAddr, r = c.remoteAddr;
    return UnixConn._(
      c,
      net,
      l == null ? null : _unixAddrOf(l, n),
      r == null ? null : _unixAddrOf(r, n),
      c.isConnected,
    );
  }
  return UnixConn._(
    c,
    net,
    _unixAddrOf(c.local, net),
    _unixAddrOf(c.remote, net),
    dialed,
  );
}
