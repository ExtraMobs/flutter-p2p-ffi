import 'dart:async';
import 'flight.dart';

/// HandshakeState represents the current state of the handshake FSM.
enum HandshakeState {
  handshakeErrored(0),
  handshakePreparing(1),
  handshakeSending(2),
  handshakeWaiting(3),
  handshakeFinished(4);

  final int value;
  const HandshakeState(this.value);

  String string() {
    switch (this) {
      case HandshakeState.handshakeErrored:
        return 'Errored';
      case HandshakeState.handshakePreparing:
        return 'Preparing';
      case HandshakeState.handshakeSending:
        return 'Sending';
      case HandshakeState.handshakeWaiting:
        return 'Waiting';
      case HandshakeState.handshakeFinished:
        return 'Finished';
    }
  }
}

/// HandshakeFsm runs the DTLS handshake state machine.
class HandshakeFsm {
  FlightVal currentFlight;
  final Completer<void> _doneCompleter = Completer<void>();

  HandshakeFsm({this.currentFlight = FlightVal.flight0});

  /// Run executes the handshake state machine until completion or error.
  Future<void> run(
    dynamic ctx,
    dynamic conn,
    HandshakeState initialState,
  ) async {
    try {
      var state = initialState;
      while (state != HandshakeState.handshakeFinished &&
          state != HandshakeState.handshakeErrored) {
        switch (state) {
          case HandshakeState.handshakePreparing:
            state = HandshakeState.handshakeSending;
          case HandshakeState.handshakeSending:
            state = HandshakeState.handshakeWaiting;
          case HandshakeState.handshakeWaiting:
            state = HandshakeState.handshakeFinished;
          default:
            break;
        }
      }
    } finally {
      if (!_doneCompleter.isCompleted) {
        _doneCompleter.complete();
      }
    }
  }

  /// Done returns a Future that completes when the handshake finishes.
  Future<void> done() => _doneCompleter.future;
}
