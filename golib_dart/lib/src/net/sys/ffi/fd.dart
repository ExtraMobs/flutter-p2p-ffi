/// [FfiFd]: um socket da libc (não bloqueante) com esperas pelo poller,
/// prazos e `close` como o `netFD`/`poll.FD` do Go.
///
/// - Esperas ([waitRead]/[waitWrite]) estacionam no poller deste isolate e
///   seguram o detector de deadlock (`heldIo`), como o netpoller do Go.
/// - Prazos ([readDeadline]/[writeDeadline]) pelo `Deadline` do motor:
///   vencer acorda a espera pendente com `SysTimeout`; re-armar vale para
///   ela também.
/// - [close] é síncrono e idempotente: marca fechado, acorda quem espera com
///   `SysClosed` e só faz o `close(2)` depois do ack do poller (o fd não
///   está mais no `poll` do auxiliar, e o número pode ser reaproveitado).
/// - Fd esquecido sem [close] é fechado por um `NativeFinalizer`.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../../../sysffi/sysffi.dart' as sf;
import '../common.dart';
import 'errors.dart';
import 'poller.dart';

final class FfiFd implements Finalizable {
  /// Assume [fd]: daqui em diante é deste objeto. Liga `O_NONBLOCK` se
  /// faltar (as chamadas leaf não podem bloquear).
  FfiFd.adopt(int fd) : _fd = fd, _watch = PollWatch(fd) {
    final fl = sf.fcntl(fd, sf.F_GETFL);
    if (fl >= 0 && fl & sf.O_NONBLOCK == 0) {
      sf.fcntl(fd, sf.F_SETFL, fl | sf.O_NONBLOCK);
    }
    _rd = Deadline(_watch.wakeReaders);
    _wd = Deadline(_watch.wakeWriters);
    _finalizer.attach(this, Pointer<Void>.fromAddress(fd), detach: this);
  }

  /// `socket(domain, type|SOCK_NONBLOCK|SOCK_CLOEXEC, protocol)`.
  factory FfiFd.socket(int domain, int type, [int protocol = 0]) {
    final fd = sf.socket(
      domain,
      type | sf.SOCK_NONBLOCK | sf.SOCK_CLOEXEC,
      protocol,
    );
    if (fd < 0) throw FfiErrno('socket', -fd);
    return FfiFd.adopt(fd);
  }

  /// Fecha fd esquecido. O token é o número do fd; o `close(int)` da libc
  /// recebe o ponteiro no mesmo registrador (`rdi`/`x0` no linux), então
  /// lê o número certo.
  static final _finalizer = NativeFinalizer(sf.closeFinalizer);

  int _fd;
  final PollWatch _watch;
  late final Deadline _rd;
  late final Deadline _wd;
  final _done = Completer<void>();

  /// O número do fd; `-1` depois do [close].
  int get fd => _fd;

  bool get isClosed => _fd < 0;

  /// Completa depois do `close(2)` (que, com espera pendente, só vem depois
  /// do ack do poller).
  Future<void> get done => _done.future;

  /// Prazo das leituras e do `accept` (inclusive a espera pendente); no
  /// passado, vence na hora; `null`, sem prazo.
  set readDeadline(DateTime? d) => _rd.set(d);

  /// Prazo das escritas e do [connect].
  set writeDeadline(DateTime? d) => _wd.set(d);

  /// Estaciona até o fd ficar legível (ou erro/fim). Erros: `SysClosed`,
  /// `SysTimeout` (prazo de leitura), `SysCanceled` ([cancel] completou).
  Future<void> waitRead({Future<void>? cancel}) =>
      heldIo(() => _wait(sf.POLLIN, cancel));

  /// Estaciona até o fd aceitar escrita. Erros como [waitRead], com o prazo
  /// de escrita.
  Future<void> waitWrite({Future<void>? cancel}) =>
      heldIo(() => _wait(sf.POLLOUT, cancel));

