// Paridade com go-yamux: `Session.close` espera o escritor terminar antes de
// fechar o transporte.
//
// Em `session.go` o upstream faz `<-s.sendDoneCh` antes de `s.conn.Close()`, com
// o comentário explícito "wait for write loop to exit / We need to write the
// current frame completely before sending a goaway". O port Dart tinha o
// escritor serializado (a cadeia `_writeTail`), mas não tinha esse rendezvous:
// `_close` chamava `transport.close()` sem nunca aguardar a escrita em voo.
//
// Em Go isso ainda assim não quebraria, porque `net.Conn` documenta que Close
// pode correr com Write e o `fdMutex` do `internal/poll` resolve. Em Dart não
// há equivalente: `Socket.close()` durante um `flush()` pendente lança
// "StreamSink is bound to a stream" e derruba o processo por exceção assíncrona
// não tratada — foi o que aconteceu em produção, com o stack
// `YamuxSession._close -> _NoiseYamuxTransport.close -> _TcpRawConn.close`.
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';

/// Transporte que registra a ordem dos eventos e permite segurar uma escrita
/// em voo, para tornar a corrida determinística.
class _RecordingTransport implements YamuxTransport {
  _RecordingTransport({this.holdWrites = false});

  final bool holdWrites;
  final List<String> events = <String>[];
  final _inputController = StreamController<List<int>>();
  final _releaseWrite = Completer<void>();

  @override
  Stream<List<int>> get input => _inputController.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    events.add('write-start');
    if (holdWrites) {
      await _releaseWrite.future;
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    events.add('write-end');
  }

  @override
  Future<void> close() async {
    events.add('close');
    if (!_inputController.isClosed) await _inputController.close();
  }
}

void main() {
  test('close aguarda a escrita em voo antes de fechar o transporte', () async {
    final transport = _RecordingTransport();
    final session = YamuxSession.client(transport);

    // Enfileira um quadro sem aguardar: fica em voo quando o close entrar.
    unawaited(session.goAway());
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await session.close();

    expect(
      transport.events,
      equals(['write-start', 'write-end', 'close']),
      reason: 'o transporte não pode ser fechado por cima de um quadro '
          'escrito pela metade (go-yamux session.go: <-s.sendDoneCh)',
    );
  });

  test('close não trava para sempre se a escrita nunca completa', () async {
    final transport = _RecordingTransport(holdWrites: true);
    final session = YamuxSession.client(
      transport,
      config: const YamuxConfig(
        connectionWriteTimeout: Duration(milliseconds: 200),
      ),
    );

    unawaited(session.goAway());
    await Future<void>.delayed(const Duration(milliseconds: 5));

    // A válvula de segurança equivalente ao ConnectionWriteTimeout do upstream:
    // sem ela, trocaríamos um crash por um deadlock no shutdown.
    await expectLater(
      session.close().timeout(const Duration(seconds: 5)),
      completes,
    );
    expect(transport.events, contains('close'));
  });
}
