// The real network, without touching the screen: the same network and
// reachability checks as the app's button (lib/checks.dart), with the app's online
// node (main.dart). It takes about 3 min (reachability waits for the node to be
// online for 2 min). Run with:
//   flutter test integration_test/network_test.dart -d <device>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:p2p_ffi_android/checks.dart';
import 'package:p2p_ffi_android/main.dart' show prepare, startNode;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('network and reachability', () async {
    final tmp = Directory.systemTemp.createTempSync('p2p_ffi_net_');
    await prepare('${tmp.path}/repo', '${tmp.path}/crash.log');
    final online = Stopwatch()..start();
    final n = await startNode(Go.context.background(), '${tmp.path}/repo');
    final api = Go.kubo.core.coreapi.newCoreApi(n);
    final lines = <String>[];
    try {
      var failed = await networkChecks(api, lines.add);
      failed += await reachabilityChecks(api, online, lines.add);
      // ignore: avoid_print
      print(lines.join('\n'));
      expect(failed, 0, reason: lines.join('\n'));
    } finally {
      await n.close();
      await P2pService.stop();
      tmp.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
