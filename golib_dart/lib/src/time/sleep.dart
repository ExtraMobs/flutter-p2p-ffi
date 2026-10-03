part of '../../time.dart';

// Porta de `time/sleep.go` e `time/tick.go` do Go 1.26 (`Sleep`, `Timer`,
// `After`, `AfterFunc`, `Ticker`, `Tick`) sobre o escalonador do runtime
// (`src/runtime/sched.dart`), com a semântica do Go ≥ 1.23 (`asynctimerchan`
// desligado): canal de timer síncrono (`len`/`cap` 0; `Stop`/`Reset`
// garantem que nenhum valor velho é recebido depois, e devolvem `true` se
// descartaram um disparo ainda não recebido).
//
// Um `Sleep` ou `AfterFunc` pendente é uma fonte de evento externo
// (`holdEvents`): enquanto existir, todas as goroutines bloqueadas não são
// deadlock, como o `checkdead` do Go (que não reclama com timer no heap).
// Um timer de canal (`NewTimer`/`NewTicker`/`After`/`Tick`) só conta
// enquanto alguma goroutine espera no canal dele (`addEventSource`), como
// no Go ≥ 1.23 (o timer só entra no heap com alguém bloqueado no canal).
// Disparado ou parado, libera.
//
// O relógio é o monotônico do shim (`_runtimeNanoSinceStart`, o mesmo do
// `Now`); o evento do Dart (`async.Timer`) só acorda o laço de eventos. Um
// timer vencido cujo evento ainda não rodou dispara também quando alguém
// olha o canal (`Chan.$timerPoll`), como o `maybeRunChan` do Go.

/// Maior espera de um `async.Timer` só: o `setTimeout` do JS/Node estoura
/// acima de 2^31-1 ms (~24,8 dias) e dispara na hora; esperas maiores (ex.
/// `time.NewTimer(math.MaxInt64)`) viram uma cadeia de esperas de 1 dia.
const _maxChunkMicros = 24 * 3600 * 1000000;

/// Teto das esperas em ns: 2^62 ns (~146 anos, "nunca" na prática). O
/// `int` do Dart só é exato até 2^53 no JS, então uma `Duration` acima
/// disso (até `math.MaxInt64`) satura aqui.
const _farFutureNs = 4611686018427387904; // 2^62 (exato em double)
final _farFuture = Duration.fromBigInt(BigInt.one << 62);

int _monoNs() => _runtimeNanoSinceStart().toInt();

/// `Duration` → ns como `int` do Dart (exato até 2^53; acima satura em
/// [_farFutureNs], que já é "nunca").
int _durNs(Duration d) {
  if (d <= Duration()) return 0;
  if (d >= _farFuture) return _farFutureNs;
  return d.toInt();
}

/// Um alarme no relógio monotônico: chama [_fire] quando `_monoNs()`
/// alcança [when], encadeando `async.Timer`s de no máximo
/// [_maxChunkMicros].
final class _Alarm {
  _Alarm(this.when, this._fire) {
    ensureAsyncScheduling();
    _arm();
  }

  final int when;
  final void Function() _fire;
  async.Timer? _t;

  void _arm() {
    final waitUs = (when - _monoNs() + 999) ~/ 1000;
    if (waitUs > _maxChunkMicros) {
      _t = async.Timer(
        const core.Duration(microseconds: _maxChunkMicros),
        _arm,
      );
      return;
    }
    _t = async.Timer(core.Duration(microseconds: waitUs < 0 ? 0 : waitUs), () {
      _t = null;
      _fire();
    });
  }

  void cancel() {
    _t?.cancel();
    _t = null;
  }
}

/// `time.Sleep(d)`: suspende a goroutine atual por pelo menos [d]. O g2d
/// emite `await time.sleep(d)` (a função é `async` na cor transitiva).
///
/// `d <= 0` volta sem timer, como o Go (que nem cede o processador); o
/// `await` de quem chama ainda passa por uma microtask (efeito do Dart,
/// inevitável e inofensivo: o Go não promete ordem entre goroutines aqui).
async.Future<void> sleep(Duration d) async {
  final ns = _durNs(d);
  if (ns <= 0) return;
  final done = async.Completer<void>();
  holdEvents();
  goroutineBlocked();
  _Alarm(_monoNs() + ns, done.complete);
  try {
    await done.future;
  } finally {
    goroutineUnblocked();
    releaseEvents();
  }
}

/// O timer do runtime (`runtime.timer`): o que `Timer` e `Ticker` apontam.
final class _RuntimeTimer {
  _RuntimeTimer(this.ch, this.f, this.period);

