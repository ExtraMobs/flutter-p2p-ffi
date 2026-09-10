// ignore_for_file: public_member_api_docs, sort_constructors_first, library_private_types_in_public_api, depend_on_referenced_packages, unused_element_parameter, inference_failure_on_instance_creation, directives_ordering
import 'dart:async';
import 'dart:collection';
import 'package:transpiled_cid/transpiled_cid.dart';

class DontHaveTimeoutConfig {
  final Duration dontHaveTimeout;
  final Duration maxExpectedWantProcessTime;
  final Duration maxTimeout;
  final Duration minTimeout;
  final int pingLatencyMultiplier;
  final double messageLatencyAlpha;
  final int messageLatencyMultiplier;

  // StreamSink for timeoutsSignal (used for testing)
  final StreamSink<void>? timeoutsSignal;

  DontHaveTimeoutConfig({
    required this.dontHaveTimeout,
    required this.maxExpectedWantProcessTime,
    required this.maxTimeout,
    required this.minTimeout,
    required this.pingLatencyMultiplier,
    required this.messageLatencyAlpha,
    required this.messageLatencyMultiplier,
    this.timeoutsSignal,
  });

  factory DontHaveTimeoutConfig.defaultConfig() {
    const dontHaveTimeout = Duration(seconds: 5);
    const maxExpectedWantProcessTime = Duration(seconds: 2);
    return DontHaveTimeoutConfig(
      dontHaveTimeout: dontHaveTimeout,
      minTimeout: const Duration(milliseconds: 50),
      maxExpectedWantProcessTime: maxExpectedWantProcessTime,
      pingLatencyMultiplier: 3,
      messageLatencyAlpha: 0.5,
      messageLatencyMultiplier: 2,
      maxTimeout: dontHaveTimeout + maxExpectedWantProcessTime,
    );
  }
}

abstract class PeerConnection {
  /// Ping the peer. Throws if there is an error, returns the latency.
  Future<Duration> ping(Duration timeout);
  
  /// The average latency of all pings
  Duration latency();
}

class _PendingWant {
  final Cid c;
  bool active;
  final DateTime sent;

  _PendingWant({
    required this.c,
    required this.active,
    required this.sent,
  });
}

typedef OnDontHaveTimeout = void Function(List<Cid> cids, Duration timeout);

class DontHaveTimeoutManager {
  bool _started = false;
  bool _isShutdown = false;
  
  final PeerConnection _peerConn;
  final OnDontHaveTimeout _onDontHaveTimeout;
  final DontHaveTimeoutConfig _config;

  final Map<Cid, _PendingWant> _activeWants = {};
  final Queue<_PendingWant> _wantQueue = Queue();
  
  late Duration _timeout;
  final _LatencyEwma _messageLatency;
  
  Timer? _checkForTimeoutsTimer;

  DontHaveTimeoutManager._(
    this._peerConn,
    this._onDontHaveTimeout,
    this._config,
  ) : _messageLatency = _LatencyEwma(alpha: _config.messageLatencyAlpha) {
    _timeout = _config.dontHaveTimeout;
  }

  static DontHaveTimeoutManager? create(
    PeerConnection pc,
    OnDontHaveTimeout? onDontHaveTimeout, [
    DontHaveTimeoutConfig? cfg,
  ]) {
    if (onDontHaveTimeout == null) return null;
    return DontHaveTimeoutManager._(pc, onDontHaveTimeout, cfg ?? DontHaveTimeoutConfig.defaultConfig());
  }

  void shutdown() {
    _isShutdown = true;
    _checkForTimeoutsTimer?.cancel();
    _checkForTimeoutsTimer = null;
  }

  void start() {
    if (_started || _isShutdown) return;
    _started = true;

    final latency = _peerConn.latency();
    if (latency.inMicroseconds > 0) {
      _timeout = _calculateTimeoutFromPingLatency(latency);
      return;
    }

    _measurePingLatency();
  }

