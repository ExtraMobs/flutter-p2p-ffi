// The on-demand callback's default batch on Android: the same matrix as the
// desktop's tool/bench_callback.dart (lib/src/callback_bench.dart). In profile
// (AOT, like release):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/callback_bench_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_ffi/p2p_ffi.dart' show P2pService;
import 'package:p2p_ffi/src/callback_bench.dart' show callbackBench;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('on-demand callback batch', () async {
    await P2pService.start();
    // ignore: avoid_print
    await callbackBench(print, seconds: 0.5);
    await P2pService.stop();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
