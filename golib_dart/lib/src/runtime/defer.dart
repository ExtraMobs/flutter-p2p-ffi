/// `defer` / `recover` do Go.
library;

import 'output.dart';
import 'panic.dart';

/// Pilha de defers de uma chamada de função Go.
///
/// O g2d emite, para toda função com `defer`:
///
/// ```dart
/// final $d = go.Defers();
/// try { corpo } catch (e, st) { $d.fail(e, st); }
/// finally { $d.run(); return (resultados); }
/// ```
///
/// - [defer] empilha a chamada (argumentos já avaliados pelo chamador);
/// - [run] executa em ordem LIFO; um panic dentro de um defer substitui o
///   anterior; ao final, relança o panic se ninguém chamou `recover`;
/// - o `return` no `finally` devolve os resultados nomeados depois dos
///   defers, que podem tê-los alterado (como no Go).
final class Defers {
  final _calls = <void Function()>[];
  bool _panicking = false;
  Object? _value;
  StackTrace? _trace;

  static final _running = <Defers>[];

  void defer(void Function() call) => _calls.add(call);

  /// A função entrou em panic.
  void fail(Object e, StackTrace st) {
    _panicking = true;
    _value = panicValue(e);
    _trace = st;
  }

  void run() {
    while (_calls.isNotEmpty) {
      final call = _calls.removeLast();
      _running.add(this);
      try {
        call();
      } catch (e, st) {
        fail(e, st);
      } finally {
        _running.removeLast();
      }
    }
    if (_panicking) Error.throwWithStackTrace(Panic(_value), _trace!);
  }

  Object? _recover() {
    if (!_panicking) return null;
    _panicking = false;
    final v = _value;
    _value = null;
    return v;
  }
}

/// `recover()`: interrompe o panic da função cujos defers estão executando.
// ponytail: o Go só recupera se chamado *diretamente* pela função adiada;
// aqui qualquer chamada durante a execução de um defer recupera.
Object? recover() =>
    Defers._running.isEmpty ? null : Defers._running.last._recover();

/// Ponto de entrada do `main` Go: um panic não recuperado imprime
/// `panic: ...` no stderr e encerra com código 2, como o runtime Go.
void runMain(void Function() main) {
  try {
    main();
  } catch (e, st) {
    final value = panicValue(e);
    writeStderr(
      'panic: ${describePanic(value)}\n\ngoroutine 1 [running]:\n$st\n',
    );
    exitProcess(2);
  }
}
