/// Tipos e ajudantes comuns do motor de rede por plataforma (`sys.dart`):
/// endereço cru, erros no vocabulário do Go, interfaces das conexões, IP em
/// texto, prazos e a marcação de espera de I/O para o detector de deadlock.
///
/// Nada aqui depende de `dart:io` nem de `dart:js_interop`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../runtime/sched.dart' show holdEvents, releaseEvents;

part 'common_ip.dart';
part 'common_wait.dart';

/// Endereço cru: [ip] com 4 ou 16 bytes (vazio = não especificado/"any",
/// deixando a família à escolha do motor), [port] e [zone] IPv6.
///
/// IPv4 visto por um socket IPv6 dual-stack chega como IPv4 mapeado em IPv6
/// (`::ffff:a.b.c.d`, 16 bytes), como o `net.IP` do Go.
final class SysAddr {
  SysAddr(this.ip, this.port, [this.zone = '']) : path = null;

  /// Socket Unix: [path] é o caminho no sistema de arquivos (ou `@nome`
  /// abstrato no linux; `@` sozinho é o lado que discou, sem nome). [ip],
  /// [port] e [zone] ficam vazios.
  SysAddr.unix(String this.path)
    : ip = _noIp,
      port = 0,
      zone = '';

  final Uint8List ip;
  final int port;
  final String zone;

  /// Caminho do socket Unix, ou `null` num endereço IP.
  final String? path;

  /// Endereço de socket Unix (não de IP).
  bool get isUnix => path != null;

  /// Sem IP, ou IP todo zero (`0.0.0.0`, `::`).
  bool get isUnspecified => ip.every((b) => b == 0);

  @override
  bool operator ==(Object other) =>
      other is SysAddr &&
      other.path == path &&
      other.port == port &&
      other.zone == zone &&
      _sameBytes(other.ip, ip);

  @override
  int get hashCode => Object.hash(path, port, zone, Object.hashAll(ip));

  /// `ip:port` / `[ip%zona]:port`, como o `net.JoinHostPort` do Go; num
  /// socket Unix, o próprio caminho.
  @override
  String toString() {
    final unix = path;
    if (unix != null) return unix;
    final host = ip.isEmpty ? '' : ipToString(ip);
    final z = zone.isEmpty ? '' : '%$zone';
    return host.contains(':') || z.isNotEmpty
        ? '[$host$z]:$port'
        : '$host:$port';
  }
}

final Uint8List _noIp = Uint8List(0);

/// Nome do socket Unix sem nome (quem discou): o Go imprime `@`, por
/// reescrever o NUL inicial de um nome abstrato vazio.
const unixUnnamed = '@';

