part of '../../net.dart';

// `net.IPConn` (`iprawsock.go` do Go 1.26); a rede, a resolução e o
// `DialIP`/`ListenIP` estão em `iprawsock.dart`.

/// `net.IPConn`. ⚠️ Sem socket bruto, nenhuma `IPConn` do shim tem um
/// descritor: todo método age como no Go com `c.ok()` falso (`EINVAL`,
/// endereços nil; pânico de nil sobre `(*IPConn)(nil)`). O tipo existe para type switch, embutimento e
/// assinaturas.
final class IPConn extends GoStruct<IPConn>
    with io.CloserSync
    implements Conn, PacketConn, syscall.Conn {
  IPConn();

  /// `(*IPConn)(nil)` dentro de uma interface.
  static final IPConn $nil = IPConn()..$nilPtr = true;

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
  IPConn $copy() => IPConn();
  @override
  void $set(IPConn o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  static final _zero = Golang.Int(0);

  /// `!c.ok()`: sem descritor é `EINVAL`; `(*IPConn)(nil)` desreferencia
  /// nil (o `ok` do `conn` embutido), como no Go.
  GoError get _einval {
    if ($nilPtr) nilDeref();
    return syscall.einval;
  }

  /// `Close()`.
  @override
  GoError? close() => _einval;

  /// `LocalAddr()`.
  @override
  Addr? localAddr() => $nilPtr ? nilDeref() : null;

  /// `RemoteAddr()`.
  @override
  Addr? remoteAddr() => $nilPtr ? nilDeref() : null;

  /// `SetDeadline(t)`.
  @override
  GoError? setDeadline(time.Time t) => _einval;

  /// `SetReadDeadline(t)`.
  @override
  GoError? setReadDeadline(time.Time t) => _einval;

  /// `SetWriteDeadline(t)`.
  @override
  GoError? setWriteDeadline(time.Time t) => _einval;

  /// `SetReadBuffer(bytes)`.
  GoError? setReadBuffer(Golang.Int bytes) => _einval;

  /// `SetWriteBuffer(bytes)`.
  GoError? setWriteBuffer(Golang.Int bytes) => _einval;

  /// `SyscallConn()`.
  @override
  (syscall.RawConn?, GoError?) syscallConn() => (null, _einval);

  /// `Read(b)` síncrono (o g2d chama a forma `$async`).
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> b) => (_zero, _einval);

  /// `Read(b)`.
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> b) async =>
      read(b);

  /// `Write(b)` síncrono (o g2d chama a forma `$async`).
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> b) => (_zero, _einval);

  /// `Write(b)`.
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> b) async =>
      write(b);

  /// `ReadFromIP(b)`.
  Future<(Golang.Int, IPAddr?, GoError?)> readFromIP(
    Slice<Golang.Uint8> b,
  ) async => (_zero, null, _einval);

  /// `ReadFrom(b)` (`net.PacketConn`).
  @override
  Future<(Golang.Int, Addr?, GoError?)> readFrom(Slice<Golang.Uint8> b) async =>
      (_zero, null, _einval);

  /// `ReadMsgIP(b, oob)`.
  Future<(Golang.Int, Golang.Int, Golang.Int, IPAddr?, GoError?)> readMsgIP(
    Slice<Golang.Uint8> b,
    Slice<Golang.Uint8> oob,
  ) async => (_zero, _zero, _zero, null, _einval);

  /// `WriteToIP(b, addr)`.
  Future<(Golang.Int, GoError?)> writeToIP(
    Slice<Golang.Uint8> b,
    IPAddr? addr,
  ) async => (_zero, _einval);

  /// `WriteTo(b, addr)` (`net.PacketConn`).
  @override
  Future<(Golang.Int, GoError?)> writeTo(
    Slice<Golang.Uint8> b,
    Addr? addr,
  ) async => (_zero, _einval);

  /// `WriteMsgIP(b, oob, addr)`.
  Future<(Golang.Int, Golang.Int, GoError?)> writeMsgIP(
    Slice<Golang.Uint8> b,
    Slice<Golang.Uint8> oob,
    IPAddr? addr,
  ) async => (_zero, _zero, _einval);
}
