// A rede de verdade, sem tocar na tela: as mesmas verificações de rede e de
// alcançabilidade do botão do app (lib/checks.dart), com o nó online do app
// (main.dart). Leva uns 3 min (a alcançabilidade espera o nó estar online há
// 2 min). Roda com:
//   flutter test integration_test/network_test.dart -d <aparelho>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/go/context.dart' as gocontext;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi_android/checks.dart';
import 'package:ipfs_ffi_android/main.dart' show prepare, startNode;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('rede e alcançabilidade', () async {
    final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_net_');
    await prepare('${tmp.path}/repo', '${tmp.path}/crash.log');
    final online = Stopwatch()..start();
    final n = await startNode(gocontext.background(), '${tmp.path}/repo');
    final api = coreapi.newCoreApi(n);
    final lines = <String>[];
    try {
      var failed = await networkChecks(api, lines.add);
      failed += await reachabilityChecks(api, online, lines.add);
      // ignore: avoid_print
      print(lines.join('\n'));
      expect(failed, 0, reason: lines.join('\n'));
    } finally {
      await n.close();
      await IpfsService.stop();
      tmp.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
