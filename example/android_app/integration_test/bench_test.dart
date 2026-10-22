// Diagnosing the cost of a synchronous call on the device: the app's checks
// measured api.unixfs() at ~80× Noop. It measures each call (mean and
// percentiles), with Dart pauses between calls, with different spins and with an
// offline and an online node in the host. In profile (AOT, like release):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/bench_test.dart -d <device>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/src/runtime.dart' show $callSync, $W;
import 'package:ipfs_ffi_android/main.dart' show setupService, startNode;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final freq = Stopwatch().frequency;

  String pct(List<int> ticks) {
    ticks.sort();
    double us(int t) => t * 1e6 / freq;
    String at(double p) =>
        us(ticks[(p * (ticks.length - 1)).round()]).toStringAsFixed(1);
    final mean = us(ticks.reduce((a, b) => a + b)) / ticks.length;
    return 'mean ${mean.toStringAsFixed(1)} | p10 ${at(.1)} p50 ${at(.5)} '
        'p90 ${at(.9)} p99 ${at(.99)} µs';
  }

  List<int> measure(void Function() f, {int gapUs = 0, int n = 3000}) {
    final sw = Stopwatch()..start();
    final gap = Stopwatch();
    for (var i = 0; i < 300; i++) {
      f();
    }
    final out = <int>[];
    for (var i = 0; i < n; i++) {
      if (gapUs > 0) {
        gap
          ..reset()
          ..start();
        // trabalho do Dart entre as chamadas
        while (gap.elapsedMicroseconds < gapUs) {}
      }
      final t0 = sw.elapsedTicks;
      f();
      out.add(sw.elapsedTicks - t0);
    }
    return out;
  }

  test('cost of a synchronous call', () async {
    final lines = <String>[];
    for (final spin in [20000, 200000]) {
      await IpfsService.start(spin: spin);
      final ctx = context.background();
      lines.add('--- spin $spin');
      lines.add('Noop:          ${pct(measure(() => $callSync(0)))}');
      lines.add(
          'Echo 8 B:      ${pct(measure(() => $callSync(2, $W()..i64(1))))}');
      lines.add('ctx.err():     ${pct(measure(() => ctx.err()))}');
      lines.add('background():  ${pct(measure(() => context.background()))}');
      for (final gap in [20, 50, 100]) {
        lines.add('Noop + $gap µs of Dart: '
            '${pct(measure(() => $callSync(0), gapUs: gap, n: 1000))}');
      }
      await IpfsService.stop();
    }
    // ignore: avoid_print
    print(lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('with a node in the host: offline × online', () async {
    final lines = <String>[];
    final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_bench_');
    final repo = '${tmp.path}/repo';
    for (final spin in [20000, 200000]) {
      await IpfsService.start(spin: spin);
      setupService(repo); // plugins (once per host) and the app's repo
      final ctx = context.background();
      for (final online in [false, true]) {
        final n = online
            ? await startNode(ctx, repo)
            : await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repo)));
        final api = coreapi.newCoreApi(n);
        if (online) await Future<void>.delayed(const Duration(seconds: 20));
        final peers = online ? (await api.swarm().peers(ctx)).length : 0;
        lines.add(
            '--- spin $spin, node ${online ? 'online ($peers peers)' : 'offline'}');
        lines.add('Noop:          ${pct(measure(() => $callSync(0)))}');
        lines.add('ctx.err():     ${pct(measure(() => ctx.err()))}');
        lines.add('api.unixfs():  ${pct(measure(() => api.unixfs()))}');
        lines.add('Noop again:    ${pct(measure(() => $callSync(0)))}');
        await n.close();
      }
      await IpfsService.stop();
    }
    tmp.deleteSync(recursive: true);
    // ignore: avoid_print
    print(lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
