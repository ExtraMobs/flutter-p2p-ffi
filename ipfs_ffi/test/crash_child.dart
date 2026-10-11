// Processo filho do teste de crash (test/kubo_test.dart): grava o relatório
// de crash do Go em [args.first] e dispara um panic numa goroutine solta,
// como um bug interno do kubo. O processo inteiro cai; o pai lê o arquivo.
import 'package:ipfs_ffi/os.dart' as os;
import 'package:ipfs_ffi/runtime/debug.dart' as debug;
import 'package:ipfs_ffi/src/runtime.dart' show $callSync;

Future<void> main(List<String> args) async {
  final f = os.create(args.first);
  debug.setCrashOutput(f, debug.CrashOptions());
  f.close(); // o Go duplicou o descritor
  $callSync('ipfs_ffi/test.PanicInGoroutine', const []);
  await Future<void>.delayed(
      const Duration(seconds: 10)); // o panic chega antes
}
