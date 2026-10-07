/// O lado auxiliar do poller (`poller.dart`): o laço de `poll(2)` que roda
/// num isolate próprio, um por isolate que usa a rede FFI.
///
/// Protocolo (listas de `int` pelos ports; quem manda já escreveu no
/// `eventfd` depois, então o `poll` acorda e o comando é tratado na volta do
/// laço de eventos):
///
/// - principal → auxiliar: `[opArm, fd, token, eventos]` acrescenta interesse
///   (um disparo: o que for relatado sai do conjunto);
///   `[opForget, fd, token]` tira o fd e responde `[kindAck, fd, token]`.
///   O auxiliar encerra (e fecha o `eventfd`) quando o isolate principal sai.
/// - auxiliar → principal: primeiro o próprio `SendPort`; depois
///   `[kindEvents, fd, token, revents, ...]` por volta
///   do `poll`; `[kindAck, fd, token]`.
///
/// O `poll` vai em fatias de [pollSliceMs]: um `poll(-1)` num isolate
/// auxiliar impede a VM de encerrar (medido). Entre as fatias o isolate volta
/// ao laço de eventos e trata os comandos.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../sysffi/sysffi.dart' as sf;

const opArm = 1;
const opForget = 2;

const kindEvents = 1;
const kindAck = 2;

/// Fatia de cada `poll(2)`, em ms.
const pollSliceMs = 250;

/// Erro, fim de conexão ou fd inválido: acorda as duas direções.
const pollBroken = sf.POLLERR | sf.POLLHUP | sf.POLLNVAL;

/// Mensagem de partida: port do principal, o `eventfd` e o isolate
/// principal (para morrer com ele).
typedef PollerBoot = (SendPort, int, Isolate);

/// Entrada do isolate auxiliar.
void pollerMain(PollerBoot boot) {
  final (toMain, efd, main) = boot;
  final rp = RawReceivePort(null, 'golib-netpoller-cmd');
  final interest = <int, (int token, int events)>{};
  var stopped = false;
  var cap = 16;
  var pfds = sf.libcAlloc<sf.PollFd>(cap);
  final drain = Uint8List(8);

  void stop() {
    if (stopped) return;
    stopped = true;
    rp.close();
    sf.close(efd);
    sf.libcAlloc.free(pfds);
  }

  rp.handler = (Object? m) {
    if (m is! List<Object?>) {
      // O isolate principal saiu (`addOnExitListener`).
      stop();
      return;
    }
    final op = m[0] as int;
    switch (op) {
      case opArm:
        final fd = m[1] as int, token = m[2] as int, ev = m[3] as int;
        final cur = interest[fd];
        interest[fd] = cur != null && cur.$1 == token
            ? (token, cur.$2 | ev)
            : (token, ev);
      case opForget:
        final fd = m[1] as int, token = m[2] as int;
        final cur = interest[fd];
        if (cur != null && cur.$1 == token) interest.remove(fd);
        toMain.send(Int64List.fromList([kindAck, fd, token]));
    }
  };
  main.addOnExitListener(rp.sendPort, response: 'exit');

  void loop() {
    if (stopped) return;
    final n = interest.length + 1;
    if (n > cap) {
      sf.libcAlloc.free(pfds);
      while (cap < n) {
        cap *= 2;
      }
      pfds = sf.libcAlloc<sf.PollFd>(cap);
    }
    pfds[0]
      ..fd = efd
      ..events = sf.POLLIN
      ..revents = 0;
    var i = 1;
    for (final MapEntry(key: fd, value: (_, ev)) in interest.entries) {
      pfds[i]
        ..fd = fd
        ..events = ev
        ..revents = 0;
      i++;
    }
    final r = sf.poll(pfds, n, pollSliceMs);
    if (r > 0) {
      if (pfds[0].revents != 0) sf.read(efd, drain);
      List<int>? out;
      for (var k = 1; k < n; k++) {
        final rev = pfds[k].revents;
        if (rev == 0) continue;
        final fd = pfds[k].fd;
        final cur = interest[fd];
        if (cur == null) continue;
        final (token, ev) = cur;
        final fired = rev & pollBroken != 0 ? ev : rev & ev;
        final left = ev & ~fired;
        if (left == 0) {
          interest.remove(fd);
        } else {
          interest[fd] = (token, left);
        }
        (out ??= [kindEvents])
          ..add(fd)
          ..add(token)
          ..add(rev);
      }
      if (out != null) toMain.send(Int64List.fromList(out));
    }
    // Volta ao laço de eventos (os comandos chegam como mensagens) e repete.
    Timer.run(loop);
  }

  toMain.send(rp.sendPort);
  Timer.run(loop);
}
