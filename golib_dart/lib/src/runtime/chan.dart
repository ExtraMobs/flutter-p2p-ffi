/// `chan T` do Go: `make(chan T, n)`, envio, recebimento e o canal nil.
/// `select` está em `select.dart` (usa a API `$`-prefixada abaixo).
library;

import 'dart:async';
import 'dart:collection';

import 'panic.dart';
import 'sched.dart';

class _RecvWaiter<T> {
  _RecvWaiter(this.onValue);
  final void Function(T value, bool ok) onValue;
  bool cancelled = false;
}

class _SendWaiter<T> {
  _SendWaiter(this.value, this.onDone);
  final T value;

  /// `false`: valor entregue. `true`: canal fechou antes (o send panica).
  final void Function(bool closed) onDone;
  bool cancelled = false;
}

/// `chan T` do Go.
///
/// Identidade por referência (`==` de canal Go): [Chan] não sobrescreve
/// `==`/`hashCode`, então a identidade do `Object` já é a semântica certa.
///
/// FIFO de remetentes e de receptores, como o runtime do Go: sem buffer, a
/// entrega é direta (o `send` só volta quando um `recv` pegou o valor); com
/// buffer, vira fila — um `send` só bloqueia com o buffer cheio, e um valor
/// que sai do buffer libera lugar para o remetente mais antigo em espera.
final class Chan<T> {
  /// `make(chan T, cap)`. [zero] é o valor zero de T, devolvido no `recv` de
  /// canal fechado (drenado ou não).
  Chan(int cap, this.zero) : _cap = _checkSize(cap);

  final T zero;
  final int _cap;
  final _buf = Queue<T>();
  final _recvQ = Queue<_RecvWaiter<T>>();
  final _sendQ = Queue<_SendWaiter<T>>();
  bool _closed = false;

  /// Bem acima de qualquer uso razoável; o Go rejeita pelo tamanho da
  /// alocação (`elem.Size_ * n` contra o espaço de endereços), que não temos
  /// como calcular aqui (T é um tipo Dart, não um layout Go) — isto cobre o
  /// caso que interessa (`n` negativo ou absurdo) sem fingir o cálculo real.
  static const _maxSize = 1 << 30;

  static int _checkSize(int n) {
    if (n < 0 || n > _maxSize) {
      throw Panic(const RuntimeError('makechan: size out of range'));
    }
    return n;
  }

  /// `len(ch)`.
  int get len => _buf.length;

  /// `cap(ch)`.
  int get cap => _cap;

  // -------------------------------------------------------- API pública

  /// `ch <- v`.
  Future<void> send(T v) async {
    if ($sendReady()) {
      $commitSend(v);
      return;
    }
    final completer = Completer<void>();
    final cancel = $registerSendWaiter(v, (closed) {
      if (completer.isCompleted) return;
      if (closed) {
        completer.completeError(
          Panic(const RuntimeError('send on closed channel')),
        );
      } else {
        completer.complete();
      }
    });
    goroutineBlocked();
    try {
      await completer.future;
    } finally {
      goroutineUnblocked();
      cancel();
    }
  }

  /// `<-ch` (sem comma-ok): zero e descarta `ok` num canal fechado e vazio.
  Future<T> recv() async => (await recv2()).$1;

  /// `v, ok := <-ch`.
  Future<(T, bool)> recv2() async {
    if ($recvReady()) return $commitRecv();
    final completer = Completer<(T, bool)>();
    final cancel = $registerRecvWaiter((v, ok) {
      if (!completer.isCompleted) completer.complete((v, ok));
    });
    goroutineBlocked();
    try {
      return await completer.future;
    } finally {
      goroutineUnblocked();
      cancel();
    }
  }

  /// `close(ch)`.
  void close() {
    if (_closed) throw Panic(const RuntimeError('close of closed channel'));
    _closed = true;
    while (_recvQ.isNotEmpty) {
      final w = _recvQ.removeFirst();
      if (!w.cancelled) w.onValue(zero, false);
    }
    while (_sendQ.isNotEmpty) {
      final w = _sendQ.removeFirst();
      if (!w.cancelled) w.onDone(true);
    }
  }

  // ---------------------------------------- API interna (usada por `select`)
  //
  // `$`-prefixada: não é Go (o prefixo nunca aparece num nome Go), mas
  // precisa ser pública para `select.dart` — outro arquivo, mesmo pacote —
  // enxergar. Mesma convenção de `$copy`/`$fields` etc. em `struct.dart`.

