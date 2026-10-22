// The on-demand callback's default batch on Android: the same matrix as the
// desktop's tool/bench_callback.dart (lib/src/callback_bench.dart). In profile
// (AOT, like release):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/callback_bench_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/src/callback_bench.dart' show callbackBench;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('on-demand callback batch', () async {
    await IpfsService.start();
    // ignore: avoid_print
    await callbackBench(print, seconds: 0.5);
    await IpfsService.stop();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
