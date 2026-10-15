// O ipfs_ffi dentro de um app Android: as verificações locais do app
// (lib/checks.dart), as mesmas do botão "rodar testes", e a queda do
// ipfs_host (só ele cai; o onCrash recebe o relatório e relança). Roda com:
//   flutter test integration_test -d <emulador-ou-aparelho>
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsCrash, IpfsService;
import 'package:ipfs_ffi/src/runtime.dart' show $callSync;
import 'package:ipfs_ffi_android/checks.dart';
import 'package:ipfs_ffi_android/main.dart' show prepare, setupService;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  final crashes = StreamController<IpfsCrash>();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_it_');
    // plugins (1x por processo do serviço) e relatório de crash, como o app
    await prepare('${tmp.path}/app-repo', '${tmp.path}/crash.log',
        onCrash: crashes.add);
  });

  tearDownAll(() async {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('verificações locais', () async {
    final lines = <String>[];
    final failed = await localChecks(lines.add);
    // ignore: avoid_print
    print(lines.join('\n'));
    expect(failed, 0, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('panic no Go derruba só o ipfs_host; onCrash relança', () async {
    final hostPid = IpfsService.hostPid;
    $callSync(24); // panic numa goroutine do Go: responde e cai logo depois
    final crash =
        await crashes.stream.first.timeout(const Duration(seconds: 30));
    // ignore: avoid_print
    print('app pid $pid; host pid ${crash.pid} caiu (saída ${crash.exitCode})');
    expect(crash.pid, hostPid);
    expect(crash.report, contains('panic de teste numa goroutine'));
    expect(IpfsService.isRunning, isFalse);

    await IpfsService.restart();
    setupService('${tmp.path}/app-repo');
    expect(IpfsService.hostPid, isNot(hostPid));
    final lines = <String>[];
    final failed = await localChecks(lines.add);
    expect(failed, 0, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