  void updateMessageLatency(Duration elapsed) {
    if (_isShutdown) return;

    _messageLatency.update(elapsed);
    final oldTimeout = _timeout;
    _timeout = _calculateTimeoutFromMessageLatency();

    if (_timeout < oldTimeout) {
      _checkForTimeouts();
    }
  }

  Future<void> _measurePingLatency() async {
    try {
      await _peerConn.ping(_config.dontHaveTimeout);
    } catch (_) {
      return;
    }

    if (_isShutdown) return;

    final latency = _peerConn.latency();

    if (_messageLatency.samples > 0) {
      return;
    }

    _timeout = _calculateTimeoutFromPingLatency(latency);
    _checkForTimeouts();
  }

  void _checkForTimeouts() {
    if (_wantQueue.isEmpty || _isShutdown) return;

    final now = DateTime.now();
    final expired = <Cid>[];

    while (_wantQueue.isNotEmpty) {
      final pw = _wantQueue.first;

      if (pw.active) {
        if (now.difference(pw.sent) < _timeout) {
          break;
        }

        expired.add(pw.c);
        _activeWants.remove(pw.c);
      }

      _wantQueue.removeFirst();
    }

    if (expired.isNotEmpty) {
      _fireTimeout(expired, _timeout);
    }

    if (_wantQueue.isEmpty || _isShutdown) return;

    final oldestStart = _wantQueue.first.sent;
    var until = oldestStart.add(_timeout).difference(now);
    if (until.isNegative) until = Duration.zero;

    _checkForTimeoutsTimer?.cancel();
    _checkForTimeoutsTimer = Timer(until, () {
      if (!_isShutdown) {
        _checkForTimeouts();
      }
    });
  }

  void addPending(List<Cid> ks) {
    if (ks.isEmpty || _isShutdown) return;

    final start = DateTime.now();
    final queueWasEmpty = _activeWants.isEmpty;

    for (final c in ks) {
      if (!_activeWants.containsKey(c)) {
        final pw = _PendingWant(
          c: c,
          sent: start,
          active: true,
        );
        _activeWants[c] = pw;
        _wantQueue.addLast(pw);
      }
    }

    if (queueWasEmpty) {
      _checkForTimeouts();
    }
  }

  void cancelPending(List<Cid> ks) {
    if (_isShutdown) return;

    for (final c in ks) {
      final pw = _activeWants.remove(c);
      if (pw != null) {
        pw.active = false;
      }
    }
  }

  void _fireTimeout(List<Cid> pending, Duration timeout) {
    if (_isShutdown) return;

    // Run asynchronously to simulate `go dhtm.fireTimeout`
    scheduleMicrotask(() {
      if (_isShutdown) return;
      _onDontHaveTimeout(pending, timeout);
      _config.timeoutsSignal?.add(null);
    });
  }

  Duration _calculateTimeoutFromPingLatency(Duration latency) {
    var timeout = _config.maxExpectedWantProcessTime + latency * _config.pingLatencyMultiplier;
    if (timeout > _config.maxTimeout) {
      timeout = _config.maxTimeout;
    } else if (timeout < _config.minTimeout) {
      timeout = _config.minTimeout;
    }
    return timeout;
  }

  Duration _calculateTimeoutFromMessageLatency() {
    var timeout = _messageLatency.latency * _config.messageLatencyMultiplier;
    if (timeout > _config.maxTimeout) {
      timeout = _config.maxTimeout;
    } else if (timeout < _config.minTimeout) {
      timeout = _config.minTimeout;
    }
    return timeout;
  }
}

class _LatencyEwma {
  final double alpha;
  int samples = 0;
  Duration latency = Duration.zero;

  _LatencyEwma({required this.alpha});

  void update(Duration elapsed) {
    samples++;

    var currentAlpha = 1.0 / samples;
    if (currentAlpha < alpha) {
      currentAlpha = alpha;
    }

    final newLatencyUs = (elapsed.inMicroseconds * currentAlpha + latency.inMicroseconds * (1 - currentAlpha)).round();
    latency = Duration(microseconds: newLatencyUs);
  }
}
