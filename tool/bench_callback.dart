// Escolha do lote padrão do callback sob demanda (0.17.0): `dart run
// tool/bench_callback.dart [segundos]` (exige `dart run tool/build.dart`). A
// medida está em lib/src/callback_bench.dart; o Android roda a mesma no
// integration_test/bench_test.dart do app.
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/src/callback_bench.dart';

Future<void> main(List<String> args) async {
  await IpfsService.start();
  try {
    await callbackBench(print,
        seconds: args.isEmpty ? 1.0 : double.parse(args.first));
  } finally {
    await IpfsService.stop();
  }
}
