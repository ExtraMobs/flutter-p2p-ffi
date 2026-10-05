import 'dart:async';
import 'dart:io';

/// Prontidão de I/O de um [RawSocket] (ou [RawDatagramSocket]): o `pollDesc`
/// do Go (`internal/poll/fd_poll_runtime.go`), com os eventos do socket no
/// papel do netpoller. O `Fd` estaciona em [waitRead]/[waitWrite] e, ao
/// fechar, chama [evict] e [close].
///
/// Prazos (`SetReadDeadline`/`SetWriteDeadline` do Go) vivem aqui como no
/// `pollDesc` do runtime: um temporizador por direção marca [readExpired] /
/// [writeExpired] e acorda quem estiver estacionado naquela direção; mudar o
/// prazo vale também para a espera já pendente.
final class PollDesc {
  PollDesc(RawSocket socket)
    : this._(
        socket,
        (v) => socket.readEventsEnabled = v,
        (v) => socket.writeEventsEnabled = v,
      );

  /// Mesma prontidão sobre um socket UDP (`RawDatagramSocket`), que não tem
  /// `readClosed`.
  PollDesc.datagram(RawDatagramSocket socket)
    : this._(
        socket,
        (v) => socket.readEventsEnabled = v,
        (v) => socket.writeEventsEnabled = v,
      );

  PollDesc._(
    Stream<RawSocketEvent> events,
    this._setReadEvents,
    this._setWriteEvents,
  ) {
    // Interesse em escrita é registrado sob demanda, em [waitWrite].
    _setWriteEvents(false);
    _subscription = events.listen(
      _onEvent,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  final void Function(bool) _setReadEvents;
  final void Function(bool) _setWriteEvents;
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

  /// O prazo de leitura venceu (`pd.rd < 0` no runtime do Go).
  bool readExpired = false;

  /// O prazo de escrita venceu (`pd.wd < 0` no runtime do Go).
  bool writeExpired = false;

  Timer? _readTimer;
  Timer? _writeTimer;

  /// Estaciona até o socket aceitar escrita, [evict] ou o prazo vencer.
  Future<void> waitWrite() {
    // Já despejado (erro assíncrono, par fechou): ninguém mais acordaria esta
    // espera.
    if (evicted || writeExpired) return Future<void>.value();
    final waiter = Completer<void>();
    _writeWaiter = waiter;
    // One-shot: precisa ser religado a cada espera.
    _setWriteEvents(true);
    return waiter.future;
  }

  /// Estaciona até haver dado, fim de leitura, [evict] ou o prazo vencer.
  Future<void> waitRead() {
    if (evicted || readExpired) return Future<void>.value();
    final waiter = Completer<void>();
    _readWaiter = waiter;
    // Interesse em leitura de novo (desligado no último `read`, ver
    // [_onEvent]).
    _setReadEvents(true);
    return waiter.future;
  }

  /// O leitor esvaziou o que estava disponível: volta a ouvir leitura (o
  /// próximo dado, ou o `readClosed` do par, chegam sem esperar a próxima
  /// [waitRead]).
  void drained() {
    readable = false;
    _setReadEvents(true);
  }

  /// `SetReadDeadline`: `null` tira o prazo; no passado, vence na hora.
  void setReadDeadline(DateTime? d) {
    _readTimer?.cancel();
    _readTimer = null;
    readExpired = false;
    if (d == null) return;
    _readTimer = _arm(d, () {
      _readTimer = null;
      readExpired = true;
      _wakeRead();
    });
  }

  /// `SetWriteDeadline`: `null` tira o prazo; no passado, vence na hora.
  void setWriteDeadline(DateTime? d) {
    _writeTimer?.cancel();
    _writeTimer = null;
    writeExpired = false;
    if (d == null) return;
    _writeTimer = _arm(d, () {
      _writeTimer = null;
      writeExpired = true;
      _wakeWrite();
    });
  }

  static Timer? _arm(DateTime d, void Function() fire) {
    final wait = d.difference(DateTime.now());
    if (wait <= Duration.zero) {
      fire();
      return null;
    }
    return Timer(wait, fire);
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
  Future<void> close() {
    _readTimer?.cancel();
    _writeTimer?.cancel();
    _readTimer = _writeTimer = null;
    return _subscription.cancel();
  }

  void _onEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.read:
        readable = true;
        // Borda, como o netpoller: o `dart:io` reemite `read` numa microtask
        // atrás da outra enquanto houver dado não lido (`issueReadEvent`), o
        // que, com ninguém lendo (prazo vencido, leitor ocupado), trava o
        // laço de eventos — nem temporizador dispara. Desliga até a próxima
        // espera ([waitRead]).
        _setReadEvents(false);
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
