part of 'common.dart';

// Sockets montados passo a passo (rede FFI, etapas E2–E7 do plano D10): o
// `net` segue a ordem do `socket()` do Go (`socket` → opções padrão →
// `Control` → `bind` → `listen`/`connect`) sobre [SysSocket], e o
// `SyscallConn` do Go vê o descritor por [SysRawFd] (fd real) ou
// [SysSockopts] (só as opções, pelo dono do socket).

/// Socket com descritor real do processo (rede FFI): o `RawConn` do Go
/// chama o `f` com [rawFd] e espera por [rawWaitRead]/[rawWaitWrite].
abstract interface class SysRawFd {
  /// O número do fd; `-1` depois de fechado.
  int get rawFd;

  /// O prazo de leitura venceu (o `prepareRead` do Go falha na hora).
  bool get rawReadExpired;

  /// O prazo de escrita venceu.
  bool get rawWriteExpired;

  /// Espera o fd ficar legível. Erros: [SysClosed], [SysTimeout].
  Future<void> rawWaitRead();

  /// Espera o fd aceitar escrita. Erros: [SysClosed], [SysTimeout].
  Future<void> rawWaitWrite();
}

/// Socket sem fd ao alcance (o `dart:io` não o expõe) que ainda responde
/// por opções de socket: o descritor virtual do `RawConn.Control`. Os dois
/// devolvem `>= 0` (0 no `set`; o tamanho no `get`) ou `-errno` (linux).
abstract interface class SysSockopts {
  int rawSetsockopt(int level, int opt, Uint8List value);
  int rawGetsockopt(int level, int opt, Uint8List out);
}

/// Socket cru da rede FFI, criado por `sysSocket(family, sotype, proto)`
/// (não bloqueante, `close-on-exec`). Os métodos que consomem ([toTcpConn],
/// [toTcpListener], [toUdpConn]) passam o fd a outro dono; depois deles e
/// do [close], este objeto está fechado.
abstract interface class SysSocket implements SysRawFd {
  /// [sysAfUnix], [sysAfInet] ou [sysAfInet6].
  int get family;

  /// [sysSockStream], [sysSockDgram], [sysSockRaw] ou [sysSockSeqpacket].
  int get sotype;

  /// `setsockopt` de um `int`: 0 ou `-errno`.
  int setsockoptInt(int level, int opt, int value);

  /// `bind`. Erros: [SysError] (`bind`), [SysAddrError] (IP fora da
  /// família).
  void bind(SysAddr local);

  /// `listen`. Erros: [SysError] (`listen`).
  void listen(int backlog);

  /// `connect` não bloqueante, com [deadline] (vence com [SysTimeout]) e
  /// [cancel] (aborta com [SysCanceled]). Erros: [SysError] (`connect`).
  Future<void> connect(
    SysAddr remote, {
    DateTime? deadline,
    Future<void>? cancel,
  });

  /// `getsockname`; `null` se falhar.
  SysAddr? localAddr();

  /// `getpeername`; `null` se não conectado.
  SysAddr? remoteAddr();

  /// Conexão de fluxo conectada → [SysTcpConn] (na VM, a ponte para o
  /// `dart:io`, com `TCP_NODELAY` como o `newTCPConn` do Go).
  Future<SysTcpConn> toTcpConn();

  /// Socket de fluxo escutando → listener (o laço de `accept4` fica no FFI;
  /// cada conexão aceita vai para o `dart:io`).
  SysTcpListener toTcpListener();

  /// Socket de datagrama (com `bind` ou `connect` já feitos) → conexão UDP
  /// com [SysUdpMsg] e [SysRawFd].
  SysUdpConn toUdpConn();

  /// Qualquer outro socket (Unix de todos os tipos, IP bruto), discado,
  /// escutando ou só com `bind` → [SysSockConn] (fica no FFI).
  SysSockConn toSockConn();

  /// Fecha (síncrono, idempotente).
  void close();
}

/// UDP com descritor real (rede FFI, E7): o que o `UDPConn` do Go faz além
/// de `ReadFrom`/`WriteTo`.
abstract interface class SysUdpMsg {
  /// `AF_INET`/`AF_INET6`: o endereço de destino tem de caber nela.
  int get family;

  /// O par de um socket conectado (`connect`), ou `null`.
  SysAddr? get remote;

  /// `read` (socket conectado): um datagrama, truncado em `buf.length`.
  /// Erros: [SysError] (`read`), [SysTimeout], [SysClosed].
  Future<int> recv(Uint8List buf);

  /// `write` (socket conectado). Erros: [SysError] (`write`)...
  Future<int> send(Uint8List data);

  /// `recvmsg`: `(n, oobn, flags, origem)`; `flags` traz `MSG_TRUNC`
  /// (0x20) no datagrama truncado e `MSG_CTRUNC` (0x8) no controle
  /// truncado. Erros: [SysError] (`recvmsg`)...
  Future<(int, int, int, SysAddr?)> readMsg(Uint8List buf, Uint8List oob);

  /// `sendmsg` com dados de controle [oob] para [to] (`null`: o par do
  /// socket conectado): `(n, len(oob))`. Erros: [SysError] (`sendmsg`)...
  Future<(int, int)> writeMsg(Uint8List data, Uint8List oob, SysAddr? to);
}

/// O que a pilha IP do processo suporta (`ipStackCapabilities` do Go,
/// medido por sockets de teste).
final class SysIpStack {
  const SysIpStack({
    required this.ipv4,
    required this.ipv6,
    required this.ipv4MappedIPv6,
  });

  final bool ipv4;
  final bool ipv6;
  final bool ipv4MappedIPv6;
}

/// Tipos de socket do linux (os do `syscall`), para [SysSockConn.sotype].
const sysSockStream = 1, sysSockDgram = 2, sysSockRaw = 3, sysSockSeqpacket = 5;

/// Famílias do linux, para [SysSockConn.family] e o `sysSocket`.
const sysAfUnix = 1, sysAfInet = 2, sysAfInet6 = 10;

/// A conexão de um [SysSocket] montado (`SysSocket.toSockConn`), com as
/// operações do `netFD` do Go: conexão
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
abstract interface class SysSockConn implements SysTcpConn, SysTcpListener {
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
  Future<SysSockConn> accept();

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
    Uint8List oob, [
    int flags,
  ]);

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
