// Testes de FdMutex, adaptação de `internal/poll.fdMutex`.
//
// Estes testes são inteiramente determinísticos: o FdMutex não toca em I/O, e
// toda espera aqui é resolvida por uma ação explícita do teste, nunca por
// tempo. Onde é preciso deixar microtasks drenarem, isso é feito com um
// `Future.delayed(Duration.zero)` explícito e o teste afirma o estado nos dois
// lados da drenagem, para que "ainda não completou" seja uma asserção e não uma
// suposição.
//
// Cada invariante coberto aqui foi confirmado por mutação: removê-lo do
// fd_mutex.dart faz ao menos um destes testes falhar.
import 'dart:async';

import 'package:boilerplate/internal_poll/golang.dart';
import 'package:test/test.dart';

/// Deixa a fila de microtasks drenar.
Future<void> _pump([int voltas = 3]) async {
  for (var i = 0; i < voltas; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('FdMutex - travas de leitura e escrita', () {
    test('rwlock adquire leitura e escrita de forma independente', () async {
      final mu = FdMutex();
      expect(await mu.rwlock(true), isTrue);
      expect(
        await mu.rwlock(false),
        isTrue,
        reason: 'leitura e escrita têm travas separadas; tomar uma não pode '
            'impedir a outra, senão um read pendente bloquearia todo write',
      );
    });

    test('segunda trava do mesmo tipo espera, e não completa sozinha',
        () async {
      final mu = FdMutex();
      expect(await mu.rwlock(false), isTrue);

      var segundaCompletou = false;
      unawaited(mu.rwlock(false).then((_) => segundaCompletou = true));

      await _pump();
      expect(
        segundaCompletou,
        isFalse,
        reason: 'esta é a serialização de escrita inteira: se a segunda trava '
            'passasse, dois writes se sobreporiam no mesmo descritor e '
            'produziriam um quadro cortado ao meio na rede',
      );
      expect(mu.writeWaiters, 1);
    });

    test('rwunlock desperta exatamente um esperador', () async {
      final mu = FdMutex();
      await mu.rwlock(false);

      final ordem = <int>[];
      unawaited(mu.rwlock(false).then((_) => ordem.add(1)));
      unawaited(mu.rwlock(false).then((_) => ordem.add(2)));
      await _pump();
      expect(mu.writeWaiters, 2);

      mu.rwunlock(false);
      await _pump();
      expect(
        ordem,
        [1],
        reason: 'a fila é FIFO e libera um de cada vez; despertar os dois '
            'devolveria a trava a ambos e desfaria a exclusão mútua',
      );
      expect(mu.writeWaiters, 1);
    });

    test('rwunlock sem trava correspondente denuncia inconsistência', () {
      final mu = FdMutex();
      expect(() => mu.rwunlock(false), throwsA(isA<StateError>()));
    });

    test('travar leitura não afeta a fila de escrita', () async {
      final mu = FdMutex();
      await mu.rwlock(true);
      unawaited(mu.rwlock(true).then((_) {}));
      await _pump();
      expect(mu.readWaiters, 1);
      expect(mu.writeWaiters, 0);
    });
  });

  group('FdMutex - fechamento', () {
    test('close só tem efeito na primeira vez', () {
      final mu = FdMutex();
      expect(mu.isClosed, isFalse);
      expect(mu.close(), isTrue);
      expect(mu.isClosed, isTrue);
      expect(
        mu.close(),
        isFalse,
        reason: 'é o que faz o segundo Fd.close lançar o sentinela em vez de '
            'destruir duas vezes',
      );
    });

    test('rwlock recusa de imediato quando já fechado', () async {
      final mu = FdMutex();
      mu.close();
      expect(await mu.rwlock(true), isFalse);
      expect(await mu.rwlock(false), isFalse);
    });

    test('fechar desperta TODOS os esperadores, e eles observam o fechamento',
        () async {
      final mu = FdMutex();
      await mu.rwlock(true);
      await mu.rwlock(false);

      final resultados = <bool>[];
      unawaited(mu.rwlock(true).then(resultados.add));
      unawaited(mu.rwlock(true).then(resultados.add));
      unawaited(mu.rwlock(false).then(resultados.add));
      await _pump();
      expect(resultados, isEmpty);
      expect(mu.readWaiters, 2);
      expect(mu.writeWaiters, 1);

      mu.close();
      await _pump();

      expect(
        resultados,
        [false, false, false],
        reason: 'o upstream diz que os despertados "will observe closed flag '
            'after wakeup"; sem isso uma operação parada ficaria pendurada '
            'para sempre quando a conexão fosse fechada sob ela',
      );
      expect(mu.readWaiters, 0);
      expect(mu.writeWaiters, 0);
    });

    test('esperador despertado por rwunlock após fechamento também desiste',
        () async {
      final mu = FdMutex();
      await mu.rwlock(false);

      bool? resultado;
      unawaited(mu.rwlock(false).then((r) => resultado = r));
      await _pump();
      expect(resultado, isNull);

      // Fecha e SÓ ENTÃO libera a trava: o esperador é acordado pelo caminho
      // do rwunlock, não pelo do close, e mesmo assim tem de reavaliar.
      mu.close();
      mu.rwunlock(false);
      await _pump();

      expect(
        resultado,
        isFalse,
        reason: 'reavaliar do topo do laço é o que cobre este caminho; sair da '
            'espera assumindo que a trava está boa entregaria um descritor '
            'fechado a uma operação nova',
      );
    });
  });
}

/// Local, para não importar dart:async só por causa de `unawaited`.
void unawaited(Future<void> future) {}
