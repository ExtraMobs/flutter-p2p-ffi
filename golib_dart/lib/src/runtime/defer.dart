/// `defer` / `recover` do Go.
library;

import 'dart:async';

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
/// (ou `await $d.runAsync();` numa função `async` — quando o g2d a colore
/// como suspensiva — para esperar defers que devolvem `Future`.)
///
/// - [defer] empilha a chamada (argumentos já avaliados pelo chamador);
/// - [run]/[runAsync] executam em ordem LIFO; um panic dentro de um defer
///   substitui o anterior; ao final, relança o panic se ninguém chamou
///   `recover`;
/// - o `return` no `finally` devolve os resultados nomeados depois dos
///   defers, que podem tê-los alterado (como no Go).
///
/// O quadro que [recover] consulta ("estou dentro de qual `Defers` agora?")
/// vive numa [Zone] por chamada, não numa pilha global: com goroutines, duas
/// chamadas concorrentes podem se intercalar em qualquer ordem através de um
/// `await` no meio de uma closure diferida (ex.: `defer` cujo corpo espera
/// um canal antes de chamar `recover`), e uma pilha global compartilhada
/// devolveria o quadro de quem quer que tivesse feito push por último — não
/// necessariamente o certo. Uma [Zone] carrega o valor certo através do
/// próprio `await` de cada cadeia assíncrona, mesmo com goroutines
/// diferentes se intercalando.
final class Defers {
  final _calls = <FutureOr<void> Function()>[];
  bool _panicking = false;
  Object? _value;
  StackTrace? _trace;

  static const _zoneKey = #goDefersFrame;

  void defer(FutureOr<void> Function() call) => _calls.add(call);

  /// A função entrou em panic.
  void fail(Object e, StackTrace st) {
    _panicking = true;
    _value = panicValue(e);
    _trace = st;
  }

  /// Roda os defers de uma função síncrona (nenhuma chamada aqui deve
  /// devolver `Future` pendente; o g2d só emite `run()`, em vez de
  /// [runAsync], para funções que ele colore como síncronas).
  void run() {
    while (_calls.isNotEmpty) {
      final call = _calls.removeLast();
      Zone.current.fork(zoneValues: {_zoneKey: this}).run(() {
        try {
          call();
        } catch (e, st) {
          fail(e, st);
        }
      });
    }
    if (_panicking) Error.throwWithStackTrace(Panic(_value), _trace!);
  }

  /// Como [run], mas aguarda cada defer que devolve `Future` (funções
  /// `async` com `defer`).
  Future<void> runAsync() async {
    while (_calls.isNotEmpty) {
      final call = _calls.removeLast();
      await Zone.current.fork(zoneValues: {_zoneKey: this}).run(() async {
        try {
          final r = call();
          if (r is Future) await r;
        } catch (e, st) {
          fail(e, st);
        }
      });
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

/// `recover()`. [frame] é a pilha de defers que invocou *diretamente* a
/// função que chama `recover` (o g2d a repassa pelo parâmetro oculto `$rd`,
/// só na chamada feita pelo defer). Qualquer outra chamada, ou fora de um
/// panic, devolve nil, como no Go.
Object? recover([Defers? frame]) {
  if (frame == null) return null;
  if (!identical(Zone.current[Defers._zoneKey], frame)) return null;
  return frame._recover();
}

/// Ponto de entrada do `main` Go. [main] pode suspender (`await` em canais,
/// `select`, mutex etc. — goroutines viram código `async`). Ao terminar —
/// com sucesso ou panic —, o processo encerra IMEDIATAMENTE (código 0 ou 2),
/// mesmo com goroutines vivas ou timers pendentes, como o Go faz ao retornar
/// de `main` (as outras goroutines não têm mais chance de rodar).
///
/// Um panic não recuperado imprime `panic: ...` no stderr e encerra com
/// código 2, como o runtime Go.
Future<void> runMain(FutureOr<void> Function() main) async {
  ensureAsyncScheduling();
  try {
    final r = main();
    if (r is Future) await r;
  } catch (e, st) {
    final value = panicValue(e);
    await flushOutput();
    writeStderr(
      'panic: ${describePanic(value)}\n\ngoroutine 1 [running]:\n$st\n',
    );
    exitProcess(2);
  }
  await flushOutput();
  exitProcess(0);
}
