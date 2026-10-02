// Programa mínimo: a única goroutine (main) bloqueia num recv que ninguém
// jamais vai satisfazer. `dart run` (ou compilado) deve imprimir
// "fatal error: all goroutines are asleep - deadlock!" no stderr e sair
// com código 2, como o Go.
import 'package:golib_dart/builtin.dart' as go;

void main() {
  go.runMain(() async {
    print('antes');
    final ch = go.Chan<int>(0, 0);
    await ch.recv(); // ninguém mais vivo pra mandar: deadlock.
    print('depois'); // nunca roda.
  });
}
