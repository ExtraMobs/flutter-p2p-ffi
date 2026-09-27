// Programa mínimo: uma goroutine spawnada entra em panic sem recover. Como
// no Go, isso derruba o processo inteiro: "panic: ..." no stderr, código 2 —
// mesmo com a goroutine principal (`main`) ainda viva e bloqueada esperando.
import 'package:golib_dart/builtin.dart' as go;

void main() {
  go.runMain(() async {
    final ch = go.Chan<int>(0, 0);
    go.spawn(() {
      throw go.Panic('bom dia');
    });
    print('main espera');
    await ch.recv(); // fica bloqueada; quem derruba o processo é o panic.
  });
}
