// test/atomic/nivel_2/yamux_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo transpiled_go_yamux (37 simbolos).

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';

class _MemoryTransport implements YamuxTransport {
  _MemoryTransport([StreamController<List<int>>? controller])
      : _controller = controller ?? StreamController<List<int>>();

  final StreamController<List<int>> _controller;
  final List<Uint8List> writtenChunks = <Uint8List>[];
  _MemoryTransport? _peer;
  bool _closed = false;

  bool get isClosed => _closed;

  void feed(List<int> bytes) {
    if (!_closed) {
      _controller.add(bytes);
    }
  }

  static (_MemoryTransport, _MemoryTransport) pair() {
    final a = _MemoryTransport();
    final b = _MemoryTransport();
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  @override
  Stream<List<int>> get input => _controller.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    writtenChunks.add(bytes);
    if (!_closed && _peer != null && !_peer!._closed) {
      _peer!._controller.add(Uint8List.fromList(bytes));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    unawaited(_controller.close());
  }
}

void main() {
  group('YamuxFrame [Atomic Audit]', () {
    test('wireLength - retorna tamanho do payload para frames de dados', () {
      final frame = YamuxFrame(
        type: YamuxMessageType.data,
        flags: 0,
        streamId: 1,
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(frame.wireLength, equals(4));
    });

    test('wireLength - retorna campo length para frames de controle', () {
      final frame = YamuxFrame(
        type: YamuxMessageType.windowUpdate,
        flags: 0,
        streamId: 1,
        length: 4096,
      );
      expect(frame.wireLength, equals(4096));
    });

    test('encode() - serializa cabecalho e payload em formato binario', () {
      final frame = YamuxFrame(
        type: YamuxMessageType.data,
        flags: 1,
        streamId: 1234,
        payload: Uint8List.fromList([10, 20, 30]),
      );
      final encoded = frame.encode();
      expect(encoded.length, equals(12 + 3));
      final header = ByteData.sublistView(encoded);
      expect(header.getUint8(0), equals(0));
      expect(header.getUint8(1), equals(YamuxMessageType.data.index));
      expect(header.getUint16(2, Endian.big), equals(1));
      expect(header.getUint32(4, Endian.big), equals(1234));
      expect(header.getUint32(8, Endian.big), equals(3));
      expect(encoded.sublist(12), equals([10, 20, 30]));
    });

    test('decode() - desserializa frame valido a partir de bytes', () {
      final original = YamuxFrame(
        type: YamuxMessageType.windowUpdate,
        flags: 2,
        streamId: 42,
        length: 8192,
      );
      final encoded = original.encode();
      final decoded = YamuxFrame.decode(encoded);
      expect(decoded.version, equals(0));
      expect(decoded.type, equals(YamuxMessageType.windowUpdate));
      expect(decoded.flags, equals(2));
      expect(decoded.streamId, equals(42));
      expect(decoded.length, equals(8192));
    });

    test('decode() - lanca YamuxProtocolException quando cabecalho e truncado', () {
      final shortBytes = Uint8List(8);
      expect(
        () => YamuxFrame.decode(shortBytes),
        throwsA(isA<YamuxProtocolException>()),
      );
    });

    test('toString() - formata informacoes do frame em string', () {
      final frame = YamuxFrame(
        type: YamuxMessageType.ping,
        flags: 1,
        streamId: 0,
        length: 77,
      );
      final str = frame.toString();
      expect(str, contains('YamuxFrame'));
      expect(str, contains('type: YamuxMessageType.ping'));
      expect(str, contains('flags: 1'));
      expect(str, contains('length: 77'));
    });
  });

  group('YamuxFrameDecoder [Atomic Audit]', () {
    test('add() - decodifica frames recebidos incrementalmente em pedacos', () {
      final decoder = YamuxFrameDecoder();
      final frame = YamuxFrame(
        type: YamuxMessageType.data,
        flags: 0,
        streamId: 5,
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      final bytes = frame.encode();
      final part1 = decoder.add(bytes.sublist(0, 6));
      expect(part1, isEmpty);
      final part2 = decoder.add(bytes.sublist(6));
      expect(part2.length, equals(1));
      final decoded = part2.first;
      expect(decoded.streamId, equals(5));
      expect(decoded.payload, equals([1, 2, 3, 4, 5]));
    });

    test('add() - lanca YamuxProtocolException quando versao do protocolo e invalida', () {
      final decoder = YamuxFrameDecoder();
      final invalidHeader = Uint8List.fromList([
        99, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
      ]);
      expect(
        () => decoder.add(invalidHeader),
        throwsA(isA<YamuxProtocolException>()),
      );
    });

    test('add() - lanca YamuxProtocolException quando tamanho excede maxDataLength', () {
      final decoder = YamuxFrameDecoder(maxDataLength: 4);
      final frame = YamuxFrame(
        type: YamuxMessageType.data,
        payload: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
      );
      final bytes = frame.encode();
      expect(
        () => decoder.add(bytes),
        throwsA(isA<YamuxProtocolException>()),
      );
    });
  });

  group('YamuxConfig [Atomic Audit]', () {
    test('verify() - valida configuracao padrao com sucesso', () {
      expect(() => YamuxConfig.defaults.verify(), returnsNormally);
    });

    test('verify() - lanca YamuxConfigException para acceptBacklog invalido', () {
      const invalidConfig = YamuxConfig(acceptBacklog: 0);
      expect(
        () => invalidConfig.verify(),
        throwsA(isA<YamuxConfigException>()),
      );
    });

    test('verify() - lanca YamuxConfigException para maxMessageSize menor que 1024', () {
      const invalidConfig = YamuxConfig(maxMessageSize: 512);
      expect(
        () => invalidConfig.verify(),
        throwsA(isA<YamuxConfigException>()),
      );
    });

    test('verify() - lanca YamuxConfigException para initialStreamWindowSize invalido', () {
      const invalidConfig = YamuxConfig(initialStreamWindowSize: 1024);
      expect(
        () => invalidConfig.verify(),
        throwsA(isA<YamuxConfigException>()),
      );
    });

    test('verify() - lanca YamuxConfigException para maxStreamWindowSize menor que initial', () {
      const invalidConfig = YamuxConfig(
        initialStreamWindowSize: 256 * 1024,
        maxStreamWindowSize: 128 * 1024,
      );
      expect(
        () => invalidConfig.verify(),
        throwsA(isA<YamuxConfigException>()),
      );
    });
  });

  group('YamuxConfigException [Atomic Audit]', () {
    test('toString() - retorna mensagem de erro de configuracao', () {
      final ex = YamuxConfigException('parametro invalido');
      expect(ex.toString(), equals('parametro invalido'));
    });
  });

  group('YamuxProtocolException [Atomic Audit]', () {
    test('toString() - retorna mensagem de violacao de protocolo', () {
      final ex = YamuxProtocolException('violacao de protocolo');
      expect(ex.toString(), equals('violacao de protocolo'));
    });
  });

  group('YamuxStreamResetException [Atomic Audit]', () {
    test('toString() - formata origem remota ou local e codigo de erro', () {
      final exRemote = YamuxStreamResetException(remote: true, errorCode: 42);
      expect(exRemote.toString(), contains('remote'));
      expect(exRemote.toString(), contains('42'));

      final exLocal = YamuxStreamResetException(remote: false, errorCode: 0);
      expect(exLocal.toString(), contains('local'));
      expect(exLocal.toString(), contains('0'));
    });
  });

  group('YamuxSessionClosedException [Atomic Audit]', () {
    test('toString() - retorna motivo do encerramento da sessao', () {
      final exDefault = YamuxSessionClosedException();
      expect(exDefault.toString(), equals('session shutdown'));

      final exCustom = YamuxSessionClosedException('conexao encerrada');
      expect(exCustom.toString(), equals('conexao encerrada'));
    });
  });

  group('YamuxTransport [Atomic Audit]', () {
    test('input - expoe stream para leitura de dados de transporte', () async {
      final transport = _MemoryTransport();
      expect(transport.input, isA<Stream<List<int>>>());
      transport.feed([10, 20, 30]);
      final chunk = await transport.input.first;
      expect(chunk, equals([10, 20, 30]));
      await transport.close();
    });

    test('write() - envia bytes para o canal de saida do transporte', () async {
      final transport = _MemoryTransport();
      final data = Uint8List.fromList([1, 2, 3, 4]);
      await transport.write(data);
      expect(transport.writtenChunks, contains(data));
      await transport.close();
    });

    test('close() - fecha o canal de transmissao do transporte', () async {
      final transport = _MemoryTransport();
      expect(transport.isClosed, isFalse);
      await transport.close();
      expect(transport.isClosed, isTrue);
    });
  });

  group('YamuxSession [Atomic Audit]', () {
    test('isClosed - indica se a sessao foi encerrada', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      expect(client.isClosed, isFalse);
      await client.close();
      await server.close();
      expect(client.isClosed, isTrue);
    });

    test('closeFuture - future completa quando a sessao encerra', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      var completed = false;
      unawaited(client.closeFuture.then((_) => completed = true));
      expect(completed, isFalse);
      await client.close();
      await server.close();
      expect(completed, isTrue);
    });

    test('numStreams - rastreia quantidade de streams ativas na sessao', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final outgoing = await client.openStream();
      final incoming = await acceptFuture;
      expect(client.numStreams, equals(1));
      expect(server.numStreams, equals(1));
      await outgoing.close();
      await incoming.close();
      await Future<void>.delayed(Duration.zero);
      expect(client.numStreams, equals(0));
      expect(server.numStreams, equals(0));
      await client.close();
      await server.close();
    });

    test('numIncomingStreams - rastreia streams recebidas pela sessao', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final outgoing = await client.openStream();
      final incoming = await acceptFuture;
      expect(server.numIncomingStreams, equals(1));
      await outgoing.close();
      await incoming.close();
      await Future<void>.delayed(Duration.zero);
      expect(server.numIncomingStreams, equals(0));
      await client.close();
      await server.close();
    });

    test('openStream() - abre uma nova stream de saida com timeout', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final outgoing = await client.openStream(
        timeout: const Duration(seconds: 2),
      );
      final incoming = await acceptFuture;
      expect(outgoing.streamId, equals(1));
      expect(incoming.streamId, equals(1));
      await outgoing.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('acceptStream() - aceita stream aberta pelo peer', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final outgoing = await client.openStream();
      final incoming = await acceptFuture;
      expect(incoming.streamId, equals(outgoing.streamId));
      await outgoing.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('open() - metodo de conveniencia equivalente a openStream', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.accept();
      final outgoing = await client.open();
      final incoming = await acceptFuture;
      expect(outgoing.streamId, equals(1));
      expect(incoming.streamId, equals(1));
      await outgoing.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('accept() - metodo de conveniencia equivalente a acceptStream', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.accept();
      final outgoing = await client.open();
      final incoming = await acceptFuture;
      expect(incoming.streamId, equals(outgoing.streamId));
      await outgoing.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('goAway() - envia frame goAway e impede abertura de novas streams', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      await client.goAway();
      expect(
        () => client.openStream(),
        throwsA(isA<YamuxSessionClosedException>()),
      );
      await client.close();
      await server.close();
    });

    test('closeWithError() - encerra a sessao enviando goAway com codigo de erro', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      await client.closeWithError(99);
      expect(client.isClosed, isTrue);
      await server.close();
    });

    test('close() - encerra a sessao e recursos associados', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      await client.close(reason: 'encerramento de teste');
      expect(client.isClosed, isTrue);
      await server.close();
    });
  });

