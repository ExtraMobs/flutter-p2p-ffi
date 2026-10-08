part of '../../net.dart';

// `net.IPConn` (`iprawsock.go` e `iprawsock_posix.go` do Go 1.26); a rede,
// a resolução e o `DialIP`/`ListenIP` estão em `iprawsock.dart` e
// `iprawsock_sock.dart`.

/// `net.IPConn`: socket de IP bruto (`SOCK_RAW`) pela rede FFI (VM no
/// linux; exige privilégio, como no Go). O valor zero (`&net.IPConn{}`) não
/// tem descritor: todo método age como no Go com `c.ok()` falso (`EINVAL`,
/// endereços nil; pânico de nil sobre `(*IPConn)(nil)`).
final class IPConn extends GoStruct<IPConn>
    with io.CloserSync
    implements Conn, PacketConn, syscall.Conn, _BuffersWriter {
  IPConn() : _fd = null, _net = '', _laddr = null, _raddr = null;

  IPConn._(sys.SysSockConn this._fd, this._net, this._laddr, this._raddr);

  /// `(*IPConn)(nil)` dentro de uma interface.
  static final IPConn $nil = IPConn()..$nilPtr = true;

  final sys.SysSockConn? _fd;

  /// `fd.net`: a família sem o protocolo (`ip4`, `ip6`, `ip`).
  final String _net;
  final IPAddr? _laddr;
  final IPAddr? _raddr;
  bool _closed = false;

  @override
  String get $goType => 'net.IPConn';
  @override
  List<String> get $ptrMethods => const [
    'Close',
    'LocalAddr',
    'Read',
    'ReadFrom',
    'ReadFromIP',
    'ReadMsgIP',
    'RemoteAddr',
    'SetDeadline',
    'SetReadBuffer',
    'SetReadDeadline',
    'SetWriteBuffer',
    'SetWriteDeadline',
    'SyscallConn',
    'Write',
    'WriteMsgIP',
    'WriteTo',
    'WriteToIP',
  ];
  @override
  IPConn $copy() =>
      _fd == null ? IPConn() : IPConn._(_fd, _net, _laddr, _raddr);
  @override
  void $set(IPConn o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  static final _zero = Golang.Int(0);

  /// `!c.ok()`: sem descritor é `EINVAL`; `(*IPConn)(nil)` desreferencia
  /// nil (o `ok` do `conn` embutido), como no Go. `null` com descritor.
  GoError? get _bad {
    if ($nilPtr) nilDeref();
    return _fd == null ? syscall.einval : null;
  }

  GoError _op(String op, Object e) =>
      _opError(op, _net, _laddr, _raddr, e is GoError ? e : _sysError(e));

  /// `writeBuffers(v)` (`buffers.dart`).
  @override
  Future<(Golang.Int64, GoError?)> _writeBuffers(Buffers$Ptr v) =>
      _writeBuffersVia(v, _fd, _closed, write$async, _op);

  /// Opção/prazo: fechado é `ErrClosed` no `*OpError` de `set`.
  GoError? _set(void Function(sys.SysSockConn fd) f) {
    final bad = _bad;
    if (bad != null) return bad;
    if (_closed) return _op('set', errClosed);
    f(_fd!);
    return null;
  }

  /// `Close()`.
  @override
  GoError? close() {
    final bad = _bad;
    if (bad != null) return bad;
    if (_closed) return _op('close', errClosed);
    _closed = true;
    _fd!.close();
    return null;
  }

  /// `LocalAddr()`.
  @override
  Addr? localAddr() => $nilPtr ? nilDeref() : _laddr;

  /// `RemoteAddr()`.
  @override
  Addr? remoteAddr() => $nilPtr ? nilDeref() : _raddr;

  /// `SetDeadline(t)`.
  @override
  GoError? setDeadline(time.Time t) => _set((fd) {
    fd.readDeadline = _deadline(t);
    fd.writeDeadline = _deadline(t);
  });

  /// `SetReadDeadline(t)`.
  @override
  GoError? setReadDeadline(time.Time t) =>
      _set((fd) => fd.readDeadline = _deadline(t));

  /// `SetWriteDeadline(t)`.
  @override
  GoError? setWriteDeadline(time.Time t) =>
      _set((fd) => fd.writeDeadline = _deadline(t));

  /// `SetReadBuffer(bytes)`: dica aceita e ignorada.
  GoError? setReadBuffer(Golang.Int bytes) => _set((_) {});

  /// `SetWriteBuffer(bytes)`: dica aceita e ignorada.
  GoError? setWriteBuffer(Golang.Int bytes) => _set((_) {});

  /// `SyscallConn()`: o `rawConn` do Go sobre o fd real (`rawconn.dart`).
  @override
  (syscall.RawConn?, GoError?) syscallConn() {
    final bad = _bad;
    if (bad != null) return (null, bad);
    return (_RawConn(_fd!, _net, _laddr, _raddr, () => _closed), null);
  }

  /// `Read(b)` síncrono (o g2d chama a forma `$async`).
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> b) {
    final bad = _bad;
    if (bad != null) return (_zero, bad);
    return syncOfAsync('IPConn.Read');
  }

  /// `Read(b)`: o datagrama inteiro, com o cabeçalho IPv4 (só o `ReadFrom`
  /// o tira, como no Go); 0 bytes não é EOF.
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> b) async {
    final bad = _bad;
    if (bad != null) return (_zero, bad);
    if (_closed) return (_zero, _op('read', errClosed));
    if (b.length == 0) return (_zero, null);
    final buf = Uint8List(b.length);
    try {
      final n = await _fd!.read(buf);
      _copyInto(b, buf, n);
      return (Golang.Int(n), null);
    } on Object catch (e) {
      return (_zero, _op('read', e));
    }
  }

  /// `Write(b)` síncrono (o g2d chama a forma `$async`).
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> b) {
    final bad = _bad;
    if (bad != null) return (_zero, bad);
    return syncOfAsync('IPConn.Write');
  }

  /// `Write(b)`: um datagrama para o par conectado.
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> b) async {
    final bad = _bad;
    if (bad != null) return (_zero, bad);
    if (_closed) return (_zero, _op('write', errClosed));
    try {
      return (Golang.Int(await _fd!.write(_u8(b))), null);
    } on Object catch (e) {
      return (_zero, _op('write', e));
    }
  }

  /// `ReadFromIP(b)`: sem o cabeçalho IPv4 (`stripIPv4Header`).
  Future<(Golang.Int, IPAddr?, GoError?)> readFromIP(
    Slice<Golang.Uint8> b,
  ) async {
    final bad = _bad;
    if (bad != null) return (_zero, null, bad);
    if (_closed) return (_zero, null, _op('read', errClosed));
    final buf = Uint8List(b.length);
    try {
      final (n, from) = await _fd!.readFrom(buf);
      _copyInto(b, buf, n);
      if (from == null) return (Golang.Int(n), null, null);
      final addr = IPAddr(ip: _ipOf(from.ip), zone: _s(from.zone));
      final k = from.ip.length == 4 ? _stripIPv4Header(n, b) : n;
      return (Golang.Int(k), addr, null);
    } on Object catch (e) {
      return (_zero, null, _op('read', e));
    }
  }

  /// `ReadFrom(b)` (`net.PacketConn`).
  @override
  Future<(Golang.Int, Addr?, GoError?)> readFrom(Slice<Golang.Uint8> b) async {
    final (n, a, err) = await readFromIP(b);
    return (n, a, err);
  }

  /// `ReadMsgIP(b, oob)`: o datagrama com o cabeçalho (como o `Read`).
  Future<(Golang.Int, Golang.Int, Golang.Int, IPAddr?, GoError?)> readMsgIP(
    Slice<Golang.Uint8> b,
    Slice<Golang.Uint8> oob,
  ) async {
    final bad = _bad;
    if (bad != null) return (_zero, _zero, _zero, null, bad);
    if (_closed) return (_zero, _zero, _zero, null, _op('read', errClosed));
    final buf = Uint8List(b.length), ob = Uint8List(oob.length);
    try {
      final (n, oobn, flags, from) = await _fd!.readMsg(buf, ob, 0);
      _copyInto(b, buf, n < b.length ? n : b.length);
      _copyInto(oob, ob, oobn);
      final addr = from == null
          ? null
          : IPAddr(ip: _ipOf(from.ip), zone: _s(from.zone));
      return (Golang.Int(n), Golang.Int(oobn), Golang.Int(flags), addr, null);
    } on Object catch (e) {
      return (_zero, _zero, _zero, null, _op('read', e));
    }
  }

  /// O `writeTo`/`writeMsg` do Go até o destino: o erro, ou o endereço.
  (sys.SysAddr?, GoError?) _dest(IPAddr? addr) {
    if (_fd!.isConnected) return (null, errWriteToConnected);
    if (addr == null) return (null, _errMissingAddress);
    return (_sysAddrOf(addr.ip, 0, addr.zone), null);
  }

  /// `WriteToIP(b, addr)`.
  Future<(Golang.Int, GoError?)> writeToIP(
    Slice<Golang.Uint8> b,
    IPAddr? addr,
  ) async {
    final bad = _bad;
    if (bad != null) return (_zero, bad);
    final to = addr == null || addr.$nilPtr ? null : addr;
    GoError fail(Object e) =>
        _opError('write', _net, _laddr, to, e is GoError ? e : _sysError(e));
    if (_closed) return (_zero, fail(errClosed));
    final (dest, err) = _dest(to);
    if (err != null) return (_zero, fail(err));
    try {
      return (Golang.Int(await _fd!.writeTo(_u8(b), dest!)), null);
    } on Object catch (e) {
      return (_zero, fail(e));
    }
  }

  /// `WriteTo(b, addr)` (`net.PacketConn`): addr precisa ser `*IPAddr`.
  @override
  Future<(Golang.Int, GoError?)> writeTo(
    Slice<Golang.Uint8> b,
    Addr? addr,
  ) async {
    final bad = _bad;
    if (bad != null) return (_zero, bad);
    if (addr is! IPAddr) {
      return (_zero, _opError('write', _net, _laddr, addr, syscall.einval));
    }
    return writeToIP(b, addr);
  }

  /// `WriteMsgIP(b, oob, addr)`.
  Future<(Golang.Int, Golang.Int, GoError?)> writeMsgIP(
    Slice<Golang.Uint8> b,
    Slice<Golang.Uint8> oob,
    IPAddr? addr,
  ) async {
    final bad = _bad;
    if (bad != null) return (_zero, _zero, bad);
    final to = addr == null || addr.$nilPtr ? null : addr;
    GoError fail(Object e) =>
        _opError('write', _net, _laddr, to, e is GoError ? e : _sysError(e));
    if (_closed) return (_zero, _zero, fail(errClosed));
    final (dest, err) = _dest(to);
    if (err != null) return (_zero, _zero, fail(err));
    try {
      final (n, oobn) = await _fd!.writeMsg(_u8(b), _u8(oob), dest);
      return (Golang.Int(n), Golang.Int(oobn), null);
    } on Object catch (e) {
      return (_zero, _zero, fail(e));
    }
  }
}

/// `stripIPv4Header(n, b)` do Go: tira o cabeçalho IPv4 do começo de `b`
/// (todo o buffer anda, como o `copy(b, b[l:])`).
int _stripIPv4Header(int n, Slice<Golang.Uint8> b) {
  if (b.length < 20) return n;
  final l = (b[0].toInt() & 0x0f) << 2;
  if (20 > l || l > b.length) return n;
  if (b[0].toInt() >> 4 != 4) return n;
  for (var i = 0; i + l < b.length; i++) {
    b[i] = b[i + l];
  }
  return n - l;
}
