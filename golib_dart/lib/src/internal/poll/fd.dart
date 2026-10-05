// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'errors.dart';
import 'fd_mutex.dart';
import 'poll_desc.dart';

/// Descritor de rede não-bloqueante com a semântica de tempo de vida do Go.
///
/// Port de `internal/poll.FD` (`internal/poll/fd_unix.go`) sobre o [RawSocket]
/// do `dart:io`.
///
/// ## O problema que este tipo existe para resolver
///
/// A interface `net.Conn` do Go documenta que "multiple goroutines may invoke
/// methods on a Conn simultaneously", e o `Close` pode correr com um `Write` em
/// voo. Essa garantia não é retórica: ela é implementada pelo `internal/poll`,
/// com o [FdMutex] serializando as operações e o `Close` em três fases —
/// marcar fechado, desbloquear quem está parado, destruir quando a última
/// referência sai.
///
/// O `Socket` do `dart:io` não oferece equivalente. Ele é um `IOSink`, e o
/// `flush()` marca o sink como *bound* enquanto está pendente
/// (`io_sink.dart`, `_StreamSinkImpl.flush`, `_isBound = true` limpo num
/// `whenComplete`), de modo que um `close()` concorrente encontra esse estado e
/// lança `StateError('StreamSink is bound to a stream')`. Em produção isso
/// derrubou o processo por exceção assíncrona não tratada.
///
/// O [RawSocket], porém, oferece exatamente as primitivas que o `poll.FD`
/// pressupõe, o que torna o port viável em vez de uma imitação:
///
/// - `int write(...)` é síncrono e não-bloqueante, e o doc do SDK afirma que
///   "the number of successfully written bytes may be less than `count` or even
///   0" — que é a semântica de `write(2)` com `EAGAIN`.
/// - `Uint8List? read(...)` devolve `null` quando não há dados, equivalente a
///   `EAGAIN` na leitura.
/// - `Future<RawSocket> close()` — o doc afirma que "calling [close] will never
///   throw an exception and calling it several times is supported".
/// - `RawSocketEvent.read` / `.write` fazem o papel do netpoller.
///
/// ## Armadilha do `writeEventsEnabled`
///
/// O doc do SDK é explícito: "This is a one-shot listener, and
/// writeEventsEnabled must be set to true again to receive another write
/// event." Ambos os flags nascem `true`. Este port desliga o de escrita na
/// construção e só o religa ao efetivamente parar para esperar, que é o que o
/// netpoller do Go faz — registrar interesse apenas quando bloquearia. Esquecer
/// de religar produz uma escrita presa para sempre; religar sem necessidade
/// produz eventos espúrios. Isso, os eventos e as esperas vivem no
/// [PollDesc], como o `pollDesc` do Go.
final class Fd {
  Fd(this._socket, {bool isFile = false})
    : _isFile = isFile,
      _pd = PollDesc(_socket);

  final RawSocket _socket;
  final bool _isFile;
  final FdMutex _fdmu = FdMutex();
  final PollDesc _pd;
  final Completer<void> _destroyed = Completer<void>();

  /// Se o descritor já foi marcado como fechado.
  ///
  /// [close] é idempotente, então isto não é necessário para fechar em
  /// segurança; serve a quem precisa distinguir se o fechamento partiu daqui.
  bool get isClosed => _fdmu.isClosed;

  /// Se o par já sinalizou fim de leitura (`RawSocketEvent.readClosed`).
  bool get isReadClosed => _pd.readClosed;

  /// Completa quando o descritor foi realmente destruído, isto é, quando as
  /// operações em voo assentaram e o socket subjacente foi fechado.
  ///
  /// Equivale a esperar na semáfora `csema` que o `FD.Close` do Go aguarda.
  Future<void> get destroyed => _destroyed.future;

