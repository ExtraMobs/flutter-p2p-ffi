part of 'sys_io.dart';

// Sockets Unix de fluxo (`unix`) na VM: o mesmo `Fd`/listener do TCP, só
// com o endereço `InternetAddressType.unix` e o caminho como endereço.

/// Endereço do `dart:io` para o caminho [name] (`@nome` é abstrato, como no
/// Go: o `dart:io` usa a mesma convenção).
InternetAddress _unixAddr(String name) =>
    InternetAddress(name, type: InternetAddressType.unix);

Future<SysTcpConn> _dialUnix(
  String path,
  DateTime? deadline,
  Future<void>? cancel,
) async {
  if (deadline != null && !deadline.isAfter(DateTime.now())) {
    throw const SysTimeout();
  }
  final bad = sysUnixPathError(path, 'connect');
  if (bad != null) throw bad;
  final ConnectionTask<RawSocket> task;
  try {
    task = await RawSocket.startConnect(_unixAddr(path), 0);
  } catch (e) {
    throw _mapUnix(e, 'connect');
  }
  var aborted = 0; // 1: prazo; 2: cancelado.
  Timer? timer;
  if (deadline != null) {
    timer = Timer(deadline.difference(DateTime.now()), () {
      aborted = 1;
      task.cancel();
    });
  }
  var settled = false;
  unawaited(
    cancel?.then((_) {
      if (settled || aborted != 0) return;
      aborted = 2;
      task.cancel();
    }),
  );
  final RawSocket socket;
  try {
    socket = await task.socket;
  } catch (e) {
    if (aborted == 1) throw const SysTimeout();
    if (aborted == 2) throw const SysCanceled();
    throw _mapUnix(e, 'connect');
  } finally {
    settled = true;
    timer?.cancel();
  }
  if (aborted != 0) {
    unawaited(socket.close());
    throw aborted == 1 ? const SysTimeout() : const SysCanceled();
  }
  // Quem disca não dá nome ao próprio socket: no linux o `getsockname` não
  // devolve nome e o Go imprime `@` (ver `anyToSockaddrUnix`).
  return _IoTcpConn.unix(socket, local: unixUnnamed, remote: path);
}

Future<SysTcpListener> _listenUnix(String path, int backlog) async {
  final bad = sysUnixPathError(path, 'bind');
  if (bad != null) throw bad;
  final RawServerSocket srv;
  try {
    srv = await RawServerSocket.bind(_unixAddr(path), 0, backlog: backlog);
  } catch (e) {
    // O que falha num `listen` de socket Unix é o `bind` (como no Go).
    throw _mapUnix(e, 'bind');
  }
  return _IoTcpListener(srv, backlog <= 0 ? 128 : backlog, unixPath: path);
}

/// Apaga o arquivo do socket (o `unlink` do `Close` do `UnixListener`); o
/// que não dá para apagar é ignorado, como o Go ignora o erro do `unlink`.
///
/// ⚠️ Na VM o próprio `dart:io` apaga o arquivo ao fechar o socket que o
/// criou, antes disto: `SetUnlinkOnClose(false)` não o preserva.
void _unlinkUnix(String path) {
  if (path.isEmpty || path.startsWith('@')) return;
  try {
    File(path).deleteSync();
  } on FileSystemException {
    // Já apagado (pelo `dart:io`) ou sem permissão.
  }
}

/// Falha de uma operação de socket Unix: o `dart:io` troca alguns errno por
/// texto próprio, sem código.
SysException _mapUnix(Object e, String syscall) {
  if (e is SocketException && (e.osError?.errorCode ?? 0) == 0) {
    final msg = e.osError?.message ?? e.message;
    // Caminho ocupado por um socket escutando ou por outro arquivo.
    if (msg.contains('shared flag') ||
        msg.contains('File exists with given unix domain address')) {
      return SysError.errno('bind', 'EADDRINUSE');
    }
    if (msg.contains('The length of path exceeds the limit')) {
      return SysError.errno(syscall, 'EINVAL');
    }
  }
  return _mapBind(e, syscall);
}
