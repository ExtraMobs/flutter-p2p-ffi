// Programa dos cenários do motor de rede: `net_sys_test.dart` roda na VM
// (`dart run`), em JS (`dart compile js` + node) e em Wasm
// (`dart compile wasm` + node) e exige a mesma saída.
import 'package:golib_dart/src/runtime/output.dart';
import 'package:golib_dart/src/net/sys/sys.dart';

import 'scenarios.dart';

Future<void> main() async {
  ensureAsyncScheduling();
  print('suportado ${sysNetSupported}');
  for (final name in scenarios.keys) {
    print('== $name');
    for (final line in await runScenario(name)) {
      print(line);
    }
  }
  await flushOutput();
  exitProcess(0);
}
