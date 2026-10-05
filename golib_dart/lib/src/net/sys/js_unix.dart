part of 'sys_js.dart';

// Sockets Unix de fluxo (`unix`) sob Node: `net.connect({path})` e
// `server.listen({path})`, com a mesma conexão e o mesmo listener do TCP.
//
// O Node quer o nome abstrato do linux com NUL inicial; o Go (e o
// `dart:io`) escrevem `@nome`.

String _nodePath(String name) =>
    name.startsWith('@') ? '\u0000${name.substring(1)}' : name;

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
  final JSObject s;
  try {
    s = _net.callMethod<JSObject>(
      'createConnection'.toJS,
      _obj({
        'path': _nodePath(path).toJS,
        // Meia-conexão do Go: o EOF do par não fecha a nossa escrita.
        'allowHalfOpen': true.toJS,
      }),
    );
  } catch (e) {
    throw SysError('connect', 'EOTHER', '$e');
  }
  final done = Completer<JSAny?>();
  _on(
    s,
    'connect',
    (() {
      if (!done.isCompleted) done.complete(null);
    }).toJS,
  );
  _on(
    s,
    'error',
    ((JSAny? e) {
      if (!done.isCompleted) done.complete(e ?? 'error'.toJS);
    }).toJS,
  );
  var aborted = 0; // 1: prazo; 2: cancelado.
  void abort(int why) {
    if (done.isCompleted) return;
    aborted = why;
    s.callMethod<JSAny?>('destroy'.toJS);
    done.complete(null);
  }

  final timer = deadline == null ? null : Deadline(() => abort(1));
  timer?.set(deadline);
  unawaited(cancel?.then((_) => abort(2)));
  final err = await done.future;
  timer?.cancel();
  if (aborted == 1) throw const SysTimeout();
  if (aborted == 2) throw const SysCanceled();
  if (err != null) {
    s.callMethod<JSAny?>('destroy'.toJS);
    throw _mapNodeBind(err, 'connect');
  }
  // Quem disca não dá nome ao próprio socket (o Go imprime `@`).
  return _NodeTcpConn(
    s,
    local: SysAddr.unix(unixUnnamed),
    remote: SysAddr.unix(path),
  );
}

Future<SysTcpListener> _listenUnix(String path, int backlog) async {
  final bad = sysUnixPathError(path, 'bind');
  if (bad != null) throw bad;
  // O `listen` do Node num diretório que não existe devolve EACCES; o Go
  // (e o `bind` do linux) devolvem ENOENT.
  if (!path.startsWith('@') && !path.startsWith('\u0000')) {
    final slash = path.lastIndexOf('/');
    if (slash > 0 && !_exists(path.substring(0, slash))) {
      throw SysError.errno('bind', 'ENOENT');
    }
  }
  final server = _net.callMethod<JSObject>(
    'createServer'.toJS,
    _obj({'allowHalfOpen': true.toJS, 'pauseOnConnect': true.toJS}),
  );
  final l = _NodeTcpListener(server)..unixPath = path;
  final ready = Completer<JSAny?>();
  l._onListenError = (e) {
    if (!ready.isCompleted) ready.complete(e ?? 'error'.toJS);
  };
  server.callMethod<JSAny?>(
    'listen'.toJS,
    _obj({
      'path': _nodePath(path).toJS,
      'backlog': backlog.toJS,
      'exclusive': true.toJS,
    }),
    (() {
      if (!ready.isCompleted) ready.complete(null);
    }).toJS,
  );
  final err = await ready.future;
  l._onListenError = null;
  if (err != null) {
    server.callMethod<JSAny?>('close'.toJS);
    // O que falha num `listen` de socket Unix é o `bind` (como no Go).
    throw _mapNodeBind(err, 'bind');
  }
  l.local = SysAddr.unix(path);
  return l;
}

/// Apaga o arquivo do socket (o `unlink` do `Close` do `UnixListener`); o
/// que não dá para apagar é ignorado, como o Go ignora o erro do `unlink`.
///
/// ⚠️ O Node (libuv) já apaga o arquivo ao fechar o socket que o criou,
/// antes disto: `SetUnlinkOnClose(false)` não o preserva.
void _unlinkUnix(String path) {
  if (path.isEmpty || path.startsWith('@')) return;
  try {
    _fs.callMethod<JSAny?>('unlinkSync'.toJS, path.toJS);
  } catch (_) {
    // Já apagado (pelo Node) ou sem permissão.
  }
}

bool _exists(String path) {
  try {
    return _bool(_fs.callMethod<JSAny?>('existsSync'.toJS, path.toJS));
  } catch (_) {
    return false;
  }
}