  /// Canal do `NewTimer`/`NewTicker` (null no `AfterFunc`).
  final Chan<Time>? ch;

  /// Função do `AfterFunc` (roda numa goroutine nova a cada disparo).
  final async.FutureOr<void> Function()? f;

  /// Período em ns (0: dispara uma vez).
  int period;

  /// Instante do próximo disparo (monotônico, ns); `null`: inativo.
  int? _when;
  _Alarm? _alarm;

  bool get active => _when != null;

  /// Timer de canal só conta como evento pendente enquanto alguém espera
  /// no canal (Go ≥ 1.23: `time.NewTimer(time.Hour)` esquecido não impede
  /// o deadlock); o de `AfterFunc` conta sempre.
  late final bool Function() _waited = () => ch!.$hasRecvWaiter();

  void _hold() => ch == null ? holdEvents() : addEventSource(_waited);

  void _release() => ch == null ? releaseEvents() : removeEventSource(_waited);

  void start(int when) {
    if (!active) _hold();
    _when = when;
    _alarm?.cancel();
    _alarm = _Alarm(when, _run);
  }

  /// Desarma; `true` se estava armado. Não mexe no canal.
  bool _disarm() {
    if (!active) return false;
    _alarm?.cancel();
    _alarm = null;
    _when = null;
    _release();
    return true;
  }

  /// `stopTimer`/`resetTimer`: desarma e descarta o valor não recebido.
  /// `true` se impediu um disparo de ser recebido (armado, ou valor
  /// pendente no canal).
  bool stop() {
    // Canal de timer vencido mas o evento do Dart ainda não rodou: o Go
    // dispara antes de parar (o valor vai pro canal e é descartado logo
    // abaixo). Timer de `AfterFunc` vencido e não rodado ainda conta como
    // parado a tempo, também como o Go.
    if (ch != null) poll();
    var pending = _disarm();
    if (ch != null && ch!.$drain()) pending = true;
    return pending;
  }

  bool reset(int when, int period) {
    final pending = stop();
    this.period = period;
    start(when);
    return pending;
  }

  /// Dispara agora se já venceu (`maybeRunChan`).
  void poll() {
    final w = _when;
    if (w != null && _monoNs() >= w) _run();
  }

  void _run() {
    final w = _when;
    if (w == null) return; // parado entre o vencimento e o evento.
    final t = _monoNs();
    final delta = t - w;
    if (period > 0) {
      // Ticker: pula os disparos perdidos, como o runtime do Go
      // (`t.when += t.period * (1 + -delta/t.period)`).
      var next = w + period * (1 + delta ~/ period);
      if (next <= t) next = t + period;
      _when = next;
      _alarm = _Alarm(next, _run);
    } else {
      _alarm = null;
      _when = null;
    }
    final c = ch;
    if (c != null) {
      // `sendTime`: o instante em que devia ter disparado; canal cheio
      // (ticker com leitor lento) descarta.
      final v = now().add(Duration(-delta));
      if (c.$sendReady()) c.$commitSend(v);
    } else {
      spawn(f!);
    }
    if (period == 0) _release();
  }
}

/// `time.Timer`. No Go é `*Timer` (no Dart, `Timer?`); `c` é o campo `C`
/// (`<-chan Time`), nulo num timer do [afterFunc].
final class Timer extends GoStruct<Timer> {
  Timer() : c = null, initTimer = false;
  Timer._(this.c, this.initTimer, this._rt);

  /// `(*Timer)(nil)`: o g2d chama métodos por `(p ?? Timer.$nil)`.
  static final Timer $nil = Timer()..$nilPtr = true;

  /// Campo `C`.
  Chan<Time>? c;

  /// Campo não exportado `initTimer` do Go (`Stop`/`Reset` em `Timer{}`
  /// panicam).
  bool initTimer;
  _RuntimeTimer? _rt;

  static const _ms = ['Reset', 'Stop'];

  @override
  String get $goType => 'time.Timer';
  @override
  List<String> get $ptrMethods => _ms;

  @override
  Timer $copy() => Timer._(c, initTimer, _rt);
  @override
  void $set(Timer o) {
    c = o.c;
    initTimer = o.initTimer;
    _rt = o._rt;
  }

  @override
  List<Object?> get $fields => [c, initTimer];
  @override
  List<String> get $fieldNames => const ['C', 'initTimer'];
  @override
  List<String> get $fieldTypes => const ['<-chan time.Time', 'bool'];

