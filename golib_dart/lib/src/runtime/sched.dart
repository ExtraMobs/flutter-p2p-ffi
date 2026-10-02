/// Escalonador cooperativo das goroutines (M4,
/// `TODO/P0-design-m4-concorrencia.md`): contadores de vivas/bloqueadas para
/// a detecção de deadlock do Go, e `go f()` (que agenda, nunca roda
/// síncrono).
///
/// Cada goroutine Go vira uma cadeia `async`/`await` do Dart sobre o único
/// event loop; não há paralelismo real, só suspensão cooperativa. Os
/// contadores abaixo são globais ao isolate (processo), como o runtime do Go.
library;

import 'dart:async';

import 'output.dart';
import 'panic.dart';

/// Goroutines vivas, contando um "ambiente" implícito (a `main` do Go, ou —
/// nos testes deste pacote, que chamam `Chan`/`sync` sem passar por
/// [runMain] — a goroutine de teste atual). Esse ambiente nunca é
/// decrementado: só [spawn] soma/some uma unidade real por goroutine.
int _alive = 1;

/// Goroutines bloqueadas agora (canal, `select`, mutex, `WaitGroup`, `Cond`).
int _blocked = 0;

/// Fontes de evento externo pendentes (timers, I/O) que ainda podem acordar
/// alguém; enquanto > 0, bloqueio total não é necessariamente deadlock.
int _pendingEvents = 0;

bool _checkScheduled = false;
int _goroutineSeq = 1;

/// Goroutines vivas agora (para o limite síncrono de `sync`: só `lock()` /
/// `wait()` etc. sabem se esperar por outra goroutine é plausível).
int get aliveGoroutines => _alive;

/// Uma goroutine nova passou a existir ([spawn]); pode ainda não ter rodado.
void goroutineStarted() {
  _alive++;
}

/// Uma goroutine terminou (retornou, ou seu panic já foi tratado).
void goroutineFinished() {
  _alive--;
  _scheduleDeadlockCheck();
}

/// A goroutine atual bloqueou numa operação suspensiva do runtime.
void goroutineBlocked() {
  ensureAsyncScheduling();
  _blocked++;
  _scheduleDeadlockCheck();
}

/// A goroutine atual foi desbloqueada (valor entregue, trava obtida...).
void goroutineUnblocked() {
  _blocked--;
}

/// Uma fonte de evento externo (timer, I/O) começa pendente: enquanto durar,
/// todo mundo bloqueado não é necessariamente um deadlock (ela pode acordar
/// alguém). Shims de `time`/`net`/etc. chamam isto ao agendar.
void holdEvents() {
  _pendingEvents++;
}

/// A fonte de evento externo não está mais pendente (disparou ou foi
/// cancelada).
void releaseEvents() {
  _pendingEvents--;
  _scheduleDeadlockCheck();
}

/// Fontes de evento condicionais: cada uma diz, na hora da checagem, se
/// ainda pode acordar alguém. É o timer de canal do Go ≥ 1.23, que só conta
/// para o `checkdead` enquanto alguma goroutine espera no canal dele
/// (`time.NewTimer(time.Hour)` esquecido não impede o deadlock; `<-t.C`
/// sim).
final _conditionalSources = <bool Function()>{};

/// Registra uma fonte condicional ([_conditionalSources]); [pending] tem
/// que ser barata (roda a cada checagem de deadlock).
void addEventSource(bool Function() pending) {
  _conditionalSources.add(pending);
}

/// Retira a fonte condicional (disparou ou foi parada) e recheca o
/// deadlock: quem esperava só por ela pode ter ficado sem saída.
void removeEventSource(bool Function() pending) {
  if (_conditionalSources.remove(pending)) _scheduleDeadlockCheck();
}

/// Agenda a checagem para depois que as microtasks assentarem (`Timer.run`
/// vira um evento novo na fila, atrás de toda microtask já enfileirada), pra
/// não falso-positivar com uma goroutine recém-[spawn]ada que ainda não
/// rodou (ela conta como viva antes de rodar, então nunca empata sozinha
/// como bloqueada) nem com uma corrida perfeita de handoff (send seguido de
/// recv no mesmo turno, por exemplo) que já resolveu tudo antes do timer
/// dela disparar.
void _scheduleDeadlockCheck() {
  if (_checkScheduled) return;
  _checkScheduled = true;
  Timer.run(_checkDeadlock);
}

void _checkDeadlock() {
  _checkScheduled = false;
  if (_pendingEvents > 0) return;
  for (final pending in _conditionalSources) {
    if (pending()) return;
  }
  if (_alive > 0 && _blocked >= _alive) {
    fatal('all goroutines are asleep - deadlock!');
  }
}

/// `fatal error` do runtime Go (deadlock, unlock de mutex destravado...):
/// não passa por `recover` nem roda defers; imprime no stderr e sai com 2.
Never fatal(String message) {
  writeStderr('fatal error: $message\n\ngoroutine 1 [running]:\n');
  exitProcess(2);
}

/// `go f()`: agenda uma goroutine nova. Nunca roda `body` de forma síncrona
/// aqui — o `go` statement sempre devolve antes dela começar, como no Go.
///
/// Um panic que sai de [body] sem `recover` imprime e encerra o processo com
/// código 2, como o Go faz para qualquer goroutine (não só a `main`).
void spawn(FutureOr<void> Function() body) {
  ensureAsyncScheduling();
  goroutineStarted();
  final n = ++_goroutineSeq;
  scheduleMicrotask(() async {
    try {
      final r = body();
      if (r is Future) await r;
    } catch (e, st) {
      final value = panicValue(e);
      await flushOutput();
      writeStderr(
        'panic: ${describePanic(value)}\n\ngoroutine $n [running]:\n$st\n',
      );
      exitProcess(2);
    } finally {
      goroutineFinished();
    }
  });
}