  /// Repete [attempt] (uma chamada leaf da libc sobre [fd], que devolve
  /// `>= 0` ou `-errno`) enquanto der `EAGAIN`, esperando [events]
  /// (`POLLIN`/`POLLOUT`) entre as tentativas; `EINTR` repete na hora.
  /// Devolve o resultado, ou lança [FfiErrno] com [syscall] (e os erros de
  /// [waitRead]). É a base de `recvmsg`, `sendmsg` e afins nas etapas
  /// seguintes.
  Future<int> io(
    int events,
    String syscall,
    int Function(int fd) attempt, {
    Future<void>? cancel,
  }) => heldIo(() async {
    while (true) {
      _check(events);
      final r = attempt(_fd);
      if (r >= 0) return r;
      if (r == -sf.EINTR) continue;
      if (r != -sf.EAGAIN) throw FfiErrno(syscall, -r);
      await _wait(events, cancel);
    }
  });

  /// Lê até `buf.length` bytes; 0 = EOF. Erros: [FfiErrno] (`read`),
  /// `SysTimeout`, `SysClosed`.
  Future<int> read(Uint8List buf) {
    if (buf.isEmpty) return Future.value(0);
    return io(sf.POLLIN, 'read', (fd) => sf.read(fd, buf));
  }

  /// Escreve tudo (com `MSG_NOSIGNAL`: par fechado dá `EPIPE`, não
  /// `SIGPIPE`). Interrompida no meio, a exceção traz em `written` quanto
  /// já tinha ido.
  Future<int> write(Uint8List data) => heldIo(() async {
    var n = 0;
    while (n < data.length) {
      if (isClosed) throw SysClosed(n);
      if (_wd.expired) throw SysTimeout(n);
      final rest = n == 0 ? data : Uint8List.sublistView(data, n);
      final r = sf.sendto(_fd, rest, sf.MSG_NOSIGNAL, nullptr, 0);
      if (r >= 0) {
        n += r;
        continue;
      }
      if (r == -sf.EINTR) continue;
      if (r != -sf.EAGAIN) throw FfiErrno('write', -r, written: n);
      try {
        await _wait(sf.POLLOUT, null);
      } on SysTimeout {
        throw SysTimeout(n);
      } on SysClosed {
        throw SysClosed(n);
      }
    }
    return n;
  });

