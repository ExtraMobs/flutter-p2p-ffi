// O ipfs_ffi dentro de um app Android: as verificações locais do app
// (lib/checks.dart), as mesmas do botão "rodar testes", a queda do ipfs_host
// (só ele cai; o onStop recebe o relatório e relança) e o segundo plano nos
// dois modos do IpfsService.background. Roda com:
//   flutter test integration_test -d <emulador-ou-aparelho>
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/ipfs_ffi.dart'
    show IpfsBackground, IpfsService, IpfsStop, IpfsStopReason;
import 'package:ipfs_ffi/src/runtime.dart' show $callSync;
import 'package:ipfs_ffi_android/checks.dart';
import 'package:ipfs_ffi_android/main.dart' show prepare, setupService;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String repo;
  final stops = StreamController<IpfsStop>.broadcast();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_it_');
    repo = '${tmp.path}/app-repo';
    // plugins (1x por processo do serviço) e relatório de crash, como o app
    await prepare(repo, '${tmp.path}/crash.log', onStop: stops.add);
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

  test('panic no Go derruba só o ipfs_host; onStop relança', () async {
    final hostPid = IpfsService.hostPid;
    final next = stops.stream.first;
    $callSync(24); // panic numa goroutine do Go: responde e cai logo depois
    final crash = await next.timeout(const Duration(seconds: 30));
    // ignore: avoid_print
    print('app pid $pid; host pid ${crash.pid} caiu (saída ${crash.exitCode})');
    expect(crash.reason, IpfsStopReason.crash);
    expect(crash.pid, hostPid);
    expect(crash.report, contains('panic de teste numa goroutine'));
    expect(IpfsService.isRunning, isFalse);

    await IpfsService.restart();
    setupService(repo);
    expect(IpfsService.hostPid, isNot(hostPid));
    final lines = <String>[];
    final failed = await localChecks(lines.add);
    expect(failed, 0, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  // o plugin ipfs_ffi_flutter chama appInBackground no onPause; aqui direto
  test('segundo plano, modo stop: o serviço para e o app decide', () async {
    expect(IpfsService.background, IpfsBackground.stop);
    final next = stops.stream.first;
    await IpfsService.appInBackground();
    final s = await next.timeout(const Duration(seconds: 30));
    expect(s.reason, IpfsStopReason.background);
    expect(IpfsService.isRunning, isFalse);
    await IpfsService.restart();
    setupService(repo);
    expect(IpfsService.isRunning, isTrue);
  });

  // o serviço do Android em si só se confere de fora (adb dumpsys); se o
  // Android o recusasse, o start falharia
  test('segundo plano, modo foregroundService: o serviço segue', () async {
    await IpfsService.stop();
    IpfsService.background = IpfsBackground.foregroundService;
    try {
      await prepare(repo, '${tmp.path}/crash.log', onStop: stops.add);
      await IpfsService.appInBackground(); // nada: o serviço segue
      expect(IpfsService.isRunning, isTrue);
      await IpfsService.stop();
    } finally {
      IpfsService.background = IpfsBackground.stop;
    }
  });
}