  /// Escreve [buffer] por inteiro, respeitando a contrapressão do socket.
  ///
  /// Port de `FD.Write`. Escreve em laço o que o kernel aceitar e, quando ele
  /// deixa de aceitar, estaciona à espera de prontidão em vez de girar em
  /// espera ocupada. Lança [NetClosingException] — ou [FileClosingException] — se o
  /// descritor estiver fechado na entrada ou for fechado durante a espera.
  ///
  /// Diferente do `flush()` do `IOSink`, o future só completa quando **estes**
  /// bytes foram entregues ao kernel, o que dá contrapressão real por chamada.
  ///
  /// [progress], se dado, recebe o total já aceito pelo kernel a cada avanço:
  /// é o `n` que o `FD.Write` do Go devolve junto com o erro quando a escrita
  /// é interrompida no meio (prazo, fechamento, erro do socket).
  ///
  /// Um prazo de escrita vencido ([setWriteDeadline]) lança
  /// [DeadlineExceededException], antes de tocar no socket ou ao acordar.
  Future<int> write(
    Uint8List buffer, {
    void Function(int written)? progress,
  }) async {
    if (!await _fdmu.rwlock(false)) throw errClosing(isFile: _isFile);
    try {
      var written = 0;
      while (written < buffer.length) {
        // `prepareWrite` do Go: prazo vencido falha antes da syscall.
        if (_pd.writeExpired) throw const DeadlineExceededException();
        final accepted = _socket.write(
          buffer,
          written,
          buffer.length - written,
        );
        written += accepted;
        if (accepted > 0) progress?.call(written);
        if (written < buffer.length) {
          // Aceitou menos que o pedido: é o EAGAIN do dart:io. Estaciona à
          // espera de prontidão. Não é preciso reavaliar o estado antes de
          // estacionar: um isolate é single-threaded, nada pode fechar entre a
          // linha acima e esta, e um fechamento posterior desperta a espera via
          // eviction. Só ao acordar é que o estado pode ter mudado.
          await _pd.waitWrite();
          _throwIfBroken();
          if (_pd.writeExpired) throw const DeadlineExceededException();
        }
      }
      return written;
    } finally {
      _fdmu.rwunlock(false);
    }
  }

  /// Lê até [len] bytes, esperando por dados se necessário.
  ///
  /// Port de `FD.Read`. Devolve uma lista vazia quando o par fechou a direção
  /// de leitura, que é o equivalente do `io.EOF` do Go neste ponto. Lança o
  /// sentinela de fechamento se o descritor for fechado durante a espera.
  Future<Uint8List> read([int? len]) async {
    if (!await _fdmu.rwlock(true)) throw errClosing(isFile: _isFile);
    try {
      while (true) {
        // Fechado localmente e prazo vencido vêm antes de tudo, como no
        // `prepareRead` do Go (que falha antes da syscall, mesmo com dado ou
        // EOF esperando). O despejo por `closed` do par não entra aqui: ele
        // ainda entrega o EOF abaixo.
        if (_fdmu.isClosed) throw errClosing(isFile: _isFile);
        if (_pd.readExpired) throw const DeadlineExceededException();
        // O fim de leitura é verificado ANTES de tocar no socket, e isso é
        // obrigatório, não estilo. Duas razões, ambas verificadas:
        //
        // 1. O doc do `shutdown` no SDK garante que a direção de recepção "is
        //    only considered to be fully shutdown once all available data is
        //    drained and RawSocketEvent.readClosed is dispatched" — ou seja,
        //    quando o `readClosed` chega, não restou dado por ler. Consultar a
        //    flag primeiro não perde bytes.
        // 2. Chamar `RawSocket.read()` depois do `readClosed` devolve `null`,
        //    mas dispara um evento de erro assíncrono (`SocketException:
        //    Read failed`, no Windows) que envenena o descritor: o que se
        //    observa na sequência real é
        //    `read | readClosed | <leitura extra> | ERRO | closed | DONE`.
        //    Uma leitura inofensiva em aparência transforma um EOF limpo em
        //    falha de conexão.
        if (_pd.readClosed) return Uint8List(0);
        // Só toca no socket quando a prontidão foi anunciada. O `FD.Read` do Go
        // pode chamar a syscall a seco porque um `read(2)` sem dado devolve
        // EAGAIN e nada mais acontece; aqui não é assim. Uma leitura
        // especulativa, antes do primeiro `RawSocketEvent.read`, dispara o
        // mesmo evento de erro que uma leitura após o EOF — devolve `null` e
        // ainda assim envenena o descritor. A prontidão, neste port, chega por
        // evento, e é ela que faz o papel do retorno do syscall.
        if (_pd.readable) {
          final data = _socket.read(len);
          if (data != null && data.isNotEmpty) {
            // Esvaziou: religa os eventos de leitura (ver `PollDesc`).
            if (_socket.available() == 0) _pd.drained();
            return data;
          }
          _pd.readable = false;
        }
        _throwIfBroken();
        await _pd.waitRead();
        // Sem reavaliação aqui de propósito: o laço volta ao topo e refaz a
        // ordem correta. Checar erro logo após acordar reintroduziria o mesmo
        // defeito, mascarando o EOF de quem foi acordado justamente pelo
        // `readClosed` do par.
      }
    } finally {
      _fdmu.rwunlock(true);
    }
  }

