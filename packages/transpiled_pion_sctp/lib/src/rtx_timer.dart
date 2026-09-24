// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `rtx_timer.go` (github.com/pion/sctp): [RtoManager] (RFC 4960
/// sec 6.3.1 RTO estimation) and [RtxTimer], the retransmission timer built
/// on it.
///
/// `rtoManager` and `rtxTimer` are unexported in Go; both stay public
/// within `lib/src` (see util.dart's file-level doc comment) but are not
/// exported from `transpiled_pion_sctp.dart`.
///
/// Go's `rtxTimer` guards its state with a `sync.Mutex` and a `pending
/// uint8` counter (rtx_timer.go:138,142) solely to detect the race between
/// `time.AfterFunc`'s callback firing on its own goroutine and a concurrent
/// `start`/`stop`/`close` call -- the same race `transpiled_pion_transport`'s
/// `Deadline` documents (see its file-level doc comment). Dart has no such
/// race: a `Timer` callback can never run concurrently with the code that
/// scheduled it, so `cancel()` called synchronously before the callback's
/// turn on the event loop always succeeds. Both the mutex and the `pending`
/// counter are dropped for the same reason `Deadline` drops them; every
/// other field and the `stopped`/`started`/`closed` state machine, the
/// backoff formula, and the RTO estimator are ported as-is.
library;

import 'dart:async';
import 'dart:math';

/// RTO.Initial in msec. Port of `rtoInitial` (rtx_timer.go:14).
const double rtoInitial = 1.0 * 1000;

/// RTO.Min in msec. Port of `rtoMin` (rtx_timer.go:17).
const double rtoMin = 1.0 * 1000;

/// RTO.Max in msec. Port of `defaultRTOMax` (rtx_timer.go:20).
const double defaultRtoMax = 60.0 * 1000;

/// RTO.Alpha. Port of `rtoAlpha` (rtx_timer.go:23).
const double rtoAlpha = 0.125;

/// RTO.Beta. Port of `rtoBeta` (rtx_timer.go:26).
const double rtoBeta = 0.25;

/// Max.Init.Retransmits. Port of `maxInitRetrans` (rtx_timer.go:29).
const int maxInitRetrans = 8;

/// Path.Max.Retrans. Port of `pathMaxRetrans` (rtx_timer.go:32).
const int pathMaxRetrans = 5;

/// Port of `noMaxRetrans` (rtx_timer.go:34).
const int noMaxRetrans = 0;

/// Port of `rtoManager` (rtx_timer.go:39-46): manages Rtx timeout values, an
/// implementation of RFC 4960 sec 6.3.1.
final class RtoManager {
  /// Port of `newRTOManager` (rtx_timer.go:49-59).
  RtoManager(double rtoMaxValue)
    : rto = rtoInitial,
      rtoMax = rtoMaxValue == 0 ? defaultRtoMax : rtoMaxValue;

  /// Port of `rtoManager.srtt` (rtx_timer.go:40).
  double srtt = 0;

  /// Port of `rtoManager.rttvar` (rtx_timer.go:41).
  double rttvar = 0;

  /// Port of `rtoManager.rto` (rtx_timer.go:42).
  double rto;

  /// Port of `rtoManager.noUpdate` (rtx_timer.go:43).
  bool noUpdate = false;

  /// Port of `rtoManager.rtoMax` (rtx_timer.go:45).
  final double rtoMax;

  /// Port of `rtoManager.setNewRTT` (rtx_timer.go:62-82): takes a newly
  /// measured RTT then adjusts the RTO, in msec.
  double setNewRTT(double rtt) {
    if (noUpdate) {
      return srtt;
    }

    if (srtt == 0) {
      // First measurement
      srtt = rtt;
      rttvar = rtt / 2;
    } else {
      // Subsequent rtt measurement
      rttvar = (1 - rtoBeta) * rttvar + rtoBeta * (srtt - rtt).abs();
      srtt = (1 - rtoAlpha) * srtt + rtoAlpha * rtt;
    }
    rto = min(max(srtt + 4 * rttvar, rtoMin), rtoMax);

    return srtt;
  }

  /// Port of `rtoManager.getRTO` (rtx_timer.go:85-90): the current RTO, in
  /// msec.
  double getRTO() => rto;

  /// Port of `rtoManager.reset` (rtx_timer.go:93-104): resets the RTO
  /// variables to their initial values.
  void reset() {
    if (noUpdate) {
      return;
    }
    srtt = 0;
    rttvar = 0;
    rto = rtoInitial;
  }

  /// Port of `rtoManager.setRTO` (rtx_timer.go:107-113): sets the RTO value,
  /// for testing.
  void setRTO(double rtoValue, bool noUpdateValue) {
    rto = rtoValue;
    noUpdate = noUpdateValue;
  }
}

