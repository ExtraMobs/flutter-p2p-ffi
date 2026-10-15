// O ipfs_ffi dentro de um app Android: as verificações locais do app
// (lib/checks.dart), as mesmas do botão "rodar testes". Roda com:
//   flutter test integration_test -d <emulador-ou-aparelho>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi_android/checks.dart';
import 'package:ipfs_ffi_android/main.dart' show prepare;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('verificações locais', () async {
    final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_it_');
    // plugins (1x por processo) e relatório de crash, como o app faz
    await prepare('${tmp.path}/app-repo', '${tmp.path}/crash.log');
    final lines = <String>[];
    final failed = await localChecks(lines.add);
    // ignore: avoid_print
    print(lines.join('\n'));
    expect(failed, 0, reason: lines.join('\n'));
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
