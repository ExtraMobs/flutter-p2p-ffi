/// Poller da rede FFI (VM, linux): o netpoller do Go para fds que não são
/// do `dart:io`. O lado do isolate principal fica aqui; o laço de `poll(2)`
/// roda num isolate auxiliar (`poller_loop.dart`), um por isolate que usa a
/// rede FFI (os estáticos do Dart são por isolate).
///
/// Interesse é de um disparo, como o `EPOLLONESHOT`: quem espera arma
/// ([arm]) e o auxiliar relata e desarma. Uma espera desistida (prazo,
/// cancelamento) deixa o interesse armado; o próximo evento só não acorda
/// ninguém. Cada registro tem um token: evento de um fd já fechado (e de
/// número reaproveitado) não acorda o dono novo.
///
/// O isolate principal só é mantido vivo enquanto há espera ou `close`
/// pendente ([hold]/[release]); interesse armado sem ninguém esperando não
/// segura a VM, e o auxiliar morre com o principal.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../sysffi/sysffi.dart' as sf;
import 'errors.dart';
import 'poller_loop.dart';

/// Registro de um fd no poller: o que está armado no auxiliar e quem
/// espera em cada direção. Não referencia o dono (`FfiFd`), para o
/// `NativeFinalizer` do dono poder rodar.
final class PollWatch {
  PollWatch(this.fd) : token = ++_tokens;

  static int _tokens = 0;

  final int fd;
  final int token;

  /// Eventos armados no auxiliar (na visão do principal: o que foi pedido e
  /// ainda não voltou relatado).
  int armed = 0;

  final readers = <Completer<void>>[];
  final writers = <Completer<void>>[];

  /// O auxiliar pode ter este fd no conjunto do `poll`: fechar exige o ack.
  bool get inHelper => armed != 0;

  void wakeReaders() => _wakeAll(readers);
  void wakeWriters() => _wakeAll(writers);

  static void _wakeAll(List<Completer<void>> list) {
    if (list.isEmpty) return;
    final all = List.of(list);
    list.clear();
    for (final c in all) {
      if (!c.isCompleted) c.complete();
    }
  }
}

/// O poller deste isolate.
final class Poller {
  Poller._(this._port, this._efd);

  static Poller? _live;
  static Future<Poller>? _starting;

  /// O poller já em pé, sem criar.
  static Poller? get current => _live;

  /// O poller deste isolate (cria o auxiliar na primeira vez).
  static Future<Poller> instance() {
    final live = _live;
    if (live != null) return Future.value(live);
    return _starting ??= _start();
  }

  static Future<Poller> _start() async {
    final efd = sf.eventfd(0, sf.EFD_NONBLOCK | sf.EFD_CLOEXEC);
    if (efd < 0) {
      _starting = null;
      throw FfiErrno('eventfd', -efd);
    }
    final port = RawReceivePort(null, 'golib-netpoller');
    final p = Poller._(port, efd);
    port.handler = p._onMessage;
    try {
      await Isolate.spawn(
        pollerMain,
        (port.sendPort, efd, Isolate.current),
        debugName: 'golib-netpoller',
        onExit: port.sendPort,
      );
      await p._ready.future;
    } catch (_) {
      port.close();
      sf.close(efd);
      _starting = null;
      rethrow;
    }
    port.keepIsolateAlive = p._holds > 0;
    _live = p;
    _starting = null;
    return p;
  }

  final RawReceivePort _port;
  final int _efd;
  final _ready = Completer<void>();
  late final SendPort _cmd;

  final _watches = <int, PollWatch>{};
  final _acks = <(int, int), void Function()>{};
  int _holds = 0;
  bool _kickPending = false;

  /// O auxiliar morreu (erro dentro dele): toda espera acorda e falha.
  bool dead = false;

  static final Uint8List _one = Uint8List(8)
    ..buffer.asByteData().setUint64(0, 1, Endian.host);

  /// Esperas e `close` pendentes seguram o isolate vivo.
  void hold() {
    if (_holds++ == 0 && !dead) _port.keepIsolateAlive = true;
  }

  void release() {
    if (--_holds == 0 && !dead) _port.keepIsolateAlive = false;
  }

  /// Arma [events] (`POLLIN`/`POLLOUT`) de [w] no auxiliar.
  void arm(PollWatch w, int events) {
    if (dead) return;
    _watches[w.fd] = w;
    if (w.armed & events == events) return;
    w.armed |= events;
    _cmd.send(Int64List.fromList([opArm, w.fd, w.token, events]));
    _kick();
  }

  /// Tira [w] do auxiliar e chama [onAck] quando ele confirmar (só então o
  /// fd pode ser fechado). Sem auxiliar vivo, [onAck] roda na hora.
  void forget(PollWatch w, void Function() onAck) {
    if (identical(_watches[w.fd], w)) _watches.remove(w.fd);
    w.armed = 0;
    if (dead) {
      onAck();
      return;
    }
    hold();
    _acks[(w.fd, w.token)] = onAck;
    _cmd.send(Int64List.fromList([opForget, w.fd, w.token]));
    _kick();
  }

  /// Acorda o `poll` do auxiliar (uma escrita no `eventfd` por microtask).
  void _kick() {
    if (_kickPending) return;
    _kickPending = true;
    scheduleMicrotask(() {
      _kickPending = false;
      if (!dead) sf.write(_efd, _one);
    });
  }

  void _onMessage(Object? m) {
    if (m is SendPort) {
      _cmd = m;
      _ready.complete();
      return;
    }
    if (m is Int64List) {
      switch (m[0]) {
        case kindEvents:
          for (var i = 1; i + 2 < m.length; i += 3) {
            _onEvent(m[i], m[i + 1], m[i + 2]);
          }
        case kindAck:
          final cb = _acks.remove((m[1], m[2]));
          if (cb != null) {
            cb();
            release();
          }
      }
      return;
    }
    // `onExit` do auxiliar: morreu antes do principal.
    _die();
  }

  void _onEvent(int fd, int token, int rev) {
    final w = _watches[fd];
    if (w == null || w.token != token) return;
    final broken = rev & pollBroken != 0;
    final fired = broken ? w.armed : rev & w.armed;
    w.armed &= ~fired;
    if (broken || rev & (sf.POLLIN | sf.POLLRDHUP) != 0) w.wakeReaders();
    if (broken || rev & sf.POLLOUT != 0) w.wakeWriters();
    if (w.armed == 0 && w.readers.isEmpty && w.writers.isEmpty) {
      _watches.remove(fd);
    }
  }

  void _die() {
    if (dead) return;
    dead = true;
    if (identical(_live, this)) _live = null;
    _port.close();
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('golib-netpoller não subiu'));
    }
    for (final w in _watches.values) {
      w
        ..armed = 0
        ..wakeReaders()
        ..wakeWriters();
    }
    _watches.clear();
    final acks = List.of(_acks.values);
    _acks.clear();
    for (final cb in acks) {
      cb();
    }
  }
}
