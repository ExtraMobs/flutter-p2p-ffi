part of '../../net.dart';

// Conexões de verdade (D4): `Conn`, `Listener`, `PacketConn` e os tipos
// `TCPConn`, `TCPListener`, `UDPConn` sobre o `sys` da plataforma.
//
// Cor (D2/D4, `g2d/services/dualio.py`): `Read`/`Write` de conexão sempre
// suspendem (a forma síncrona cai no `fatal` `g2d:` de [syncOfAsync], que o
// g2d nunca chama); `Accept`, `ReadFrom`/`WriteTo` de datagrama só existem
// como `Future`; `Close`, endereços e deadlines nunca suspendem.

/// `net.Conn`. No Dart é também as interfaces do `io` que o method set satisfaz
/// (`ReadWriter`, `ReadWriteCloser`...): no Go vira qualquer uma sem conversão.
abstract interface class Conn
    implements
        io.ReadWriter,
        io.ReadCloser,
        io.WriteCloser,
        io.ReadWriteCloser {
  Addr? localAddr();
  Addr? remoteAddr();
  GoError? setDeadline(time.Time t);
  GoError? setReadDeadline(time.Time t);
  GoError? setWriteDeadline(time.Time t);
}

/// `net.Listener`.
abstract interface class Listener implements io.Closer {
  Future<(Conn?, GoError?)> accept();
  Addr? addr$();
}

/// `net.PacketConn`.
abstract interface class PacketConn implements io.Closer {
  Future<(Golang.Int, Addr?, GoError?)> readFrom(Slice<Golang.Uint8> p);
  Future<(Golang.Int, GoError?)> writeTo(Slice<Golang.Uint8> p, Addr? addr);
  Addr? localAddr();
  GoError? setDeadline(time.Time t);
  GoError? setReadDeadline(time.Time t);
  GoError? setWriteDeadline(time.Time t);
}

/// Maior leitura de uma vez (um `Read` curto é válido no Go).
const _maxRead = 1 << 18;

/// `time.Time` zero é "sem deadline".
DateTime? _deadline(time.Time t) => t.isZero()
    ? null
    : DateTime.fromMicrosecondsSinceEpoch(t.unixMicro().toInt(), isUtc: true);

Uint8List _u8(Slice<Golang.Uint8> p, [int? n]) {
  final len = n ?? p.length;
  final out = Uint8List(len);
  for (var i = 0; i < len; i++) {
    out[i] = p[i].toInt();
  }
  return out;
}

void _copyInto(Slice<Golang.Uint8> p, Uint8List src, int n) {
  for (var i = 0; i < n; i++) {
    p[i] = Golang.Uint8(src[i]);
  }
}

/// Os métodos que o `conn` do Go dá a todo tipo de conexão.
abstract base class _NetConn<T extends _NetConn<T>> extends GoStruct<T>
    with io.CloserSync {
  _NetConn(this._net, this._laddr, this._raddr);

  /// `tcp`, `udp`... (o `fd.net` do Go).
  final String _net;
  final Addr? _laddr;
  final Addr? _raddr;
  bool _closed = false;

  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
  @override
  void $set(T o) {}

  void _sysClose();

  /// Muda o deadline de leitura e/ou escrita (vale para a op pendente).
  GoError? _setDeadlines(time.Time t, {bool read = true, bool write = true});

  GoError _op(String op, Object e) =>
      _opError(op, _net, _laddr, _raddr, _sysError(e));

  /// `LocalAddr()`.
  Addr? localAddr() => _laddr;

  /// `RemoteAddr()`.
  Addr? remoteAddr() => _raddr;

  /// `Close()`: as operações pendentes terminam com `ErrClosed`.
  @override
  GoError? close() {
    if (_closed) return _opError('close', _net, _laddr, _raddr, errClosed);
    _closed = true;
    _sysClose();
    return null;
  }

  /// `SetDeadline(t)`.
  GoError? setDeadline(time.Time t) => _setDeadlines(t);

  /// `SetReadDeadline(t)`.
  GoError? setReadDeadline(time.Time t) => _setDeadlines(t, write: false);

  /// `SetWriteDeadline(t)`.
  GoError? setWriteDeadline(time.Time t) => _setDeadlines(t, read: false);

  /// `SetReadBuffer`/`SetWriteBuffer`: o tamanho é do sistema (aceito e
  /// ignorado, como dica que é).
  GoError? setReadBuffer(Golang.Int bytes) =>
      _closed ? _opError('set', _net, _laddr, _raddr, errClosed) : null;
  GoError? setWriteBuffer(Golang.Int bytes) =>
      _closed ? _opError('set', _net, _laddr, _raddr, errClosed) : null;
}