  /// Fecha o descritor.
  ///
  /// Adaptação de `FD.Close`, com as mesmas três fases do upstream:
  ///
  /// 1. [FdMutex.close] marca o descritor como fechado, de modo que toda
  ///    operação nova falhe de imediato, e desperta quem espera por trava.
  /// 2. `evict` desbloqueia quem está parado esperando prontidão de I/O; essas
  ///    esperas terminam com o sentinela de fechamento.
  /// 3. `_destroy` cancela a inscrição e fecha o socket.
  ///
  /// Ao retornar, **nenhum callback desta conexão dispara mais** — nem de uma
  /// operação estacionada, nem de uma que ainda estava na fila da trava. Vale a
  /// pena registrar por que isso sai de graça, porque é contraintuitivo e foi
  /// medido: o `await` de `_destroy` sobre `_subscription.cancel()` devolve o
  /// controle ao event loop, que drena a fila de microtasks **inteira** antes
  /// do próximo evento. Toda operação acordada pelas fases 1 e 2 assenta ali,
  /// independentemente de quantas sejam.
  ///
  /// Esse é o motivo de este port NÃO ter contagem de referências nem espera
  /// explícita pelos futures em voo. Ambas foram construídas e removidas: com
  /// 64 operações enfileiradas, mutação confirmou que nenhum teste distingue
  /// sua presença de sua ausência, e a versão com futures ainda cobrava
  /// alocação por operação no caminho quente. A dependência real está no
  /// `await` de `_destroy`; torná-lo síncrono quebraria esta garantia.
  ///
  /// Fechar duas vezes é seguro: o segundo chamador espera pela destruição em
  /// curso e retorna. Ver o corpo do método para por que este ponto diverge do
  /// `FD.Close` do Go de propósito.
  Future<void> close() async {
    if (!_fdmu.close()) {
      // Já fechado. Idempotente, e aqui o port se afasta do upstream de
      // propósito. O `FD.Close` do Go devolve `errClosing` no segundo
      // fechamento, e lá isso é inofensivo: `Close` DEVOLVE um erro, e o idioma
      // dominante — `defer conn.Close()` — descarta o retorno. Em Dart viraria
      // exceção lançada, e o teardown equivalente (`finally { await close(); }`
      // somado a um fechamento explícito no caminho feliz) transformaria uma
      // corrida rotineira em erro assíncrono não tratado. Ou seja: preservar o
      // comportamento do Go reintroduziria exatamente a classe de falha que
      // este tipo existe para eliminar.
      //
      // Todo o `dart:io` fecha assim — `RawSocket.close()` documenta que
      // "calling it several times is supported", e `IOSink.close()`,
      // `StreamSubscription.cancel()` e `HttpClient.close()` seguem o mesmo.
      //
      // Devolver `_destroyed` em vez de retornar seco dá ao segundo chamador a
      // mesma promessa que o primeiro recebe: ao voltar daqui, nada desta
      // conexão dispara mais. Quem precisar distinguir os dois casos consulta
      // [isClosed] antes.
      return _destroyed.future;
    }
    _pd.evict();
    await _destroy();
    // Esta espera é o que sustenta a promessa de que nada desta conexão dispara
    // depois do retorno, e ela NÃO é redundante: `_destroy` completa
    // `_destroyed`, mas os callbacks registrados em [destroyed] ainda são
    // microtasks não executadas. Verificado por mutação — removê-la faz um
    // teste cair na hora.
    await _destroyed.future;
  }

  /// Fecha uma das direções do socket.
  ///
  /// Port de `FD.Shutdown`, que toma uma referência justamente para não operar
  /// sobre um descritor fechado sob seus pés.
  Future<void> shutdown(SocketDirection direction) async {
    if (_fdmu.isClosed) throw errClosing(isFile: _isFile);
    _socket.shutdown(direction);
  }

  /// `FD.SetReadDeadline`: vale também para a leitura já estacionada;
  /// `null` tira o prazo, e um instante no passado vence na hora.
  void setReadDeadline(DateTime? deadline) => _pd.setReadDeadline(deadline);

  /// `FD.SetWriteDeadline` (mesmas regras de [setReadDeadline]).
  void setWriteDeadline(DateTime? deadline) => _pd.setWriteDeadline(deadline);

  /// `FD.SetDeadline`: os dois prazos de uma vez.
  void setDeadline(DateTime? deadline) {
    _pd.setReadDeadline(deadline);
    _pd.setWriteDeadline(deadline);
  }

  /// Quem acordou de uma espera ([PollDesc.evict], erro do socket ou fechado)
  /// desiste com o erro ou o sentinela.
  void _throwIfBroken() {
    final error = _pd.ioError;
    if (error != null) throw error;
    if (_pd.evicted || _fdmu.isClosed) throw errClosing(isFile: _isFile);
  }

  Future<void> _destroy() async {
    if (_destroyed.isCompleted) return;
    // Go desregistra do poller antes de fechar: `fd.pd.close()` precede o
    // fechamento em `FD.destroy`.
    await _pd.close();
    // O doc do SDK garante que este close nunca lança e é idempotente.
    await _socket.close();
    if (!_destroyed.isCompleted) _destroyed.complete();
  }
}