  /// `connect` não bloqueante: `POLLOUT` + `SO_ERROR`, como o `netFD.connect`
  /// do Go. [deadline] vale só durante o connect (`SysTimeout`); [cancel]
  /// completando aborta com `SysCanceled`. Erro do sistema: [FfiErrno]
  /// (`connect`).
  Future<void> connect(
    sf.Sockaddr to, {
    DateTime? deadline,
    Future<void>? cancel,
  }) => heldIo(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final int r;
    try {
      final len = sf.encodeSockaddr(to, sa);
      if (len < 0) throw FfiErrno('connect', -len);
      _check(sf.POLLOUT);
      r = sf.connect(_fd, sa, len);
    } finally {
      sf.libcAlloc.free(sa);
    }
    if (r == 0) return;
    if (r != -sf.EINPROGRESS && r != -sf.EALREADY && r != -sf.EINTR) {
      throw FfiErrno('connect', -r);
    }
    if (deadline != null) _wd.set(deadline);
    try {
      while (true) {
        await _wait(sf.POLLOUT, cancel);
        final (so, err) = sf.getsockoptInt(_fd, sf.SOL_SOCKET, sf.SO_ERROR);
        if (err != 0) throw FfiErrno('getsockopt', err);
        switch (so) {
          case sf.EINPROGRESS || sf.EALREADY || sf.EINTR:
            continue;
          case 0:
            // O poller pode acordar à toa (Go, issues 14548 e 19289):
            // conectado de verdade só se houver par.
            if (peerAddr() != null) return;
          case sf.EISCONN:
            return;
          default:
            throw FfiErrno('connect', so);
        }
      }
    } finally {
      if (deadline != null) _wd.set(null);
    }
  });

  /// Próxima conexão (`accept4` com `SOCK_NONBLOCK|SOCK_CLOEXEC`), com o
  /// endereço do par. `ECONNABORTED` repete, como o Go. Erros: [FfiErrno]
  /// (`accept`), `SysTimeout` (prazo de leitura), `SysClosed`.
  Future<(FfiFd, sf.Sockaddr)> accept() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>();
    try {
      final fd = await io(sf.POLLIN, 'accept', (fd) {
        while (true) {
          len.value = sf.sockaddrStorageSize;
          final r = sf.accept4(fd, sa, len, sf.SOCK_NONBLOCK | sf.SOCK_CLOEXEC);
          if (r != -sf.ECONNABORTED) return r;
        }
      });
      return (FfiFd.adopt(fd), sf.decodeSockaddr(sa, len.value));
    } finally {
      sf.libcAlloc.free(sa);
      sf.libcAlloc.free(len);
    }
  }

  /// `getsockname`; `null` se falhar.
  sf.Sockaddr? localAddr() => _name(sf.getsockname);

  /// `getpeername`; `null` se não conectado (ou falhar).
  sf.Sockaddr? peerAddr() => _name(sf.getpeername);

  sf.Sockaddr? _name(int Function(int, Pointer<Uint8>, Pointer<Uint32>) f) {
    if (isClosed) return null;
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>()..value = sf.sockaddrStorageSize;
    try {
      if (f(_fd, sa, len) < 0) return null;
      return sf.decodeSockaddr(sa, len.value);
    } finally {
      sf.libcAlloc.free(sa);
      sf.libcAlloc.free(len);
    }
  }

  /// Fecha (síncrono, idempotente). Quem espera acorda com `SysClosed`; o
  /// `close(2)` vem quando o poller confirmar que largou o fd ([done]).
  void close() {
    final fd = _fd;
    if (fd < 0) return;
    _fd = -1;
    _finalizer.detach(this);
    _rd.cancel();
    _wd.cancel();
    _watch
      ..wakeReaders()
      ..wakeWriters();
    void reallyClose() {
      sf.close(fd);
      if (!_done.isCompleted) _done.complete();
    }

    final poller = Poller.current;
    if (poller != null && _watch.inHelper) {
      poller.forget(_watch, reallyClose);
    } else {
      reallyClose();
    }
  }

  /// Entrega o número do fd a outro dono sem fechá-lo: este objeto fica
  /// fechado (quem espera acorda com `SysClosed`) e o finalizador
  /// desligado; o número sai depois do ack do poller, quando o auxiliar já
  /// não o tem no `poll`.
  Future<int> release() {
    final fd = _fd;
    if (fd < 0) return Future.error(const SysClosed());
    _fd = -1;
    _finalizer.detach(this);
    _rd.cancel();
    _wd.cancel();
    _watch
      ..wakeReaders()
      ..wakeWriters();
    final out = Completer<int>();
    void handOver() {
      if (!_done.isCompleted) _done.complete();
      out.complete(fd);
    }

    final poller = Poller.current;
    if (poller != null && _watch.inHelper) {
      poller.forget(_watch, handOver);
    } else {
      handOver();
    }
    return out.future;
  }

  void _check(int events) {
    if (isClosed) throw const SysClosed();
    if ((events & sf.POLLIN != 0 ? _rd : _wd).expired) {
      throw const SysTimeout();
    }
  }

  Future<void> _wait(int events, Future<void>? cancel) async {
    _check(events);
    final poller = await Poller.instance();
    _check(events);
    if (poller.dead) throw StateError('golib-netpoller morreu');
    final c = Completer<void>();
    final list = events == sf.POLLIN ? _watch.readers : _watch.writers;
    list.add(c);
    var canceled = false;
    poller.hold();
    poller.arm(_watch, events);
    if (cancel != null) {
      unawaited(
        cancel.then((_) {
          if (c.isCompleted) return;
          canceled = true;
          list.remove(c);
          c.complete();
        }),
      );
    }
    try {
      await c.future;
    } finally {
      poller.release();
    }
    if (canceled && !isClosed) throw const SysCanceled();
    _check(events);
    if (poller.dead) throw StateError('golib-netpoller morreu');
  }
}