/// `net.TCPConn`.
final class TCPConn extends _NetConn<TCPConn>
    implements Conn, io.ReaderFrom, io.WriterTo {
  TCPConn._(this._fd, String net, Addr? laddr, Addr? raddr)
    : super(net, laddr, raddr);

  /// `(*TCPConn)(nil)` dentro de uma interface.
  static final TCPConn $nil = TCPConn._(null, 'tcp', null, null)
    ..$nilPtr = true;

  final sys.SysTcpConn? _fd;

  @override
  String get $goType => 'net.TCPConn';
  @override
  List<String> get $ptrMethods => const [
    'Close',
    'CloseRead',
    'CloseWrite',
    'LocalAddr',
    'Read',
    'ReadFrom',
    'RemoteAddr',
    'SetDeadline',
    'SetKeepAlive',
    'SetKeepAlivePeriod',
    'SetLinger',
    'SetNoDelay',
    'SetReadBuffer',
    'SetReadDeadline',
    'SetWriteBuffer',
    'SetWriteDeadline',
    'Write',
    'WriteTo',
  ];
  @override
  TCPConn $copy() => TCPConn._(_fd, _net, _laddr, _raddr);

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
      syncOfAsync('TCPConn.Read');

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
      syncOfAsync('TCPConn.Write');

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

  /// `SetNoDelay(noDelay)`.
  GoError? setNoDelay(bool noDelay) {
    if (_closed) return _opError('set', _net, _laddr, _raddr, errClosed);
    _fd!.setNoDelay(noDelay);
    return null;
  }

  /// `SetKeepAlive(keepalive)`.
  GoError? setKeepAlive(bool keepalive) {
    if (_closed) return _opError('set', _net, _laddr, _raddr, errClosed);
    _fd!.setKeepAlive(keepalive);
    return null;
  }

  /// `SetKeepAlivePeriod(d)`: ⚠️ o período é do sistema (só liga).
  GoError? setKeepAlivePeriod(time.Duration d) => setKeepAlive(true);

  /// `SetLinger(sec)`: ⚠️ aceito e ignorado (o `Close` é sempre imediato).
  GoError? setLinger(Golang.Int sec) =>
      _closed ? _opError('set', _net, _laddr, _raddr, errClosed) : null;

  /// `ReadFrom(r)` síncrono (o socket só escreve suspendendo).
  @override
  (Golang.Int64, GoError?) readFrom(io.Reader? r) =>
      syncOfAsync('TCPConn.ReadFrom');

  /// `ReadFrom(r)` (`io.ReaderFrom`): copia r para a conexão.
  @override
  Future<(Golang.Int64, GoError?)> readFrom$async(io.Reader? r) =>
      io.copy$async(_ConnWriter(this), r);

  /// `WriteTo(w)` síncrono (o socket só lê suspendendo).
  @override
  (Golang.Int64, GoError?) writeTo(io.Writer? w) =>
      syncOfAsync('TCPConn.WriteTo');

  /// `WriteTo(w)` (`io.WriterTo`): copia a conexão para w até o EOF.
  @override
  Future<(Golang.Int64, GoError?)> writeTo$async(io.Writer? w) =>
      io.copy$async(w, _ConnReader(this));
}

/// A conexão só como `io.Writer`/`io.Reader` (sem `ReadFrom`/`WriteTo`):
/// o `io.Copy` de dentro de `TCPConn.ReadFrom` não volta para ele, como o
/// `genericReadFrom` do Go.
final class _ConnWriter with io.WriterSync implements io.Writer {
  _ConnWriter(this.c);
  final TCPConn c;
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) => c.write(p);
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> p) =>
      c.write$async(p);
}

