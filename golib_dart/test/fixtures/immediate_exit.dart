// Programa mínimo: `main` termina com uma goroutine e um timer ainda vivos.
// O processo tem que sair IMEDIATAMENTE com código 0 (como o Go faz ao
// retornar de `main`) — a goroutine tardia nunca chega a imprimir nada — e
// toda a saída já escrita (bastante, pra estressar o flush) tem que chegar
// inteira, sem truncar.
import 'package:golib_dart/builtin.dart' as go;

void main() {
  go.runMain(() async {
    go.spawn(() async {
      await Future<void>.delayed(const Duration(seconds: 5));
      print('goroutine tardia'); // nunca deve aparecer.
    });
    for (var i = 0; i < 2000; i++) {
      print('linha $i');
    }
    print('main terminou');
  });
}
