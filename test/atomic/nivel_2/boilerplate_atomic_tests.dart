// test/atomic/nivel_2/boilerplate_atomic_tests.dart
// Testes atomicos 1 para 1 para internal_poll.Golang.Fd.
//
// Nivel 2 porque exige socket real em loopback: o Fd e uma adaptacao da
// semantica de tempo de vida do internal/poll.FD do Go sobre RawSocket, e nao
// tem como ser exercitado sem I/O. Nao depende de daemon externo algum.
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/internal_poll/golang.dart';
import 'package:test/test.dart';

/// Servidor de loopback que aceita e nunca le, para produzir contrapressao.
Future<({ServerSocket server, Fd fd})> _par() async {
  final server = await ServerSocket.bind('127.0.0.1', 0);
  server.listen((_) {});
  final raw = await RawSocket.connect('127.0.0.1', server.port);
  return (server: server, fd: Fd(raw));
}

void main() {
  group('Fd [Atomic Audit]', () {
    test('write() - entrega os bytes e recusa depois de fechado', () async {
      final p = await _par();
      expect(await p.fd.write(Uint8List.fromList([1, 2, 3])), 3);
      await p.fd.close();
      expect(
        () => p.fd.write(Uint8List.fromList([4])),
        throwsA(isA<NetClosingException>()),
      );
      await p.server.close();
    });

    test('read() - recusa depois de fechado com o sentinela do upstream',
        () async {
      final p = await _par();
      await p.fd.close();
      expect(() => p.fd.read(), throwsA(isA<NetClosingException>()));
      await p.server.close();
    });

    test('close() - fecha o descritor e e idempotente', () async {
      final p = await _par();
      await p.fd.close();
      expect(p.fd.isClosed, isTrue);
      await p.fd.close();
      expect(p.fd.isClosed, isTrue);
      await p.server.close();
    });

    test('shutdown() - encerra direcao e recusa depois de fechado', () async {
      final p = await _par();
      await p.fd.shutdown(SocketDirection.send);
      await p.fd.close();
      expect(
        () => p.fd.shutdown(SocketDirection.both),
        throwsA(isA<NetClosingException>()),
      );
      await p.server.close();
    });

    test('isClosed - reflete o fechamento do descritor', () async {
      final p = await _par();
      expect(p.fd.isClosed, isFalse);
      await p.fd.close();
      expect(p.fd.isClosed, isTrue);
      await p.server.close();
    });

    test('isReadClosed - falso enquanto o par nao encerra o envio', () async {
      final p = await _par();
      expect(p.fd.isReadClosed, isFalse);
      await p.fd.close();
      await p.server.close();
    });

    test('destroyed - completa quando o descritor e destruido de fato',
        () async {
      final p = await _par();
      var destruido = false;
      // ignore: unawaited_futures
      p.fd.destroyed.then((_) => destruido = true);
      expect(destruido, isFalse);
      await p.fd.close();
      expect(destruido, isTrue);
      await p.server.close();
    });
  });
}
