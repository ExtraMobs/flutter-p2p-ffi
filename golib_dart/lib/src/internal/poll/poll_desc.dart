import 'dart:async';
import 'dart:io';

/// Prontidão de I/O de um [RawSocket]: o `pollDesc` do Go
/// (`internal/poll/fd_poll_runtime.go`), com os eventos do socket no papel do
/// netpoller. O `Fd` estaciona em [waitRead]/[waitWrite] e, ao fechar, chama
/// [evict] e [close].
final class PollDesc {
  PollDesc(this._socket) {
    // Interesse em escrita é registrado sob demanda, em [waitWrite].
    _socket.writeEventsEnabled = false;
    _subscription = _socket.listen(
      _onEvent,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  final RawSocket _socket;
  late final StreamSubscription<RawSocketEvent> _subscription;

  Completer<void>? _readWaiter;
  Completer<void>? _writeWaiter;

  /// O par sinalizou fim de leitura (`RawSocketEvent.readClosed`).
  bool readClosed = false;

  /// Prontidão de leitura anunciada por `RawSocketEvent.read` e ainda não
  /// consumida. Faz o papel que, no Go, cabe ao retorno do próprio `read(2)`.
  bool readable = false;

  /// Toda espera foi desbloqueada de vez ([evict]).
  bool evicted = false;

  /// Erro assíncrono do socket, relançado a quem acordar.
  Object? ioError;

  /// Estaciona até o socket aceitar escrita.
  Future<void> waitWrite() {
    final waiter = Completer<void>();
    _writeWaiter = waiter;
    // One-shot: precisa ser religado a cada espera.
    _socket.writeEventsEnabled = true;
    return waiter.future;
  }

  /// Estaciona até haver dado, fim de leitura ou [evict].
  Future<void> waitRead() {
    final waiter = Completer<void>();
    _readWaiter = waiter;
    return waiter.future;
  }

  /// Desbloqueia toda espera de I/O pendente.
  ///
  /// Port de `pollDesc.evict`. Quem acorda reavalia o estado e desiste com o
  /// sentinela, exatamente como no Go, onde "any attempts to block in the
  /// pollDesc will return errClosing".
  void evict() {
    evicted = true;
    _wakeRead();
    _wakeWrite();
  }

  /// Desregistra do "poller": no Go, `fd.pd.close()` precede o fechamento em
  /// `FD.destroy`.
  Future<void> close() => _subscription.cancel();

  void _onEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.read:
        readable = true;
        _wakeRead();
      case RawSocketEvent.write:
        _wakeWrite();
      case RawSocketEvent.readClosed:
        readClosed = true;
        _wakeRead();
      case RawSocketEvent.closed:
        // O par encerrou por completo: equivale à eviction do poller.
        evict();
    }
  }

  void _onError(Object error, StackTrace stack) {
    ioError = error;
    evict();
  }

  void _onDone() {
    readClosed = true;
    evict();
  }

  void _wakeRead() {
    final waiter = _readWaiter;
    _readWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _wakeWrite() {
    final waiter = _writeWaiter;
    _writeWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }
}