  /// `(*Timer).Stop()`: `true` se impediu o disparo (inclusive um valor
  /// já disparado e ainda não recebido, que é descartado).
  bool stop() {
    final rt = _rt;
    if (!initTimer || rt == null) {
      _panic('time: Stop called on uninitialized Timer');
    }
    return rt.stop();
  }

  /// `(*Timer).Reset(d)`: rearma para daqui a [d]; mesmo retorno de [stop].
  bool reset(Duration d) {
    final rt = _rt;
    if (!initTimer || rt == null) {
      _panic('time: Reset called on uninitialized Timer');
    }
    return rt.reset(_whenNs(d), 0);
  }
}

/// `time.Ticker`. No Go é `*Ticker` (no Dart, `Ticker?`).
final class Ticker extends GoStruct<Ticker> {
  Ticker() : c = null, initTicker = false;
  Ticker._(this.c, this.initTicker, this._rt);

  /// `(*Ticker)(nil)`: o g2d chama métodos por `(p ?? Ticker.$nil)`.
  static final Ticker $nil = Ticker()..$nilPtr = true;

  /// Campo `C`.
  Chan<Time>? c;

  /// Campo não exportado `initTicker` do Go.
  bool initTicker;
  _RuntimeTimer? _rt;

  static const _ms = ['Reset', 'Stop'];

  @override
  String get $goType => 'time.Ticker';
  @override
  List<String> get $ptrMethods => _ms;

  @override
  Ticker $copy() => Ticker._(c, initTicker, _rt);
  @override
  void $set(Ticker o) {
    c = o.c;
    initTicker = o.initTicker;
    _rt = o._rt;
  }

  @override
  List<Object?> get $fields => [c, initTicker];
  @override
  List<String> get $fieldNames => const ['C', 'initTicker'];
  @override
  List<String> get $fieldTypes => const ['<-chan time.Time', 'bool'];

  /// `(*Ticker).Stop()`: sem efeito num `Ticker{}` (o Go não panica aqui,
  /// por compatibilidade).
  void stop() {
    if (!initTicker) return;
    _rt?.stop();
  }

  /// `(*Ticker).Reset(d)`.
  void reset(Duration d) {
    if (d <= Duration()) _panic('non-positive interval for Ticker.Reset');
    final rt = _rt;
    if (!initTicker || rt == null) {
      _panic('time: Reset called on uninitialized Ticker');
    }
    final ns = _durNs(d);
    rt.reset(_whenNs(d), ns);
  }
}

Never _panic(String s) => throw Panic(Golang.String.fromDart(s));

/// `when(d)`: instante monotônico de daqui a [d] (`d <= 0`: agora).
int _whenNs(Duration d) => _monoNs() + _durNs(d);

Chan<Time> _timerChan(_RuntimeTimer Function(Chan<Time>) make) {
  final ch = Chan<Time>.$timer(Time());
  final rt = make(ch);
  ch.$timerPoll = rt.poll;
  return ch;
}

/// `time.NewTimer(d)`.
Timer newTimer(Duration d) {
  late _RuntimeTimer rt;
  final ch = _timerChan((ch) => rt = _RuntimeTimer(ch, null, 0));
  rt.start(_whenNs(d));
  return Timer._(ch, true, rt);
}

/// `time.After(d)`: `NewTimer(d).C`.
Chan<Time>? after(Duration d) => newTimer(d).c;

/// `time.AfterFunc(d, f)`: [f] roda numa goroutine nova (`go f()`) quando
/// o timer dispara; aceita closure síncrona ou `async`. O `C` do timer é
/// nil. `f` nil só falha (panic de nil) quando o timer dispara, como no Go.
Timer afterFunc(Duration d, async.FutureOr<void> Function()? f) {
  final rt = _RuntimeTimer(null, () => f!(), 0);
  rt.start(_whenNs(d));
  return Timer._(null, true, rt);
}

/// `time.NewTicker(d)`: dispara a cada [d]; leitor lento perde ticks.
Ticker newTicker(Duration d) {
  if (d <= Duration()) _panic('non-positive interval for NewTicker');
  final ns = _durNs(d);
  late _RuntimeTimer rt;
  final ch = _timerChan((ch) => rt = _RuntimeTimer(ch, null, ns));
  rt.start(_whenNs(d));
  return Ticker._(ch, true, rt);
}

/// `time.Tick(d)`: `NewTicker(d).C`, ou nil se `d <= 0`.
Chan<Time>? tick(Duration d) {
  if (d <= Duration()) return null;
  return newTicker(d).c;
}
