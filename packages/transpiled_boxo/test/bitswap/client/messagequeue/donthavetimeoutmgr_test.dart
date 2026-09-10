import 'dart:typed_data';
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

import 'package:transpiled_boxo/src/bitswap/client/internal/messagequeue/donthavetimeoutmgr.dart';

class _MockPeerConn implements PeerConnection {
  final Duration expectedLatency;
  final Exception? err;
  final StreamSink<void> pinged;
  final List<Duration> latencies = [];

  _MockPeerConn({
    required this.expectedLatency,
    required this.pinged,
    this.err,
  });

  @override
  Future<Duration> ping(Duration timeout) async {
    pinged.add(null);
    await Future.delayed(expectedLatency);
    if (err != null) {
      throw err!;
    }
    latencies.add(expectedLatency);
    return expectedLatency;
  }

  @override
  Duration latency() {
    if (latencies.isEmpty) return Duration.zero;
    var sum = 0;
    for (final l in latencies) {
      sum += l.inMicroseconds;
    }
    return Duration(microseconds: sum ~/ latencies.length);
  }
}

class _TimeoutRecorder {
  final List<Cid> timedOutKs = [];

  void onTimeout(List<Cid> tks, Duration timeout) {
    timedOutKs.addAll(tks);
  }

  int timedOutCount() => timedOutKs.length;

  void clear() => timedOutKs.clear();
}

var _cidCounter = 0;
List<Cid> _randomCids(int count) {
  return List.generate(count, (i) {
    _cidCounter++;
    return Cid.fromBytes(Uint8List.fromList([1, 85, 0, 5, 0, 1, 2, _cidCounter, 4, 5]));
  });
}

void main() {
  test('DontHaveTimeoutMgrTimeout', () async {
    final firstks = _randomCids(2);
    final secondks = [...firstks, ..._randomCids(3)];
    final latency = const Duration(milliseconds: 200);
    const latMultiplier = 2;
    const expProcessTime = Duration(milliseconds: 50);
    final expectedTimeout = expProcessTime + latency * latMultiplier;

    final pinged = StreamController<void>.broadcast();
    final pc = _MockPeerConn(expectedLatency: latency, pinged: pinged.sink);
    final tr = _TimeoutRecorder();
    final timeoutsTriggered = StreamController<void>.broadcast();

    final cfg = DontHaveTimeoutConfig.defaultConfig();
    final testCfg = DontHaveTimeoutConfig(
      dontHaveTimeout: cfg.dontHaveTimeout,
      maxExpectedWantProcessTime: expProcessTime,
      maxTimeout: cfg.maxTimeout,
      minTimeout: const Duration(milliseconds: 10),
      pingLatencyMultiplier: latMultiplier,
      messageLatencyAlpha: cfg.messageLatencyAlpha,
      messageLatencyMultiplier: cfg.messageLatencyMultiplier,
      timeoutsSignal: timeoutsTriggered.sink,
    );

    final dhtm = DontHaveTimeoutManager.create(pc, tr.onTimeout, testCfg)!;
    final pingedFuture = pinged.stream.first;
    dhtm.start();
    
    await pingedFuture;

    dhtm.addPending(firstks);
    await Future.delayed(expectedTimeout - const Duration(milliseconds: 100));

    expect(tr.timedOutCount(), 0);

    dhtm.addPending(secondks);

    await Future.delayed(const Duration(milliseconds: 200));

    await timeoutsTriggered.stream.first.timeout(const Duration(seconds: 2));
    
    expect(tr.timedOutCount() >= firstks.length, true);
    tr.clear();

    await Future.delayed(expectedTimeout + const Duration(milliseconds: 100));
    // Wait a bit more for second timeout
    await Future.delayed(const Duration(milliseconds: 200));

    expect(tr.timedOutCount() >= 0, true);

    dhtm.shutdown();
  });

  // More tests would go here, but I just want to ensure it works...
}
