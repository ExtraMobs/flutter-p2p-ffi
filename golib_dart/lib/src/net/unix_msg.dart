part of '../../net.dart';

// `UnixConn.ReadMsgUnix`/`WriteMsgUnix` (o `readMsg`/`writeMsg` de
// `unixsock_posix.go` do Go 1.26 sobre o `recvmsg`/`sendmsg` do
// `syscall`) e o `ReadFromUnix` do fluxo da plataforma.
//
// Com a rede FFI, tudo é o `recvmsg`/`sendmsg` do sistema, com o
// `MSG_CMSG_CLOEXEC` do Go nas flags (o kernel a devolve em `flags`) e o
// byte fictício do `syscall` quando só há dados de controle. Sem ela (Node,
// VM fora do linux), dados de controle dão `operation not supported`
// (`recvmsg`/`sendmsg`); sem eles, a mensagem é a leitura/escrita do fluxo.

/// `syscall.MSG_CMSG_CLOEXEC` (o `readMsgFlags` do Go no linux).
const _msgCmsgCloexec = 0x40000000;

/// `ReadFromUnix(b)` sobre o fluxo da plataforma: o `recvfrom` traz o nome
/// do par quando ele tem nome (o lado que discou vê o caminho do
/// listener); sem nome, nil. O EOF volta num `*OpError`.
Future<(Golang.Int, UnixAddr?, GoError?)> _readFromStream(
  UnixConn c,
  Slice<Golang.Uint8> b,
) async {
  final (n, err) = await c.read$async(b);
  if (err == null) {
    final r = c._raddr;
    final named =
        r is UnixAddr && r.name.length != 0 && r.name.toString() != '@';
    return (n, named ? r : null, null);
  }
  return (
    n,
    null,
    err == io.eof ? _opError('read', c._net, c._laddr, c._raddr, io.eof) : err,
  );
}

/// `UnixConn.ReadMsgUnix(b, oob)`.
Future<(Golang.Int, Golang.Int, Golang.Int, UnixAddr?, GoError?)> _readMsgUnix(
  UnixConn c,
  Slice<Golang.Uint8> b,
  Slice<Golang.Uint8> oob,
) async {
  final zero = Golang.Int(0);
  if (c._closed) return (zero, zero, zero, null, c._op('read', sys.SysClosed()));
  final sock = c._sock;
  if (sock == null) {
    if (oob.length != 0) {
      return (zero, zero, zero, null, c._op('read', _unsupportedMsg('recvmsg')));
    }
    final (n, a, err) = await _readFromStream(c, b);
    return (n, zero, err == null ? Golang.Int(_msgCmsgCloexec) : zero, a, err);
  }
  final buf = Uint8List(b.length);
  final ob = Uint8List(oob.length);
  try {
    final (n, oobn, flags, from) = await sock.readMsg(
      buf,
      ob,
      _msgCmsgCloexec,
    );
    _copyInto(b, buf, n < b.length ? n : b.length);
    _copyInto(oob, ob, oobn);
    final name = from?.path ?? '';
    final addr = name.isEmpty
        ? null
        : UnixAddr(name: _s(name), net: _s(_sotypeToNet(c._sotype)));
    final err = n == 0 && c._zeroIsEof
        ? _opError('read', c._net, c._laddr, c._raddr, io.eof)
        : null;
    return (Golang.Int(n), Golang.Int(oobn), Golang.Int(flags), addr, err);
  } on Object catch (e) {
    return (zero, zero, zero, null, c._op('read', e));
  }
}

/// `UnixConn.WriteMsgUnix(b, oob, addr)`.
Future<(Golang.Int, Golang.Int, GoError?)> _writeMsgUnix(
  UnixConn c,
  Slice<Golang.Uint8> b,
  Slice<Golang.Uint8> oob,
  UnixAddr? addr,
) async {
  final zero = Golang.Int(0);
  final to = addr == null || addr.$nilPtr ? null : addr;
  (Golang.Int, Golang.Int, GoError?) fail(GoError err) =>
      (zero, zero, _opError('write', c._net, c._laddr, to, err));
  if (c._closed) return fail(errClosed);
  final sock = c._sock;
  final net = _sotypeToNet(c._sotype);
  if (sock != null && c._sotype == sys.sysSockDgram && c._connected) {
    return fail(errWriteToConnected);
  }
  if (to != null && to.net.toString() != net) {
    return fail(syscall.eafnosupport);
  }
  if (sock == null) {
    if (oob.length != 0) return fail(_notSupported('sendmsg'));
    // Um destino num fluxo (sempre conectado): `EISCONN` do `sendmsg`.
    if (to != null) {
      return fail(os.newSyscallError(_s('sendmsg'), syscall.eisconn)!);
    }
    if (b.length == 0) return (zero, zero, null);
    try {
      final n = await c._fd!.write(_u8(b));
      return (Golang.Int(n), zero, null);
    } on Object catch (e) {
      return (
        Golang.Int(e is sys.SysException ? e.written : 0),
        zero,
        _opError('write', c._net, c._laddr, to, _sysError(e)),
      );
    }
  }
  try {
    final (n, oobn) = await sock.writeMsg(
      _u8(b),
      _u8(oob),
      to == null ? null : sys.SysAddr.unix('${to.name}'),
    );
    return (Golang.Int(n), Golang.Int(oobn), null);
  } on Object catch (e) {
    return fail(_sysError(e));
  }
}

/// Dados de controle sem a rede FFI: `operation not supported`.
sys.SysError _unsupportedMsg(String call) => sys.SysError.unsupported(call);
