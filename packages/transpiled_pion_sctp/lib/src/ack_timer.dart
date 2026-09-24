// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `ack_timer.go` (github.com/pion/sctp): [AckTimer], the delayed-SACK
/// timer (RFC 4960 sec 6.2).
///
/// `ackTimer` is unexported in Go; [AckTimer] stays public within `lib/src`
/// (see util.dart's file-level doc comment) but is not exported from
/// `transpiled_pion_sctp.dart`.
///
/// See `rtx_timer.dart`'s file-level doc comment for why the `sync.Mutex`
/// and `pending uint8` counter Go uses to survive a true concurrent
/// timer-callback/`start`/`stop`/`close` race are dropped here: Dart's
/// single-threaded event loop makes that race impossible.
library;

import 'dart:async';

/// Port of `ackInterval` (ack_timer.go:13).
const Duration ackInterval = Duration(milliseconds: 200);

/// Port of `ackTimerObserver` (ack_timer.go:16-18).
abstract interface class AckTimerObserver {
  /// Port of `ackTimerObserver.onAckTimeout` (ack_timer.go:18).
  void onAckTimeout();
}

/// Port of `ackTimerState` (ack_timer.go:21) and its constants
/// (ack_timer.go:23-27).
enum AckTimerState {
  /// Port of `ackTimerStopped` (ack_timer.go:24).
  stopped,

  /// Port of `ackTimerStarted` (ack_timer.go:25).
  started,

  /// Port of `ackTimerClosed` (ack_timer.go:26).
  closed,
}

/// Port of `ackTimer` (ack_timer.go:30-36): the acknowledgement timer used
/// to enable delayed ack, conforming to RFC 4960 Sec 6.3.1. See this file's
/// doc comment for the mutex/`pending`-counter adaptation.
final class AckTimer {
  /// Port of `newAckTimer` (ack_timer.go:39-45).
  AckTimer(this.observer);

  /// Port of `ackTimer.observer` (ack_timer.go:32).
  final AckTimerObserver observer;

  Timer? _timer;
  AckTimerState _state = AckTimerState.stopped;

  /// Port of `ackTimer.timeout` (ack_timer.go:47-54).
  void _timeout() {
    if (_state != AckTimerState.started) {
      return;
    }
    _state = AckTimerState.stopped;
    observer.onAckTimeout();
  }

  /// Port of `ackTimer.start` (ack_timer.go:57-71): starts the timer.
  bool start() {
    // this timer is already closed or already running
    if (_state != AckTimerState.stopped) {
      return false;
    }

    _state = AckTimerState.started;
    _timer = Timer(ackInterval, _timeout);

    return true;
  }

  /// Port of `ackTimer.stop` (ack_timer.go:75-85): stops the timer.
  void stop() {
    if (_state == AckTimerState.started) {
      _timer?.cancel();
      _timer = null;
      _state = AckTimerState.stopped;
    }
  }

  /// Port of `ackTimer.close` (ack_timer.go:89-97): similar to [stop], but a
  /// subsequent [start] call fails -- the timer is no longer usable.
  void close() {
    if (_state == AckTimerState.started) {
      _timer?.cancel();
      _timer = null;
    }
    _state = AckTimerState.closed;
  }

  /// Port of `ackTimer.isRunning` (ack_timer.go:101-106): debug purpose only.
  bool isRunning() => _state == AckTimerState.started;
}
