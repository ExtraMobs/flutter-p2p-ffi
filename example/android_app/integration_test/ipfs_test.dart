// ipfs_ffi inside an Android app: the app's local checks (lib/checks.dart),
// the same as the "run tests" button, an ipfs_host crash (only it goes down;
// onStop gets the report and restarts) and the background in both modes of
// IpfsService.background. Run with:
//   flutter test integration_test -d <emulator-or-device>
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
    // plugins (once per service process) and the crash report, like the app
    await prepare(repo, '${tmp.path}/crash.log', onStop: stops.add);
  });

  tearDownAll(() async {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('local checks', () async {
    final lines = <String>[];
    final failed = await localChecks(lines.add);
    // ignore: avoid_print
    print(lines.join('\n'));
    expect(failed, 0, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a Go panic stops only the ipfs_host; onStop restarts', () async {
    final hostPid = IpfsService.hostPid;
    final next = stops.stream.first;
    $callSync(
        24); // a panic in a Go goroutine: it answers and goes down right after
    final crash = await next.timeout(const Duration(seconds: 30));
    // ignore: avoid_print
    print(
        'app pid $pid; host pid ${crash.pid} went down (exit ${crash.exitCode})');
    expect(crash.reason, IpfsStopReason.crash);
    expect(crash.pid, hostPid);
    expect(crash.report, contains('test panic in a goroutine'));
    expect(IpfsService.isRunning, isFalse);

    await IpfsService.restart();
    setupService(repo);
    expect(IpfsService.hostPid, isNot(hostPid));
    final lines = <String>[];
    final failed = await localChecks(lines.add);
    expect(failed, 0, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  // the ipfs_ffi_flutter plugin calls appInBackground on onPause; here directly
  test('background, stop mode: the service stops and the app decides',
      () async {
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

  // the Android service itself can only be checked from outside (adb dumpsys);
  // if Android refused it, start would fail
  test('background, foregroundService mode: the service goes on', () async {
    await IpfsService.stop();
    IpfsService.background = IpfsBackground.foregroundService;
    try {
      await prepare(repo, '${tmp.path}/crash.log', onStop: stops.add);
      await IpfsService.appInBackground(); // nothing: the service goes on
      expect(IpfsService.isRunning, isTrue);
      await IpfsService.stop();
    } finally {
      IpfsService.background = IpfsBackground.stop;
    }
  });
}
