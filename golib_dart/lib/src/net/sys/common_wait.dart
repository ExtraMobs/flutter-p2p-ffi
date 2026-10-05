part of 'common.dart';

// Prazos, esperas e a marcação de I/O pendente para o detector de deadlock.

/// Prazo absoluto ([DateTime], como o `time.Time` do Go) que chama
/// [_onExpire] quando vence. Re-armar vale também para a espera pendente.
/// Esperas longas viram uma cadeia de temporizadores de até 1 dia (o
/// `setTimeout` do JS estoura acima de 2^31-1 ms).
final class Deadline {
  Deadline(this._onExpire);

  final void Function() _onExpire;
  Timer? _timer;
  DateTime? _at;

  /// Venceu (e ainda não foi re-armado).
  bool expired = false;

  /// Novo prazo; `null` tira; no passado, vence na hora (chamando o aviso já).
  void set(DateTime? at) {
    _timer?.cancel();
    _timer = null;
    expired = false;
    _at = at;
    if (at != null) _arm();
  }

  void _arm() {
    final at = _at!;
    final wait = at.difference(DateTime.now());
    if (wait <= Duration.zero) {
      _timer = null;
      expired = true;
      _onExpire();
      return;
    }
    const chunk = Duration(days: 1);
    _timer = Timer(wait > chunk ? chunk : wait, _arm);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Espera de I/O pendente: segura o detector de deadlock do runtime
/// (`holdEvents`) enquanto [op] não termina — goroutines paradas em rede não
/// são deadlock, como no Go (o `checkdead` não reclama com o netpoller
/// esperando).
Future<T> heldIo<T>(Future<T> Function() op) async {
  holdEvents();
  try {
    return await op();
  } finally {
    releaseEvents();
  }
}

/// Fila de esperas que acordam todas de uma vez (cada uma reavalia o estado).
final class Waiters {
  final _list = <Completer<void>>[];

  Future<void> wait() {
    final c = Completer<void>();
    _list.add(c);
    return c.future;
  }

  void wakeAll() {
    if (_list.isEmpty) return;
    final all = List.of(_list);
    _list.clear();
    for (final c in all) {
      c.complete();
    }
  }
}
