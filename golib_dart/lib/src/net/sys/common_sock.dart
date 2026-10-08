part of 'common.dart';

// Sockets montados passo a passo (rede FFI, etapas E2/E7 do plano D10): o
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

/// Socket do `dart:io` de fluxo (TCP, Unix) cujo descritor virtual também
/// lê e escreve: o `syscall.Read`/`Write` do `f` de um `RawConn.Read`/
/// `Write` (o leitor do gRPC, `readyreader`). [vfdRead]/[vfdWrite] não
/// esperam e devolvem como a libc do `sysffi`: `>= 0` (0 na leitura é o
/// EOF) ou `-errno` (`EAGAIN` sem dado ou sem espaço). [rawRead]/[rawWrite]
/// são o `FD.RawRead`/`RawWrite`. Erros: [SysClosed], [SysTimeout].
abstract interface class SysVfdIo {
  int vfdRead(Uint8List buf);
  int vfdWrite(Uint8List data);
  Future<void> rawRead(bool Function() f);
  Future<void> rawWrite(bool Function() f);
}

/// Socket cru da rede FFI, criado por `sysSocket(family, sotype, proto)`
/// (não bloqueante, `close-on-exec`). Os métodos que consomem ([toTcpConn],
/// [toTcpListener], [toUdpConn]) passam o fd a outro dono; depois deles e
/// do [close], este objeto está fechado.
abstract interface class SysSocket implements SysRawFd {
  /// `AF_INET` (2) ou `AF_INET6` (10).
  int get family;

  /// `setsockopt` de um `int`: 0 ou `-errno`.
  int setsockoptInt(int level, int opt, int value);

  /// `bind`. Erros: [SysError] (`bind`).
  void bind(SysAddr local);

  /// `listen`. Erros: [SysError] (`listen`).
  void listen(int backlog);

  /// `connect` não bloqueante, com [deadline] (vence com [SysTimeout]) e
  /// [cancel] (aborta com [SysCanceled]). Erros: [SysError] (`connect`).
  Future<void> connect(SysAddr remote, {DateTime? deadline, Future<void>? cancel});

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