  group('YamuxStreamsExhaustedException [Atomic Audit]', () {
    test('toString() - retorna mensagem de streams esgotadas', () {
      final ex = YamuxStreamsExhaustedException();
      expect(ex.toString(), equals('streams exhausted'));
    });
  });

  group('YamuxStream [Atomic Audit]', () {
    test('streamId - retorna o identificador numerico da stream', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      expect(stream.streamId, equals(1));
      expect(incoming.streamId, equals(1));
      await stream.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('streamID - alias em maiusculo compativel com padrao Go', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      expect(stream.streamID, equals(stream.streamId));
      expect(incoming.streamID, equals(incoming.streamId));
      await stream.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('isClosed - indica quando os dois lados ou reset encerraram a stream', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      expect(stream.isClosed, isFalse);
      await stream.close();
      await incoming.close();
      expect(stream.isClosed, isTrue);
      await client.close();
      await server.close();
    });

    test('bufferedBytes - indica quantidade de bytes pendentes no buffer de leitura', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      await stream.write(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(incoming.bufferedBytes, equals(7));
      await incoming.read();
      expect(incoming.bufferedBytes, equals(0));
      await stream.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('write() - envia dados pela stream com sucesso', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      final payload = Uint8List.fromList([11, 22, 33, 44]);
      final written = await stream.write(payload);
      expect(written, equals(4));
      final received = await incoming.read();
      expect(received, equals([11, 22, 33, 44]));
      await stream.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('read() - le dados recebidos na stream ou null no encerramento', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      await stream.write(Uint8List.fromList([55, 66]));
      final chunk = await incoming.read();
      expect(chunk, equals([55, 66]));
      await stream.closeWrite();
      final eof = await incoming.read();
      expect(eof, isNull);
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('readInto() - preenche buffer alvo com bytes recebidos e retorna tamanho', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      await stream.write(Uint8List.fromList([7, 8, 9]));
      final target = Uint8List(3);
      final bytesRead = await incoming.readInto(target);
      expect(bytesRead, equals(3));
      expect(target, equals([7, 8, 9]));
      await stream.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('closeWrite() - encerra lado de escrita e envia flag FIN', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      await stream.closeWrite();
      expect(
        () => stream.write(Uint8List.fromList([1, 2])),
        throwsA(isA<YamuxSessionClosedException>()),
      );
      final eof = await incoming.read();
      expect(eof, isNull);
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('closeRead() - encerra lado de leitura da stream', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      await incoming.closeRead();
      expect(
        incoming.read(),
        throwsA(isA<YamuxStreamResetException>()),
      );
      await stream.close();
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('close() - encerra ambos os lados de leitura e escrita', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      await stream.close();
      expect(stream.isClosed, isTrue);
      await incoming.close();
      await client.close();
      await server.close();
    });

    test('reset() - cancela stream com codigo opcional e notifica peer', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      final readFuture = incoming.read();
      await stream.reset(42);
      expect(
        readFuture,
        throwsA(isA<YamuxStreamResetException>()),
      );
      expect(stream.isClosed, isTrue);
      await client.close();
      await server.close();
    });

    test('resetWithError() - reseta stream com codigo de erro especifico', () async {
      final (clientTransport, serverTransport) = _MemoryTransport.pair();
      final client = YamuxSession.client(clientTransport);
      final server = YamuxSession.server(serverTransport);
      final acceptFuture = server.acceptStream();
      final stream = await client.openStream();
      final incoming = await acceptFuture;
      final readFuture = incoming.read();
      await stream.resetWithError(77);
      expect(
        readFuture,
        throwsA(isA<YamuxStreamResetException>()),
      );
      expect(stream.isClosed, isTrue);
      await client.close();
      await server.close();
    });
  });
}
