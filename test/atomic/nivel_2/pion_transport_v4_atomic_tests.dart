// test/atomic/nivel_2/pion_transport_v4_atomic_tests.dart
// Testes atômicos 1 para 1 para os subpacotes deadline, stdnet e netctx de
// pion/transport v4 (transpiled_pion_transport_v4). Vetores de deadline
// adaptados de
// go-ipfs-reference/pion-transport-v4/deadline/deadline_test.go (idêntico
// em comportamento ao de v3, ver doc-comment de lib/src/deadline.dart).
// stdnet e netctx exigem sockets loopback reais/estado local -- por isso
// nível 2 ("emulação local/memória... trocas locais sem daemons externos").

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';

/// Test double for [UdpConn] used only to drive [PacketConn]'s cancellation
/// race deterministically, without a real socket. Test-only per this
/// project's Rule 14 (test doubles must live under test/, never lib/).
class _FakeUdpConn implements UdpConn {
  final Completer<(int, NetAddr)> readCompleter = Completer<(int, NetAddr)>();
  final Completer<int> writeCompleter = Completer<int>();
  bool closeCalled = false;

  @override
  NetAddr get localAddr => UdpAddr(InternetAddress.loopbackIPv4, 9000);

  @override
  NetAddr get remoteAddr => UdpAddr(InternetAddress.loopbackIPv4, 9001);

  @override
  Future<void> close() async {
    closeCalled = true;
  }

  @override
  Future<(int, NetAddr)> readFrom(Uint8List buffer) => readCompleter.future;

  @override
  Future<int> writeTo(Uint8List buffer, NetAddr addr) => writeCompleter.future;
}

/// Waits for the next datagram to arrive on [socket], with a timeout so a
/// broken test fails fast instead of hanging.
Future<Datagram> _receiveOne(RawDatagramSocket socket) async {
  await for (final event in socket.timeout(const Duration(seconds: 5))) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) return datagram;
    }
  }
  throw StateError('socket closed before a datagram arrived');
}