/// Limite do `sun_path` do linux (108 bytes): o Go recusa um nome que não
/// cabe com `EINVAL` (nome não abstrato precisa do NUL final). Devolve o
/// erro de [syscall] (`bind`, `connect`), ou `null` se o nome serve.
SysError? sysUnixPathError(String name, String syscall) {
  final n = utf8.encode(name).length;
  final abstract = n > 0 && (name[0] == '@' || name.codeUnitAt(0) == 0);
  if (n > 108 || (n == 108 && !abstract)) {
    return SysError.errno(syscall, 'EINVAL');
  }
  return null;
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Base das falhas de I/O do motor. [written] é quanto um `write` já tinha
/// entregue ao sistema quando falhou (o `n` que o Go devolve junto com o
/// erro); 0 nas demais operações.
sealed class SysException implements Exception {
  const SysException([this.written = 0]);

  final int written;
}

/// Erro do sistema: [syscall] no vocabulário do Go (`connect`, `read`,
/// `write`, `listen`, `bind`, `accept`, `socket`, `setsockopt`, `sendto`,
/// `recvfrom`...), [code] o nome do errno (`ECONNREFUSED`...; `EOTHER` para o
/// que não tem nome) e [message] o texto que o Go imprime para esse errno no
/// linux.
final class SysError extends SysException {
  const SysError(this.syscall, this.code, this.message, {int written = 0})
    : super(written);

  /// Erro de [code] com o texto do Go para ele ([errnoText]).
  factory SysError.errno(String syscall, String code, {int written = 0}) =>
      SysError(
        syscall,
        code,
        errnoText[code] ?? code.toLowerCase(),
        written: written,
      );

  /// O navegador (ou plataforma sem rede): `operation not supported`.
  factory SysError.unsupported(String syscall) =>
      SysError.errno(syscall, 'EOPNOTSUPP');

  final String syscall;
  final String code;
  final String message;

  /// O `os.SyscallError` do Go: `connect: connection refused`.
  @override
  String toString() => '$syscall: $message';
}

/// O prazo venceu; a operação pendente termina com isto.
final class SysTimeout extends SysException {
  const SysTimeout([super.written]);

  @override
  String toString() => 'i/o timeout';
}

/// Operação numa conexão/listener fechado localmente (inclusive a que já
/// estava pendente quando o `close` chegou).
final class SysClosed extends SysException {
  const SysClosed([super.written]);

  @override
  String toString() => 'use of closed network connection';
}

/// O `cancel` de [sysDialTcp] completou antes de a conexão sair (o `context`
/// do Go foi cancelado). Desvio do contrato original, que não tinha como
/// distinguir cancelamento de prazo.
final class SysCanceled extends SysException {
  const SysCanceled();

  @override
  String toString() => 'operation was canceled';
}

/// Falha de resolução de nomes, no formato do `net.DNSError` do Go:
/// [message] é `no such host`, `server misbehaving`, `i/o timeout`...;
/// [server] é o `ip:porta` consultado, quando se sabe.
final class SysDnsError implements Exception {
  const SysDnsError(
    this.name,
    this.message, {
    this.server = '',
    this.isNotFound = false,
    this.isTimeout = false,
    this.isTemporary = false,
  });

  /// `no such host` (NXDOMAIN, ou nenhum registro do tipo pedido).
  const SysDnsError.notFound(this.name, {this.server = ''})
    : message = 'no such host',
      isNotFound = true,
      isTimeout = false,
      isTemporary = false;

  final String name;
  final String message;
  final String server;
  final bool isNotFound;
  final bool isTimeout;
  final bool isTemporary;

  /// `DNSError.Error()` do Go.
  @override
  String toString() =>
      'lookup $name${server.isEmpty ? '' : ' on $server'}: $message';
}

/// Texto do Go (linux, `syscall.Errno.Error()`) para cada errno conhecido.
const errnoText = <String, String>{
  'ECONNREFUSED': 'connection refused',
  'ECONNRESET': 'connection reset by peer',
  'ECONNABORTED': 'software caused connection abort',
  'EPIPE': 'broken pipe',
  'EADDRINUSE': 'address already in use',
  'EADDRNOTAVAIL': 'cannot assign requested address',
  'ETIMEDOUT': 'connection timed out',
  'EHOSTUNREACH': 'no route to host',
  'EHOSTDOWN': 'host is down',
  'ENETUNREACH': 'network is unreachable',
  'ENETDOWN': 'network is down',
  'EACCES': 'permission denied',
  'EPERM': 'operation not permitted',
  'EINVAL': 'invalid argument',
  'EAFNOSUPPORT': 'address family not supported by protocol',
  'EOPNOTSUPP': 'operation not supported',
  'EMSGSIZE': 'message too long',
  'EMFILE': 'too many open files',
  'ENFILE': 'too many open files in system',
  'ENOBUFS': 'no buffer space available',
  'ENOTCONN': 'transport endpoint is not connected',
  'EISCONN': 'transport endpoint is already connected',
  'EALREADY': 'operation already in progress',
  'EINPROGRESS': 'operation now in progress',
  'EAGAIN': 'resource temporarily unavailable',
  'EINTR': 'interrupted system call',
  'EBADF': 'bad file descriptor',
  'ENOMEM': 'cannot allocate memory',
  'EPROTONOSUPPORT': 'protocol not supported',
  'ENOENT': 'no such file or directory',
  'ENOTDIR': 'not a directory',
  'EISDIR': 'is a directory',
  'ENAMETOOLONG': 'file name too long',
  'ENOTSOCK': 'socket operation on non-socket',
  'ELOOP': 'too many levels of symbolic links',
  'EROFS': 'read-only file system',
};

/// Conexão TCP aberta.
abstract interface class SysTcpConn {
  SysAddr get local;
  SysAddr get remote;

  /// Lê até `buf.length` bytes; 0 = EOF (o par fechou a escrita) — e também
  /// o resultado de `buf` vazio. Erros: [SysTimeout], [SysClosed],
  /// [SysError] (`read`).
  Future<int> read(Uint8List buf);

  /// Escreve tudo; completa quando entregue ao sistema e devolve
  /// `data.length`. Interrompida no meio, a exceção ([SysTimeout],
  /// [SysClosed], [SysError] `write`) traz em `written` quanto já tinha ido.
  Future<int> write(Uint8List data);

  /// Imediato e idempotente; operações pendentes terminam com [SysClosed].
  void close();

  /// `shutdown(SHUT_WR)`: o par lê EOF.
  void closeWrite();

  /// `shutdown(SHUT_RD)`: leituras daqui em diante dão EOF.
  void closeRead();

  /// Prazo das leituras (inclusive a pendente); no passado, vence na hora;
  /// `null`, sem prazo.
  set readDeadline(DateTime? d);

  /// Prazo das escritas (mesmas regras de [readDeadline]).
  set writeDeadline(DateTime? d);

  void setNoDelay(bool v);
  void setKeepAlive(bool v);

  /// `SO_LINGER`: `sec < 0` desliga (o sistema termina de enviar em segundo
  /// plano); `sec == 0` descarta o que falta e o [close] manda RST (o par lê
  /// `connection reset by peer`); `sec > 0` liga com esse prazo em segundos.
  void setLinger(int sec);

  /// `TCP_KEEPIDLE`: segundos de ociosidade antes da primeira sonda
  /// (sempre > 0; quem chama já resolveu o padrão do Go).
  void setKeepAliveIdle(int secs);

  /// `TCP_KEEPINTVL`: segundos entre sondas (sempre > 0).
  void setKeepAliveInterval(int secs);

  /// `TCP_KEEPCNT`: sondas sem resposta antes de derrubar a conexão
  /// (sempre > 0).
  void setKeepAliveCount(int n);
}

/// Socket TCP escutando.
abstract interface class SysTcpListener {
  SysAddr get local;

  /// Próxima conexão. Erros: [SysTimeout] (prazo), [SysClosed].
  Future<SysTcpConn> accept();

  /// Imediato e idempotente; o `accept` pendente termina com [SysClosed] e
  /// as conexões ainda não aceitas são fechadas.
  void close();

  /// Prazo do `accept` (inclusive o pendente).
  set deadline(DateTime? d);
}

/// Socket UDP.
abstract interface class SysUdpConn {
  SysAddr get local;

  /// Próximo datagrama em [buf]: maior que [buf], é truncado (o resto se
  /// perde), como no Go. Devolve o tamanho copiado e a origem.
  Future<(int, SysAddr)> readFrom(Uint8List buf);

  /// Um datagrama para [to]; devolve `data.length`.
  Future<int> writeTo(Uint8List data, SysAddr to);

  void close();
  set readDeadline(DateTime? d);
  set writeDeadline(DateTime? d);
}

/// Uma interface de rede, como o `net.Interface` do Go (flags separadas).
final class SysInterface {
  SysInterface({
    required this.index,
    required this.name,
    this.mtu = 0,
    Uint8List? hardwareAddr,
    this.up = false,
    this.loopback = false,
    this.multicast = false,
    this.pointToPoint = false,
    this.broadcast = false,
    this.running = false,
    List<(Uint8List, int)>? addrs,
  }) : hardwareAddr = hardwareAddr ?? Uint8List(0),
       addrs = addrs ?? [];

  int index;
  String name;
  int mtu;
  Uint8List hardwareAddr;
  bool up, loopback, multicast, pointToPoint, broadcast, running;

  /// `(ip, tamanho do prefixo)` de cada endereço.
  List<(Uint8List ip, int prefixLen)> addrs;
}
