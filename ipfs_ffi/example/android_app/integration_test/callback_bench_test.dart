// O lote padrão do callback sob demanda (0.17.0) no Android: a mesma matriz
// do tool/bench_callback.dart do desktop (lib/src/callback_bench.dart). Em
// profile (AOT, como o release):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/callback_bench_test.dart -d <aparelho>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/src/callback_bench.dart' show callbackBench;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('lote do callback sob demanda', () async {
    await IpfsService.start();
    // ignore: avoid_print
    await callbackBench(print, seconds: 0.5);
    await IpfsService.stop();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
