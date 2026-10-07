part of 'common.dart';

// Socket genérico (o `netFD` do Go): o que os sockets Unix de todos os
// tipos (`unix`, `unixgram`, `unixpacket`) e o IP bruto usam quando a
// plataforma tem a rede FFI (VM no linux, `sysSockSupported`).

/// Tipos de socket do linux (os do `syscall`), para [SysSock.sotype].
const sysSockStream = 1, sysSockDgram = 2, sysSockRaw = 3, sysSockSeqpacket = 5;

/// Famílias do linux, para [SysSock.family] e o `sysSocket`.
const sysAfUnix = 1, sysAfInet = 2, sysAfInet6 = 10;

/// Um socket do sistema com as operações do `netFD` do Go: conexão
/// ([SysTcpConn]: `read`/`write`/`close`...), listener ([SysTcpListener]:
/// `accept`) e datagrama/mensagem ([readFrom], [writeTo], [readMsg],
/// [writeMsg]). Qual operação faz sentido depende do tipo; o sistema
/// responde às outras com o errno do Go (`accept4` num datagrama dá
/// `EOPNOTSUPP`, `recvfrom` num listener dá `EINVAL`).
///
/// Ao contrário de [SysTcpConn.read], [read] devolve o 0 cru: quem chama
/// decide se é EOF (o `ZeroReadIsEOF` do Go vale para fluxo e seqpacket,
/// não para datagrama nem IP bruto). Erros: [SysError] com a syscall do Go
/// (`read`, `write`, `recvfrom`, `sendto`, `recvmsg`, `sendmsg`,
/// `accept4`), [SysTimeout], [SysClosed].
abstract interface class SysSock implements SysTcpConn, SysTcpListener {
  /// [sysSockStream], [sysSockDgram], [sysSockRaw] ou [sysSockSeqpacket].
  int get sotype;

  /// [sysAfUnix], [sysAfInet] ou [sysAfInet6].
  int get family;

  /// `connect` feito (o `fd.isConnected` do Go): o lado que discou.
  bool get isConnected;

  /// O `getsockname` (o `fd.laddr` do Go), ou `null`.
  SysAddr? get localAddr;

  /// O par (o `fd.raddr` do Go), ou `null` (listener, datagrama sem
  /// destino).
  SysAddr? get remoteAddr;

  @override
  Future<SysSock> accept();

  /// `recvfrom`: o tamanho lido (truncado em `buf.length` num datagrama) e
  /// a origem (`null` quando o remetente não tem nome).
  Future<(int, SysAddr?)> readFrom(Uint8List buf);

  /// `sendto` para [to]; devolve `data.length`.
  Future<int> writeTo(Uint8List data, SysAddr to);

  /// `recvmsg` com [flags] (`MSG_*`): `(n, oobn, flags, origem)`; os dados
  /// de controle são copiados para [oob]. Sem dados e com [oob], lê um byte
  /// fictício num socket que não é de datagrama, como o `syscall.Recvmsg`.
  Future<(int, int, int, SysAddr?)> readMsg(
    Uint8List buf,
    Uint8List oob,
    int flags,
  );

  /// `sendmsg` com [oob] para [to] (`null`: o par conectado): `(n, oobn)`.
  /// Sem dados e com [oob], manda um byte fictício num socket que não é de
  /// datagrama e devolve `n == 0`, como o `syscall.SendmsgN`.
  Future<(int, int)> writeMsg(Uint8List data, Uint8List oob, SysAddr? to);
}

/// Endereço que não serve à família do socket (o `*AddrError` do
/// `ipToSockaddr` do Go): `address ::1: non-IPv4 address`.
final class SysAddrError extends SysException {
  const SysAddrError(this.err, this.addr);

  final String err;
  final String addr;

  @override
  String toString() => 'address $addr: $err';
}