final class _ConnReader with io.ReaderSync implements io.Reader {
  _ConnReader(this.c);
  final TCPConn c;
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) => c.read(p);
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) =>
      c.read$async(p);
}

/// `net.TCPListener`.
final class TCPListener extends GoStruct<TCPListener>
    with io.CloserSync
    implements Listener {
  TCPListener._(this._ln, this._net, this._laddr);

  /// `(*TCPListener)(nil)` dentro de uma interface.
  static final TCPListener $nil = TCPListener._(null, 'tcp', null)
    ..$nilPtr = true;

  final sys.SysTcpListener? _ln;
  final String _net;
  final TCPAddr? _laddr;
  bool _closed = false;

  @override
  String get $goType => 'net.TCPListener';
  @override
  List<String> get $ptrMethods => const [
    'Accept',
    'AcceptTCP',
    'Addr',
    'Close',
    'SetDeadline',
  ];
  @override
  TCPListener $copy() => TCPListener._(_ln, _net, _laddr);
  @override
  void $set(TCPListener o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  GoError _op(String op, GoError err) => _opError(op, _net, null, _laddr, err);

  /// `AcceptTCP()`.
  Future<(TCPConn?, GoError?)> acceptTCP() async {
    if (_closed) return (null, _op('accept', errClosed));
    try {
      final c = await _ln!.accept();
      return (_newTCPConn(c, _net), null);
    } on Object catch (e) {
      return (null, _op('accept', _sysError(e)));
    }
  }

  /// `Accept()`.
  @override
  Future<(Conn?, GoError?)> accept() async {
    final (c, err) = await acceptTCP();
    return (err == null ? c : null, err);
  }

  /// `Addr()`.
  @override
  Addr? addr$() => _laddr;

  /// `Close()`.
  @override
  GoError? close() {
    if (_closed) return _op('close', errClosed);
    _closed = true;
    _ln!.close();
    return null;
  }

  /// `SetDeadline(t)`.
  GoError? setDeadline(time.Time t) {
    if (_closed) return _op('set', errClosed);
    _ln!.deadline = _deadline(t);
    return null;
  }
}

TCPConn _newTCPConn(sys.SysTcpConn c, String net) {
  // O Go liga o keepalive (15s) em toda conexão TCP nova.
  c.setKeepAlive(true);
  return TCPConn._(c, net, _tcpAddrOf(c.local), _tcpAddrOf(c.remote));
}

/// `net.UDPConn`: socket de datagramas; com destino fixo (`DialUDP`), lê só
/// o que vem dele e `Write` envia para ele.
final class UDPConn extends _NetConn<UDPConn> implements Conn, PacketConn {
  UDPConn._(this._fd, String net, Addr? laddr, this._peer)
    : super(net, laddr, _peer);

  /// `(*UDPConn)(nil)` dentro de uma interface.
  static final UDPConn $nil = UDPConn._(null, 'udp', null, null)
    ..$nilPtr = true;

  final sys.SysUdpConn? _fd;
  final UDPAddr? _peer;

  @override
  String get $goType => 'net.UDPConn';
  @override
  List<String> get $ptrMethods => const [
    'Close',
    'LocalAddr',
    'Read',
    'ReadFrom',
    'ReadFromUDP',
    'ReadFromUDPAddrPort',
    'RemoteAddr',
    'SetDeadline',
    'SetReadBuffer',
    'SetReadDeadline',
    'SetWriteBuffer',
    'SetWriteDeadline',
    'Write',
    'WriteTo',
    'WriteToUDP',
    'WriteToUDPAddrPort',
  ];
  @override
  UDPConn $copy() => UDPConn._(_fd, _net, _laddr, _peer);

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

  /// Um datagrama; com destino fixo, descarta o que vem de outro endereço.
  Future<(int, sys.SysAddr)> _recv(Uint8List buf) async {
    while (true) {
      final (n, from) = await _fd!.readFrom(buf);
      final peer = _peer;
      if (peer == null || _sameAddr(from, peer)) return (n, from);
    }
  }

  /// `ReadFromUDP(b)`.
  Future<(Golang.Int, UDPAddr?, GoError?)> readFromUDP(
    Slice<Golang.Uint8> b,
  ) async {
    if (_closed) return (Golang.Int(0), null, _op('read', sys.SysClosed()));
    final buf = Uint8List(b.length);
    try {
      final (n, from) = await _recv(buf);
      _copyInto(b, buf, n);
      return (Golang.Int(n), _udpAddrOf(from), null);
    } on Object catch (e) {
      return (Golang.Int(0), null, _op('read', e));
    }
  }

  /// `ReadFrom(b)` (`net.PacketConn`).
  @override
  Future<(Golang.Int, Addr?, GoError?)> readFrom(Slice<Golang.Uint8> b) async {
    final (n, a, err) = await readFromUDP(b);
    return (n, a, err);
  }

  /// `ReadFromUDPAddrPort(b)`.
  Future<(Golang.Int, netip.AddrPort, GoError?)> readFromUDPAddrPort(
    Slice<Golang.Uint8> b,
  ) async {
    final (n, a, err) = await readFromUDP(b);
    return (n, a == null ? netip.AddrPort() : a.addrPort(), err);
  }

  /// `Read(b)` síncrono: o socket só lê suspendendo.
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> b) =>
      syncOfAsync('UDPConn.Read');

  /// `Read(b)`: um datagrama (truncado em `len(b)`).
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> b) async {
    final (n, _, err) = await readFromUDP(b);
    return (n, err);
  }

  /// `WriteToUDP(b, addr)`.
  Future<(Golang.Int, GoError?)> writeToUDP(
    Slice<Golang.Uint8> b,
    UDPAddr? addr,
  ) async {
    if (_closed) return (Golang.Int(0), _op('write', sys.SysClosed()));
    if (_peer != null) {
      return (
        Golang.Int(0),
        _opError('write', _net, _laddr, addr, errWriteToConnected),
      );
    }
    if (addr == null) {
      return (
        Golang.Int(0),
        _opError('write', _net, _laddr, null, _errMissingAddress),
      );
    }
    return _send(b, addr);
  }

  Future<(Golang.Int, GoError?)> _send(
    Slice<Golang.Uint8> b,
    UDPAddr to,
  ) async {
    try {
      final n = await _fd!.writeTo(
        _u8(b),
        _sysAddrOf(to.ip, to.port.toInt(), to.zone),
      );
      return (Golang.Int(n), null);
    } on Object catch (e) {
      return (Golang.Int(0), _opError('write', _net, _laddr, to, _sysError(e)));
    }
  }

  /// `WriteTo(b, addr)` (`net.PacketConn`): addr precisa ser `*UDPAddr`.
  @override
  Future<(Golang.Int, GoError?)> writeTo(
    Slice<Golang.Uint8> b,
    Addr? addr,
  ) async {
    if (addr is! UDPAddr?) {
      return (
        Golang.Int(0),
        _opError('write', _net, _laddr, addr, _invalidAddr(addr)),
      );
    }
    return writeToUDP(b, addr);
  }

  /// `WriteToUDPAddrPort(b, addr)`.
  Future<(Golang.Int, GoError?)> writeToUDPAddrPort(
    Slice<Golang.Uint8> b,
    netip.AddrPort addr,
  ) => writeToUDP(b, udpAddrFromAddrPort(addr));

  /// `Write(b)` síncrono: o socket só escreve suspendendo.
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> b) =>
      syncOfAsync('UDPConn.Write');

  /// `Write(b)`: um datagrama para o destino fixo.
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> b) async {
    if (_closed) return (Golang.Int(0), _op('write', sys.SysClosed()));
    final peer = _peer;
    if (peer == null) {
      return (
        Golang.Int(0),
        _opError('write', _net, _laddr, null, _errMissingAddress),
      );
    }
    return _send(b, peer);
  }
}

GoError _invalidAddr(Addr addr) =>
    AddrError(err: _s('invalid address type'), addr: addr.string());
