// Processo filho do teste de crash em Isolate (test/kubo_test.dart): um
// Isolate de fundo carrega a lib e dispara um panic numa goroutine solta do
// Go; o isolate principal segue vivo imprimindo. Se só o Isolate caísse, a
// marca "sobreviveu" sairia; o runtime do Go é um por processo, então o
// processo inteiro cai antes.
import 'dart:io';
import 'dart:isolate';

import 'package:ipfs_ffi/src/runtime.dart' show $callSync;

Future<void> main() async {
  await Isolate.run(() {
    $callSync('ipfs_ffi/test.PanicInGoroutine', const []);
    sleep(const Duration(seconds: 1)); // o panic chega nesse meio-tempo
  });
  print('sobreviveu');
}