  /// Um `send` completaria agora sem suspender? (Só olha; sem efeito.)
  bool $sendReady() => _closed || _hasLiveRecvWaiter() || _buf.length < _cap;

  /// Um `recv` completaria agora sem suspender? (Só olha; sem efeito.)
  bool $recvReady() => _buf.isNotEmpty || _hasLiveSendWaiter() || _closed;

  /// Executa o envio já sabendo, por [$sendReady], que ele não bloqueia.
  void $commitSend(T v) {
    if (_closed) throw Panic(const RuntimeError('send on closed channel'));
    final w = _popLiveRecvWaiter();
    if (w != null) {
      w.onValue(v, true);
      return;
    }
    _buf.add(v);
  }

  /// Executa o recebimento já sabendo, por [$recvReady], que ele não
  /// bloqueia.
  (T, bool) $commitRecv() {
    if (_buf.isNotEmpty) {
      final v = _buf.removeFirst();
      _promoteOneSender();
      return (v, true);
    }
    final w = _popLiveSendWaiter();
    if (w != null) {
      w.onDone(false);
      return (w.value, true);
    }
    return (zero, false); // fechado, buffer e fila de envio vazios.
  }

  /// Registra um recebimento pendente: `onValue` roda quando um valor
  /// chegar (ou o canal fechar). Devolve como cancelar o registro (usado
  /// pelo `select` para retirar os casos não escolhidos).
  void Function() $registerRecvWaiter(
    void Function(T value, bool ok) onValue,
  ) {
    final w = _RecvWaiter<T>(onValue);
    _recvQ.add(w);
    return () => w.cancelled = true;
  }

  /// Registra um envio pendente: `onDone(false)` quando entregue,
  /// `onDone(true)` se o canal fechar antes. Devolve como cancelar.
  void Function() $registerSendWaiter(T v, void Function(bool closed) onDone) {
    final w = _SendWaiter<T>(v, onDone);
    _sendQ.add(w);
    return () => w.cancelled = true;
  }

  bool _hasLiveRecvWaiter() {
    while (_recvQ.isNotEmpty && _recvQ.first.cancelled) {
      _recvQ.removeFirst();
    }
    return _recvQ.isNotEmpty;
  }

  bool _hasLiveSendWaiter() {
    while (_sendQ.isNotEmpty && _sendQ.first.cancelled) {
      _sendQ.removeFirst();
    }
    return _sendQ.isNotEmpty;
  }

  _RecvWaiter<T>? _popLiveRecvWaiter() {
    while (_recvQ.isNotEmpty) {
      final w = _recvQ.removeFirst();
      if (!w.cancelled) return w;
    }
    return null;
  }

  _SendWaiter<T>? _popLiveSendWaiter() {
    while (_sendQ.isNotEmpty) {
      final w = _sendQ.removeFirst();
      if (!w.cancelled) return w;
    }
    return null;
  }

  void _promoteOneSender() {
    if (_buf.length >= _cap) return;
    final w = _popLiveSendWaiter();
    if (w != null) {
      _buf.add(w.value);
      w.onDone(false);
    }
  }
}

// ------------------------------------------------------- Canal nil (`Chan?`)
//
// `var ch chan T` sem `make`: um `Chan<T>?` nulo. `send`/`recv` num nil
// bloqueiam para sempre (contam como bloqueada pro detector de deadlock);
// `close` panica; `len`/`cap` valem 0.

Future<T> _blockForever<T>() {
  goroutineBlocked();
  return Completer<T>().future; // nunca completa: bloqueio permanente.
}

/// `ch <- v` com `ch` possivelmente nil.
Future<void> chanSend<T>(Chan<T>? c, T v) {
  if (c == null) return _blockForever<void>();
  return c.send(v);
}

/// `<-ch` com `ch` possivelmente nil.
Future<T> chanRecv<T>(Chan<T>? c) {
  if (c == null) return _blockForever<T>();
  return c.recv();
}

/// `v, ok := <-ch` com `ch` possivelmente nil.
Future<(T, bool)> chanRecv2<T>(Chan<T>? c) {
  if (c == null) return _blockForever<(T, bool)>();
  return c.recv2();
}

/// `close(ch)` com `ch` possivelmente nil: panic, como no Go.
void chanClose<T>(Chan<T>? c) {
  if (c == null) throw Panic(const RuntimeError('close of nil channel'));
  c.close();
}

/// `len(ch)`; nil devolve 0.
int chanLen(Chan? c) => c?.len ?? 0;

/// `cap(ch)`; nil devolve 0.
int chanCap(Chan? c) => c?.cap ?? 0;