void main() {
  group('Deadline [Atomic Audit]', () {
    test('Deadline() - construtor inicia sem prazo definido', () {
      final d = Deadline();
      expect(d.deadline, isNull);
      expect(d.err, isNull);
    });

    test('done() - completa quando o prazo definido expira', () async {
      final d = Deadline();
      d.set(DateTime.now().add(const Duration(milliseconds: 15)));
      await d.done.timeout(const Duration(milliseconds: 100));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('set() - dispara done() apenas após o prazo definido expirar '
        '(porta TestDeadline/Deadline)', () async {
      final d = Deadline();
      d.set(DateTime.now().add(const Duration(milliseconds: 30)));

      var firedEarly = false;
      d.done.then((_) => firedEarly = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(firedEarly, isFalse, reason: 'done completou cedo demais');

      await d.done.timeout(const Duration(milliseconds: 100));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('set() - adiar o prazo posterga o disparo de done() '
        '(porta TestDeadline/DeadlineExtend)', () async {
      final d = Deadline();
      final start = DateTime.now();
      d.set(start.add(const Duration(milliseconds: 20)));
      d.set(start.add(const Duration(milliseconds: 60)));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(d.err, isNull, reason: 'não deveria ter expirado ainda');

      await d.done.timeout(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(55));
    });

    test('set() - antecipar o prazo faz done() disparar mais cedo '
        '(porta TestDeadline/DeadlinePretend)', () async {
      final d = Deadline();
      final start = DateTime.now();
      d.set(start.add(const Duration(milliseconds: 60)));
      d.set(start.add(const Duration(milliseconds: 15)));

      await d.done.timeout(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, lessThan(50));
    });

    test('set(null) - cancela o prazo e done() nunca dispara '
        '(porta TestDeadline/DeadlineCancel)', () async {
      final d = Deadline();
      d.set(DateTime.now().add(const Duration(milliseconds: 20)));
      d.set(null);
      expect(d.deadline, isNull);

      var fired = false;
      d.done.then((_) => fired = true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fired, isFalse);
    });

    test('err - retorna null antes do prazo, exceção após '
        '(porta TestContext/Cancel)', () async {
      final d = Deadline();
      expect(d.err, isNull);
      d.set(DateTime.fromMillisecondsSinceEpoch(1)); // já no passado
      await d.done.timeout(const Duration(milliseconds: 50));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('deadline - reflete o valor definido e não apenas se expirou '
        '(porta TestContext/Deadline)', () {
      final d = Deadline();
      expect(d.deadline, isNull);

      final dl = DateTime.fromMillisecondsSinceEpoch(12345000);
      d.set(dl);
      expect(d.deadline, equals(dl));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('value() - sempre retorna null', () {
      final d = Deadline();
      expect(d.value('qualquer-chave'), isNull);
      d.set(DateTime.now().add(const Duration(milliseconds: 5)));
      expect(d.value(null), isNull);
    });
  });

  group('DeadlineExceededException [Atomic Audit]', () {
    test('toString() - identifica a exceção de prazo excedido', () {
      expect(
        DeadlineExceededException().toString(),
        contains('deadline exceeded'),
      );
    });
  });

  // Two comments shared by several tests below:
  //
  // (1) The UDP receive tests below exercise a full request/reply round
  //     trip: the client writes, the peer replies to the ephemeral source
  //     port, and the client reads the reply. That is the pattern
  //     `pion/stun` actually depends on (a Binding request followed by the
  //     Binding response), so it is the pattern worth asserting.
  // (2) `Net` (net.dart) and `StdNet` (stdnet.dart) both declare `dial`/
  //     `dialUdp`; the AST auditor's Rule 24 tracks them as distinct
  //     symbols (interface declaration vs. concrete override), so each
  //     gets its own group/tests below -- the `Net [Atomic Audit]` group
  //     exercises them through the interface type to prove `StdNet`
  //     actually satisfies the contract, on top of the fuller coverage in
  //     `StdNet [Atomic Audit]`.

  group('StdNet [Atomic Audit]', () {
    test('StdNet() - constrói sem enumerar interfaces de rede (porta NewNet, '
        'sem UpdateInterfaces, ver doc-comment de stdnet.dart)', () {
      expect(StdNet(), isNotNull);
    });

    test('dial() - conecta via TCP e troca bytes com um servidor loopback '
        '(porta Net.Dial, pion-stun/client.go:64,74,100)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) {
        client.listen(client.add); // echo
      });

      final conn = await StdNet().dial('tcp', '127.0.0.1:${server.port}');
      final written = await conn.write(Uint8List.fromList([1, 2, 3]));
      expect(written, equals(3));

      final buf = Uint8List(3);
      final read = await conn.read(buf).timeout(const Duration(seconds: 5));
      expect(read, equals(3));
      expect(buf, equals([1, 2, 3]));

      await conn.close();
      await server.close();
    });

    test(
      'dial() - conecta via UDP em modo "connected" e troca datagramas '
      'com um peer loopback (porta Net.Dial, pion-stun/client.go:64)',
      () async {
        final peer = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        peer.listen((event) {
          if (event != RawSocketEvent.read) return;
          final datagram = peer.receive();
          if (datagram == null) return;
          // Responde à porta efêmera de origem, como faz um servidor STUN.
          peer.send([7, 7, 7], datagram.address, datagram.port);
        });

        final conn = await StdNet().dial('udp', '127.0.0.1:${peer.port}');
        final written = await conn.write(Uint8List.fromList([9, 9]));
        expect(written, equals(2));

        final buffer = Uint8List(3);
        final read = await conn
            .read(buffer)
            .timeout(const Duration(seconds: 5));
        expect(read, equals(3));
        expect(buffer, equals([7, 7, 7]));

        await conn.close();
        peer.close();
      },
    );

    test('dialUdp() - vincula localmente e troca datagramas via '
        'readFrom()/writeTo() com um peer loopback (porta Net.DialUDP, '
        'pion-stun/client.go:87)', () async {
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      peer.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = peer.receive();
        if (datagram == null) return;
        // Responde à porta efêmera de origem, como faz um servidor STUN.
        peer.send([6, 6], datagram.address, datagram.port);
      });
      final remote = UdpAddr(InternetAddress.loopbackIPv4, peer.port);

      final conn = await StdNet().dialUdp('udp', null, remote);
      final writeN = await conn.writeTo(Uint8List.fromList([5]), remote);
      expect(writeN, equals(1));

      final buffer = Uint8List(2);
      final (readN, from) = await conn
          .readFrom(buffer)
          .timeout(const Duration(seconds: 5));
      expect(readN, equals(2));
      expect(buffer, equals([6, 6]));
      expect((from as UdpAddr).port, equals(peer.port));

      await conn.close();
      peer.close();
    });
  });

  group('Net [Atomic Audit]', () {
    test('dial() - via a interface Net, StdNet troca bytes TCP com um '
        'servidor loopback (porta net.go:127)', () async {
      final Net net = StdNet();
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) => client.listen(client.add));

      final conn = await net.dial('tcp', '127.0.0.1:${server.port}');
      final written = await conn.write(Uint8List.fromList([4]));
      expect(written, equals(1));
      final buf = Uint8List(1);
      final read = await conn.read(buf).timeout(const Duration(seconds: 5));
      expect(read, equals(1));
      expect(buf[0], equals(4));

      await conn.close();
      await server.close();
    });

    test('dialUdp() - via a interface Net, StdNet envia um datagrama a um '
        'peer loopback (porta net.go:136)', () async {
      final Net net = StdNet();
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final remote = UdpAddr(InternetAddress.loopbackIPv4, peer.port);

      final conn = await net.dialUdp('udp', null, remote);
      final writeN = await conn.writeTo(Uint8List.fromList([6]), remote);
      expect(writeN, equals(1));

      final fromClient = await _receiveOne(peer);
      expect(fromClient.data, equals([6]));

      await conn.close();
      peer.close();
    });
  });

  group('NetConn [Atomic Audit]', () {
    // Regressão: `close()` precisa liberar uma leitura já bloqueada. O
    // `cancel()` da fila interna cancelava a inscrição ANTES de marcar o
    // fim, e depois disso o `onDone` do stream não dispara mais -- o
    // `Completer` estacionado pelo leitor nunca completava e o `read()`
    // ficava pendurado para sempre. No Go, fechar uma `net.Conn` desbloqueia
    // um `Read` concorrente ("use of closed network connection").
    test('close() - libera um read() UDP que já estava bloqueado', () async {
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final conn = await StdNet().dial('udp', '127.0.0.1:${peer.port}');

      var settled = false;
      // Nada será enviado: só o close() pode encerrar esta leitura.
      unawaited(
        conn
            .read(Uint8List(16))
            .then<void>(
              (_) => settled = true,
              onError: (Object _) => settled = true,
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(settled, isFalse, reason: 'a leitura deve estar bloqueada');

      await conn.close();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(settled, isTrue, reason: 'read() ficou pendurado após close()');

      peer.close();
    });

    test('close() - libera um read() TCP que já estava bloqueado', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((_) {}); // aceita e nunca envia nada
      final conn = await StdNet().dial('tcp', '127.0.0.1:${server.port}');

      var settled = false;
      unawaited(
        conn
            .read(Uint8List(16))
            .then<void>(
              (_) => settled = true,
              onError: (Object _) => settled = true,
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(settled, isFalse, reason: 'a leitura deve estar bloqueada');

      await conn.close();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(settled, isTrue, reason: 'read() ficou pendurado após close()');

      await server.close();
    });

    test('read() - lê os bytes escritos por um peer TCP loopback (porta '
        'io.Reader.Read)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) => client.add([8, 8]));

      final conn = await StdNet().dial('tcp', '127.0.0.1:${server.port}');
      final buf = Uint8List(2);
      final read = await conn.read(buf).timeout(const Duration(seconds: 5));
      expect(read, equals(2));
      expect(buf, equals([8, 8]));

      await conn.close();
      await server.close();
    });

    test('read() - retorna 0 (fim de stream) após o peer fechar a conexão '
        '(porta NetConn.Close via io.Closer)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) => client.close());

      final conn = await StdNet().dial('tcp', '127.0.0.1:${server.port}');
      final buf = Uint8List(1);
      final read = await conn.read(buf).timeout(const Duration(seconds: 5));
      expect(read, equals(0));

      await conn.close();
      await server.close();
    });

    test('write() - escreve bytes que um servidor loopback recebe (porta '
        'io.Writer.Write)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<Uint8List>();
      server.listen((client) {
        client.listen((data) {
          if (!received.isCompleted) received.complete(data);
        });
      });

      final conn = await StdNet().dial('tcp', '127.0.0.1:${server.port}');
      final written = await conn.write(Uint8List.fromList([1, 2, 3]));
      expect(written, equals(3));
      expect(
        await received.future.timeout(const Duration(seconds: 5)),
        equals([1, 2, 3]),
      );

      await conn.close();
      await server.close();
    });

    test(
      'close() - encerra a conexão TCP sem lançar (porta io Closer)',
      () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((client) {});

        final conn = await StdNet().dial('tcp', '127.0.0.1:${server.port}');
        await expectLater(conn.close(), completes);
        await server.close();
      },
    );
  });

  group('UdpConn [Atomic Audit]', () {
    test('writeTo() - envia um datagrama que um peer loopback recebe '
        '(porta UDPConn.WriteTo, net.go)', () async {
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final remote = UdpAddr(InternetAddress.loopbackIPv4, peer.port);

      final conn = await StdNet().dialUdp('udp', null, remote);
      final writeN = await conn.writeTo(Uint8List.fromList([5]), remote);
      expect(writeN, equals(1));

      final fromClient = await _receiveOne(peer);
      expect(fromClient.data, equals([5]));

      await conn.close();
      peer.close();
    });

    test('readFrom() - recebe um datagrama de um peer que não é o remoto '
        'discado, devolvendo o endereço de origem real (porta '
        'UDPConn.ReadFrom, net.go)', () async {
      final dummyRemote = UdpAddr(InternetAddress.loopbackIPv4, 1);
      final conn = await StdNet().dialUdp('udp', null, dummyRemote);
      final localPort = (conn.localAddr as UdpAddr).port;

      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final sent = peer.send(
        Uint8List.fromList([7]),
        InternetAddress.loopbackIPv4,
        localPort,
      );
      expect(sent, equals(1));

      final buf = Uint8List(1);
      final (readN, fromAddr) = await conn
          .readFrom(buf)
          .timeout(const Duration(seconds: 5));
      expect(readN, equals(1));
      expect(buf[0], equals(7));
      expect((fromAddr as UdpAddr).port, equals(peer.port));

      await conn.close();
      peer.close();
    });

    test('localAddr() - reflete o endereço/porta local efetivamente '
        'vinculados (porta UDPConn.LocalAddr, net.go)', () async {
      final localAddr = UdpAddr(InternetAddress.loopbackIPv4, 0);
      final remote = UdpAddr(InternetAddress.loopbackIPv4, 1);
      final conn = await StdNet().dialUdp('udp', localAddr, remote);
      final local = conn.localAddr as UdpAddr;
      expect(local.address, equals(InternetAddress.loopbackIPv4));
      expect(local.port, greaterThan(0));
      await conn.close();
    });

    test('remoteAddr() - reflete o destino passado a dialUdp() (porta '
        'UDPConn.RemoteAddr, net.go; pion-stun/client.go:96)', () async {
      final remote = UdpAddr(InternetAddress.loopbackIPv4, 12345);
      final conn = await StdNet().dialUdp('udp', null, remote);
      expect(conn.remoteAddr, equals(remote));
      await conn.close();
    });

    test('close() - encerra a conexão UDP sem lançar (porta UDPConn Close, '
        'net go)', () async {
      final remote = UdpAddr(InternetAddress.loopbackIPv4, 1);
      final conn = await StdNet().dialUdp('udp', null, remote);
      await expectLater(conn.close(), completes);
    });
  });

  group('PacketConn [Atomic Audit]', () {
    test(
      'readFromContext() - retorna o resultado quando a leitura conclui '
      'antes do cancelamento (porta ReadFromContext, packetconn.go:61)',
      () async {
        final fake = _FakeUdpConn();
        final pc = PacketConn(fake);
        final future = pc.readFromContext(
          Completer<void>().future,
          Uint8List(4),
        );
        fake.readCompleter.complete((3, fake.remoteAddr));
        final (n, addr) = await future;
        expect(n, equals(3));
        expect(addr, equals(fake.remoteAddr));
      },
    );

    test('readFromContext() - lança DeadlineExceededException quando o '
        'cancelamento dispara antes da leitura concluir', () async {
      final fake = _FakeUdpConn();
      final pc = PacketConn(fake);
      final cancel = Completer<void>();
      final future = pc.readFromContext(cancel.future, Uint8List(4));
      cancel.complete();
      await expectLater(future, throwsA(isA<DeadlineExceededException>()));
    });

    test('writeToContext() - retorna a contagem de bytes quando a escrita '
        'conclui antes do cancelamento (porta WriteToContext, '
        'packetconn.go:111)', () async {
      final fake = _FakeUdpConn();
      final pc = PacketConn(fake);
      final future = pc.writeToContext(
        Completer<void>().future,
        Uint8List(2),
        fake.remoteAddr,
      );
      fake.writeCompleter.complete(2);
      expect(await future, equals(2));
    });

    test('writeToContext() - lança DeadlineExceededException quando o '
        'cancelamento dispara antes da escrita concluir', () async {
      final fake = _FakeUdpConn();
      final pc = PacketConn(fake);
      final cancel = Completer<void>();
      final future = pc.writeToContext(
        cancel.future,
        Uint8List(2),
        fake.remoteAddr,
      );
      cancel.complete();
      await expectLater(future, throwsA(isA<DeadlineExceededException>()));
    });

    test('close() - delega para a conexão subjacente e bloqueia leituras/'
        'escritas seguintes (porta Close, packetconn.go:160)', () async {
      final fake = _FakeUdpConn();
      final pc = PacketConn(fake);
      await pc.close();
      expect(fake.closeCalled, isTrue);
      expect(
        () => pc.readFromContext(Completer<void>().future, Uint8List(1)),
        throwsA(isA<ClosingException>()),
      );
      expect(
        () => pc.writeToContext(
          Completer<void>().future,
          Uint8List(1),
          fake.remoteAddr,
        ),
        throwsA(isA<ClosingException>()),
      );
    });

    test('localAddr() - delega para a conexão subjacente (porta LocalAddr, '
        'packetconn.go:174)', () {
      final fake = _FakeUdpConn();
      final pc = PacketConn(fake);
      expect(pc.localAddr, equals(fake.localAddr));
    });
  });
}
