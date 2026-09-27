/// `select` do Go sobre [Chan].
library;

import 'dart:async';
import 'dart:math';

import 'chan.dart';
import 'panic.dart';
import 'sched.dart';

/// Um `case` de `select`.
sealed class SelectCase {}

/// `case ch <- value:`.
final class SendCase<T> extends SelectCase {
  SendCase(this.ch, this.value);
  final Chan<T>? ch;
  final T value;
}

/// `case v := <-ch:` ou `case v, ok := <-ch:`.
final class RecvCase<T> extends SelectCase {
  RecvCase(this.ch);
  final Chan<T>? ch;
}

final _rand = Random();

bool _ready(SelectCase c) {
  if (c is RecvCase) return c.ch?.$recvReady() ?? false;
  if (c is SendCase) return c.ch?.$sendReady() ?? false;
  throw StateError('caso de select desconhecido: $c');
}

(int, Object?, bool) _commit(int i, SelectCase c) {
  if (c is RecvCase) {
    final (v, ok) = c.ch!.$commitRecv();
    return (i, v, ok);
  }
  if (c is SendCase) {
    c.ch!.$commitSend(c.value);
    return (i, null, true);
  }
  throw StateError('caso de select desconhecido: $c');
}

/// `select` com `default`: nunca suspende. `-1` se nenhum caso está pronto
/// (é quando o `default` roda); um canal nil nunca deixa seu caso pronto.
///
/// Com mais de um caso pronto, a escolha é uniforme pseudoaleatória, como o
/// Go (inclusive quando o caso escolhido é um `send` num canal fechado: ele
/// "está pronto" — a operação só panica ao ser de fato executada).
(int, Object?, bool) selectNow(List<SelectCase> cases) {
  final ready = <int>[];
  for (var i = 0; i < cases.length; i++) {
    if (_ready(cases[i])) ready.add(i);
  }
  if (ready.isEmpty) return (-1, null, false);
  final i = ready.length == 1 ? ready[0] : ready[_rand.nextInt(ready.length)];
  return _commit(i, cases[i]);
}

/// `select` sem `default`: bloqueia até um caso ficar pronto (escolha
/// uniforme pseudoaleatória entre os prontos, como [selectNow]). Lista vazia
/// (`select {}`) ou só com canais nil bloqueia para sempre.
///
/// Um `send` escolhido cujo canal fecha enquanto ainda esperava propaga o
/// panic `send on closed channel`, como o Go.
Future<(int, Object?, bool)> select(List<SelectCase> cases) async {
  final now = selectNow(cases);
  if (now.$1 != -1) return now;

  final completer = Completer<(int, Object?, bool)>();
  final cancels = <void Function()>[];
  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    if (c is RecvCase) {
      final ch = c.ch;
      if (ch == null) continue;
      cancels.add(
        ch.$registerRecvWaiter((v, ok) {
          if (!completer.isCompleted) completer.complete((i, v, ok));
        }),
      );
    } else if (c is SendCase) {
      final ch = c.ch;
      if (ch == null) continue;
      final value = c.value;
      cancels.add(
        ch.$registerSendWaiter(value, (closed) {
          if (completer.isCompleted) return;
          if (closed) {
            completer.completeError(
              Panic(const RuntimeError('send on closed channel')),
            );
          } else {
            completer.complete((i, null, true));
          }
        }),
      );
    }
  }

  goroutineBlocked();
  try {
    return await completer.future;
  } finally {
    goroutineUnblocked();
    for (final cancel in cancels) {
      cancel();
    }
  }
}