/// Port of `rtxTimerObserver` (rtx_timer.go:118-121). NOTE: observers MUST
/// NOT call [RtxTimer.start] or [RtxTimer.stop] from within these callbacks.
abstract interface class RtxTimerObserver {
  /// Port of `rtxTimerObserver.onRetransmissionTimeout` (rtx_timer.go:119).
  void onRetransmissionTimeout(int timerId, int n);

  /// Port of `rtxTimerObserver.onRetransmissionFailure` (rtx_timer.go:120).
  void onRetransmissionFailure(int timerId);
}

/// Port of `rtxTimerState` (rtx_timer.go:123) and its constants
/// (rtx_timer.go:125-129).
enum RtxTimerState {
  /// Port of `rtxTimerStopped` (rtx_timer.go:126).
  stopped,

  /// Port of `rtxTimerStarted` (rtx_timer.go:127).
  started,

  /// Port of `rtxTimerClosed` (rtx_timer.go:128).
  closed,
}

/// Port of `rtxTimer` (rtx_timer.go:132-143): the retransmission timer
/// conforming to RFC 4960 Sec 6.3.1. See this file's doc comment for the
/// mutex/`pending`-counter adaptation.
final class RtxTimer {
  /// Port of `newRTXTimer` (rtx_timer.go:148-164): if `maxRetrans` is 0, it
  /// keeps retransmitting until [stop] is called (it never calls
  /// [RtxTimerObserver.onRetransmissionFailure]).
  RtxTimer(this.id, this.observer, this.maxRetrans, double rtoMaxValue)
    : rtoMax = rtoMaxValue == 0 ? defaultRtoMax : rtoMaxValue;

  /// Port of `rtxTimer.id` (rtx_timer.go:135).
  final int id;

  /// Port of `rtxTimer.observer` (rtx_timer.go:134).
  final RtxTimerObserver observer;

  /// Port of `rtxTimer.maxRetrans` (rtx_timer.go:136).
  final int maxRetrans;

  /// Port of `rtxTimer.rtoMax` (rtx_timer.go:137).
  final double rtoMax;

  Timer? _timer;
  double _rto = 0;

  /// Port of `rtxTimer.nRtos` (rtx_timer.go:140).
  int nRtos = 0;

  RtxTimerState _state = RtxTimerState.stopped;

  /// Port of `rtxTimer.calculateNextTimeout` (rtx_timer.go:166-170).
  Duration _calculateNextTimeoutDuration() {
    final timeout = calculateNextTimeout(_rto, nRtos, rtoMax);
    return Duration(microseconds: (timeout * 1000).round());
  }

  /// Port of `rtxTimer.timeout` (rtx_timer.go:172-185).
  void _timeout() {
    if (_state != RtxTimerState.started) {
      return;
    }
    nRtos++;
    if (maxRetrans == 0 || nRtos <= maxRetrans) {
      _timer = Timer(_calculateNextTimeoutDuration(), _timeout);
      observer.onRetransmissionTimeout(id, nRtos);
    } else {
      _state = RtxTimerState.stopped;
      observer.onRetransmissionFailure(id);
    }
  }

  /// Port of `rtxTimer.start` (rtx_timer.go:188-208): starts the timer.
  bool start(double rto) {
    // this timer is already closed or already running
    if (_state != RtxTimerState.stopped) {
      return false;
    }

    // Note: rto value is intentionally not capped by RTO.Min to allow
    // fast timeout for the tests. Non-test code should pass in the rto
    // generated by rtoManager getRTO() method which caps the value at
    // RTO.Min or at RTO.Max.
    _rto = rto;
    nRtos = 0;
    _state = RtxTimerState.started;
    _timer = Timer(_calculateNextTimeoutDuration(), _timeout);

    return true;
  }

  /// Port of `rtxTimer.stop` (rtx_timer.go:211-221): stops the timer.
  void stop() {
    if (_state == RtxTimerState.started) {
      _timer?.cancel();
      _timer = null;
      _state = RtxTimerState.stopped;
    }
  }

  /// Port of `rtxTimer.close` (rtx_timer.go:224-233): similar to [stop], but
  /// a subsequent [start] call fails -- the timer is no longer usable.
  void close() {
    if (_state == RtxTimerState.started) {
      _timer?.cancel();
      _timer = null;
    }
    _state = RtxTimerState.closed;
  }

  /// Port of `rtxTimer.isRunning` (rtx_timer.go:236-242): debug purpose only.
  bool isRunning() => _state == RtxTimerState.started;
}

/// Port of the top-level `calculateNextTimeout` (rtx_timer.go:244-257).
double calculateNextTimeout(double rto, int nRtos, double rtoMax) {
  // RFC 4096 sec 6.3.3. Handle T3-rtx Expiration
  //   E2) For the destination address for which the timer expires, set RTO
  //       <- RTO * 2 ("back off the timer"). The maximum value discussed in
  //       rule C7 above (RTO.max) may be used to provide an upper bound to
  //       this doubling operation.
  if (nRtos < 31) {
    final m = 1 << nRtos;
    return min(rto * m, rtoMax);
  }
  return rtoMax;
}
