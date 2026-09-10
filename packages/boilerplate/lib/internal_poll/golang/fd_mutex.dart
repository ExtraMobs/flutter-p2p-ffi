// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:collection';

/// Primitiva de sincronização que serializa o acesso a `read`, `write` e
/// `close` de um descritor.
///
/// Adaptação de `fdMutex` (`internal/poll/fd_mutex.go`). O comentário do
/// upstream define o contrato:
///
/// > fdMutex is a specialized synchronization primitive that manages
/// > lifetime of an fd and serializes access to Read, Write and Close
/// > methods on FD.
///
/// ## Contrato de uso
///
/// - Operações de leitura fazem `rwlock(true)` / `rwunlock(true)`.
/// - Operações de escrita fazem `rwlock(false)` / `rwunlock(false)`.
/// - Fechamento faz [close], uma vez só.
///
/// ## O que foi adaptado, e por quê
///
/// O Go empacota o estado num `uint64` manipulado por laços de compare-and-swap
/// atômico, porque múltiplas threads do SO disputam a mesma estrutura. Um
/// isolate Dart é single-threaded: entre dois pontos de suspensão (`await`)
/// nenhuma outra execução observa estado intermediário, então o empacotamento
/// em bits e o laço de CAS não teriam função — copiá-los seria mímica sem
/// semântica. O que é preservado é a máquina de estados: flag de fechado,
/// travas exclusivas de leitura e de escrita, filas de espera, e as regras de
/// transição entre elas.
///
/// O `rwlock` do Go bloqueia numa semáfora do runtime (`runtime_Semacquire`).
/// Dart não tem bloqueio; a espera vira um `Completer` numa fila FIFO e
/// [rwlock] passa a ser assíncrono. A consequência observável é a mesma — quem
/// espera só prossegue quando a trava é liberada, e **reavalia a flag de
/// fechado ao acordar**, exatamente como no upstream, onde o laço de `rwlock`
/// recomeça após a semáfora e o comentário de `increfAndClose` diz que os
/// despertados "will observe closed flag after wakeup".
///
/// ## O que foi removido, e por quê
///
/// O upstream mantém uma contagem de referências (`incref`/`decref`) cujo
/// propósito ele próprio declara: garantir que uma operação em voo "opera no fd
/// correto na presença de um close concorrente, senão o fd pode ser fechado sob
/// seus pés". O recurso protegido lá é `fd.Sysfd`, um **inteiro**: o `close(2)`
/// devolve o número ao kernel, que pode reciclá-lo para outra conexão, e uma
/// syscall atrasada escreveria no socket errado.
///
/// Esse perigo não existe aqui. `RawSocket` é referência de objeto, não número
/// reciclável, e o próprio VM recusa operações sobre um socket fechado. A
/// contagem foi removida em vez de mantida por fidelidade: mutação confirmou
/// que nenhum teste a distinguia de sua ausência. O propósito que ela serve —
/// não destruir o recurso enquanto uma operação ainda se desenrola — continua
/// atendido no `Fd`, mas pelo runtime e não por bookkeeping: ver o comentário
/// de `Fd.close`, que explica por que o `await` de `_destroy` já garante isso.
final class FdMutex {
  bool _closed = false;
  bool _rLocked = false;
  bool _wLocked = false;
  final Queue<Completer<void>> _rWaiters = Queue<Completer<void>>();
  final Queue<Completer<void>> _wWaiters = Queue<Completer<void>>();

  /// Se o descritor já foi marcado como fechado.
  bool get isClosed => _closed;

  /// Número de esperas pendentes pela trava de leitura.
  int get readWaiters => _rWaiters.length;

  /// Número de esperas pendentes pela trava de escrita.
  int get writeWaiters => _wWaiters.length;

  /// Marca o descritor como fechado.
  ///
  /// Retorna `false` se já estava fechado. Todos os que esperam por trava são
  /// despertados: eles reavaliam a flag e desistem. Go:
  /// `fdMutex.increfAndClose`.
  bool close() {
    if (_closed) return false;
    _closed = true;
    // Go remove os contadores de espera e libera todas as semáforas de uma vez.
    while (_rWaiters.isNotEmpty) {
      _rWaiters.removeFirst().complete();
    }
    while (_wWaiters.isNotEmpty) {
      _wWaiters.removeFirst().complete();
    }
    return true;
  }

  /// Adquire a trava de leitura ([read] verdadeiro) ou de escrita ([read]
  /// falso).
  ///
  /// Completa com `false` se o descritor estiver fechado, tanto na entrada
  /// quanto ao ser despertado de uma espera. Go: `fdMutex.rwlock`.
  Future<bool> rwlock(bool read) async {
    while (true) {
      if (_closed) return false;
      final locked = read ? _rLocked : _wLocked;
      if (!locked) {
        if (read) {
          _rLocked = true;
        } else {
          _wLocked = true;
        }
        return true;
      }
      final waiter = Completer<void>();
      (read ? _rWaiters : _wWaiters).add(waiter);
      await waiter.future;
      // Reavalia do topo: o upstream volta ao início do laço após a semáfora,
      // então quem acorda pode encontrar tanto a trava tomada de novo quanto o
      // descritor fechado.
    }
  }

  /// Libera a trava correspondente, despertando um esperador se houver.
  ///
  /// Go: `fdMutex.rwunlock`.
  void rwunlock(bool read) {
    final locked = read ? _rLocked : _wLocked;
    if (!locked) {
      throw StateError('inconsistent poll.fdMutex');
    }
    if (read) {
      _rLocked = false;
    } else {
      _wLocked = false;
    }
    final waiters = read ? _rWaiters : _wWaiters;
    if (waiters.isNotEmpty) {
      waiters.removeFirst().complete();
    }
  }
}
