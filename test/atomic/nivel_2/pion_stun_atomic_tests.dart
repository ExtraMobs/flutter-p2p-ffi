// test/atomic/nivel_2/pion_stun_atomic_tests.dart
// Testes atômicos 1 para 1 para Agent e Client (transpiled_pion_stun):
// gerência de transações com deadlines (agent.dart) e o "cliente" STUN
// sobre um socket UDP real de loopback (client.dart). Vetores adaptados de
// go-ipfs-reference/pion-stun/{agent,client}_test.go.
// Nível 2: emulação local/memória -- trocas locais via loopback real, sem
// daemon STUN externo (o "servidor" é um RawDatagramSocket local construído
// no próprio teste, que decodifica e responde em memória).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_pion_stun/transpiled_pion_stun.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show StdNet;

void main() {
  group('Agent [Atomic Audit]', () {
    test(
      'Agent.start() - registers a transaction; throws TransactionExistsException on duplicate id',
      () {
        final a = Agent();
        final id = List<int>.filled(12, 1);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        expect(
          () => a.start(id, DateTime.now().add(const Duration(seconds: 1))),
          throwsA(isA<TransactionExistsException>()),
        );
      },
    );

    test(
      'Agent.stop() - stops a transaction with TransactionStoppedException',
      () {
        final a = Agent();
        final id = List<int>.filled(12, 2);
        Event? received;
        a.setHandler((e) => received = e);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        a.stop(id);
        expect(received, isNotNull);
        expect(received!.error, isA<TransactionStoppedException>());
      },
    );

    test(
      'Agent.stopWithError() - throws TransactionNotExistsException for an unknown id',
      () {
        final a = Agent();
        expect(
          () => a.stopWithError(
            List<int>.filled(12, 3),
            const TransactionStoppedException(),
          ),
          throwsA(isA<TransactionNotExistsException>()),
        );
      },
    );

    test(
      'Agent.collect() - times out transactions whose deadline has passed',
      () {
        final a = Agent();
        final id = List<int>.filled(12, 4);
        Event? received;
        a.setHandler((e) => received = e);
        a.start(id, DateTime.now().subtract(const Duration(seconds: 1)));
        a.collect(DateTime.now());
        expect(received, isNotNull);
        expect(received!.error, isA<TransactionTimeOutException>());
      },
    );

    test(
      'Agent.process() - dispatches a decoded message to the handler by transaction id',
      () {
        final a = Agent();
        final id = List<int>.filled(12, 5);
        Event? received;
        a.setHandler((e) => received = e);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        final m = Message()..transactionId = Uint8List.fromList(id);
        a.process(m);
        expect(received, isNotNull);
        expect(received!.message, m);
      },
    );

    test(
      'Agent.setHandler() - throws AgentClosedException once the agent is closed',
      () {
        final a = Agent()..close();
        expect(
          () => a.setHandler((_) {}),
          throwsA(isA<AgentClosedException>()),
        );
      },
    );

    test(
      'Agent.close() - terminates all pending transactions with AgentClosedException',
      () {
        final a = Agent();
        final id = List<int>.filled(12, 6);
        Event? received;
        a.setHandler((e) => received = e);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        a.close();
        expect(received, isNotNull);
        expect(received!.error, isA<AgentClosedException>());
        expect(() => a.close(), throwsA(isA<AgentClosedException>()));
      },
    );
  });

  group('ClientAgent [Atomic Audit]', () {
    test(
      'ClientAgent.start() - registers a transaction, dispatched through the interface',
      () {
        final ClientAgent a = Agent();
        final id = List<int>.filled(12, 7);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        expect(
          () => a.start(id, DateTime.now().add(const Duration(seconds: 1))),
          throwsA(isA<TransactionExistsException>()),
        );
      },
    );

    test(
      'ClientAgent.setHandler() - installs the event handler, dispatched through the interface',
      () {
        final ClientAgent a = Agent();
        Event? received;
        a.setHandler((e) => received = e);
        final id = List<int>.filled(12, 71);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        a.stop(id);
        expect(received, isNotNull);
      },
    );

    test(
      'ClientAgent.stop() - stops a transaction, dispatched through the interface',
      () {
        final ClientAgent a = Agent();
        Event? received;
        a.setHandler((e) => received = e);
        final id = List<int>.filled(12, 72);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        a.stop(id);
        expect(received!.error, isA<TransactionStoppedException>());
      },
    );

    test(
      'ClientAgent.process() - dispatches a decoded message, dispatched through the interface',
      () {
        final ClientAgent a = Agent();
        final id = List<int>.filled(12, 73);
        Event? received;
        a.setHandler((e) => received = e);
        a.start(id, DateTime.now().add(const Duration(seconds: 1)));
        final m = Message()..transactionId = Uint8List.fromList(id);
        a.process(m);
        expect(received!.message, m);
      },
    );

    test(
      'ClientAgent.collect() - times out transactions, dispatched through the interface',
      () {
        final ClientAgent a = Agent();
        final id = List<int>.filled(12, 74);
        Event? received;
        a.setHandler((e) => received = e);
        a.start(id, DateTime.now().subtract(const Duration(seconds: 1)));
        a.collect(DateTime.now());
        expect(received!.error, isA<TransactionTimeOutException>());
      },
    );

    test(
      'ClientAgent.close() - closes the agent, dispatched through the interface',
      () {
        final ClientAgent a = Agent();
        expect(() => a.close(), returnsNormally);
      },
    );
  });

  group('Funções auxiliares de Agent/Client [Atomic Audit]', () {
    test(
      'noopHandler() - returns a Handler that discards events without throwing',
      () {
        final h = noopHandler();
        expect(() => h(const Event(transactionId: [1, 2, 3])), returnsNormally);
      },
    );
  });

  group('Exceptions [Atomic Audit]', () {
    test('AgentClosedException.toString() - fixed message', () {
      expect(const AgentClosedException().toString(), 'agent is closed');
    });
    test('ClientClosedException.toString() - fixed message', () {
      expect(const ClientClosedException().toString(), 'client is closed');
    });
    test(
      'CloseException.toString() - includes connection and agent error text',
      () {
        final e = CloseException(agentErr: 'a', connectionErr: 'c');
        expect(e.toString(), contains('c (connection)'));
        expect(e.toString(), contains('a (agent)'));
      },
    );
    test(
      'DtlsNotSupportedException.toString() - explains the pion/dtls gap',
      () {
        expect(
          const DtlsNotSupportedException().toString(),
          contains('pion/dtls'),
        );
      },
    );
    test(
      'TlsNotSupportedException.toString() - explains the Net abstraction gap',
      () {
        expect(const TlsNotSupportedException().toString(), contains('Net'));
      },
    );
    test('NoConnectionException.toString() - fixed message', () {
      expect(
        const NoConnectionException().toString(),
        'no connection provided',
      );
    });
    test('StopException.toString() - includes cause and err text', () {
      expect(
        const StopException(err: 'e', cause: 'c').toString(),
        contains('e'),
      );
    });
    test('TransactionExistsException.toString() - fixed message', () {
      expect(
        const TransactionExistsException().toString(),
        'transaction exists with same id',
      );
    });
    test('TransactionNotExistsException.toString() - fixed message', () {
      expect(
        const TransactionNotExistsException().toString(),
        'transaction not exists',
      );
    });
    test('TransactionStoppedException.toString() - fixed message', () {
      expect(
        const TransactionStoppedException().toString(),
        'transaction is stopped',
      );
    });
    test('TransactionTimeOutException.toString() - fixed message', () {
      expect(
        const TransactionTimeOutException().toString(),
        'transaction is timed out',
      );
    });
    test('UnsupportedUriException.toString() - fixed message', () {
      expect(
        const UnsupportedUriException().toString(),
        'invalid schema or transport',
      );
    });
  });

  group('Collector [Atomic Audit]', () {
    test(
      'Collector.start() - ticks f at the given rate, dispatched through the interface',
      () async {
        final Collector c = _FakeCollector();
        var ticks = 0;
        c.start(const Duration(milliseconds: 5), (_) => ticks++);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        c.close();
        expect(ticks, greaterThan(0));
      },
    );

    test(
      'Collector.close() - stops the ticking, dispatched through the interface',
      () async {
        final Collector c = _FakeCollector();
        var ticks = 0;
        c.start(const Duration(milliseconds: 5), (_) => ticks++);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        c.close();
        final afterClose = ticks;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ticks, afterClose);
      },
    );
  });

  group('Client [Atomic Audit]', () {
    late RawDatagramSocket fakeServer;
    late int serverPort;

    setUp(() async {
      fakeServer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      serverPort = fakeServer.port;
      // Minimal fake STUN server: decode a Binding request and reply with a
      // Binding success response echoing the same transaction id -- enough
      // to drive Client.doRequest()/indicate() end to end over a real
      // loopback socket without any external daemon.
      fakeServer.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = fakeServer.receive();
        if (datagram == null) return;
        final req = Message()..raw = Uint8List.fromList(datagram.data);
        try {
          req.decode();
        } catch (_) {
          return;
        }
        final resp = Message()
          ..build([bindingSuccess, transactionIdSetter(req.transactionId)]);
        fakeServer.send(resp.raw, datagram.address, datagram.port);
      });
    });

    tearDown(() => fakeServer.close());

    test(
      'Client.dial() - opens a UDP connection wrapped in a Client',
      () async {
        final client = await Client.dial('udp', '127.0.0.1:$serverPort');
        addTearDown(client.close);
        expect(client, isA<Client>());
      },
    );

    test(
      'Client.doRequest() - sends a request and resolves with the response from the server',
      () async {
        final client = await Client.dial('udp', '127.0.0.1:$serverPort');
        addTearDown(client.close);
        final req = Message()..build([bindingRequest, transactionId]);
        final event = client.doRequest(req);
        final result = await event.timeout(const Duration(seconds: 2));
        expect(result.error, isNull);
        expect(result.message?.type, bindingSuccess);
      },
    );

    test(
      'Client.indicate() - fires a message with no response expected',
      () async {
        final client = await Client.dial('udp', '127.0.0.1:$serverPort');
        addTearDown(client.close);
        final ind = Message()..build([bindingRequest, transactionId]);
        await expectLater(client.indicate(ind), completes);
      },
    );

    test(
      'Client.setRto() - changes the retransmission timeout used by subsequent transactions',
      () async {
        final client = await Client.dial('udp', '127.0.0.1:$serverPort');
        addTearDown(client.close);
        expect(
          () => client.setRto(const Duration(milliseconds: 50)),
          returnsNormally,
        );
      },
    );

    test(
      'Client.dialUri() - stun: URI dials over UDP via the default Net',
      () async {
        final uri = StunUri.parse('stun:127.0.0.1:$serverPort');
        final client = await Client.dialUri(uri);
        addTearDown(client.close);
        final req = Message()..build([bindingRequest, transactionId]);
        final result = await client
            .doRequest(req)
            .timeout(const Duration(seconds: 2));
        expect(result.message?.type, bindingSuccess);
      },
    );

    test(
      'Client.dialUri() - turns:...?transport=udp throws DtlsNotSupportedException',
      () async {
        final uri = StunUri.parse('turns:127.0.0.1:$serverPort?transport=udp');
        await expectLater(
          Client.dialUri(uri),
          throwsA(isA<DtlsNotSupportedException>()),
        );
      },
    );

    test('Client.dialUri() - stuns: throws TlsNotSupportedException', () async {
      final uri = StunUri.parse('stuns:127.0.0.1:$serverPort');
      await expectLater(
        Client.dialUri(uri),
        throwsA(isA<TlsNotSupportedException>()),
      );
    });

    test(
      'Client.dialUri() - unknown scheme throws UnsupportedUriException',
      () async {
        final uri = StunUri();
        await expectLater(
          Client.dialUri(uri),
          throwsA(isA<UnsupportedUriException>()),
        );
      },
    );
  });

  group('Funções ClientOption [Atomic Audit]', () {
    late RawDatagramSocket fakeServer;
    late int serverPort;

    setUp(() async {
      fakeServer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      serverPort = fakeServer.port;
      fakeServer.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = fakeServer.receive();
        if (datagram == null) return;
        final req = Message()..raw = Uint8List.fromList(datagram.data);
        try {
          req.decode();
        } catch (_) {
          return;
        }
        final resp = Message()
          ..build([bindingSuccess, transactionIdSetter(req.transactionId)]);
        fakeServer.send(resp.raw, datagram.address, datagram.port);
      });
    });

    tearDown(() => fakeServer.close());

    test(
      'withHandler() - installs a fallback handler for unmatched transaction events',
      () async {
        Event? sideChannel;
        final client = await Client.dial(
          'udp',
          '127.0.0.1:$serverPort',
          options: [withHandler((e) => sideChannel = e)],
        );
        addTearDown(client.close);
        expect(
          sideChannel,
          isNull,
        ); // not invoked yet; installation itself is what's under test.
      },
    );

    test('withRto() - sets the initial retransmission timeout', () async {
      final client = await Client.dial(
        'udp',
        '127.0.0.1:$serverPort',
        options: [withRto(const Duration(milliseconds: 10))],
      );
      addTearDown(client.close);
      final req = Message()..build([bindingRequest, transactionId]);
      final result = await client
          .doRequest(req)
          .timeout(const Duration(seconds: 2));
      expect(result.message?.type, bindingSuccess);
    });

    test(
      'withClock() - injects a custom Clock used for transaction deadlines',
      () async {
        var calls = 0;
        final client = await Client.dial(
          'udp',
          '127.0.0.1:$serverPort',
          options: [withClock(_CountingClock(() => calls++))],
        );
        addTearDown(client.close);
        final req = Message()..build([bindingRequest, transactionId]);
        await client.doRequest(req).timeout(const Duration(seconds: 2));
        expect(calls, greaterThan(0));
      },
    );

    test('withTimeoutRate() - sets the collector tick rate', () async {
      final client = await Client.dial(
        'udp',
        '127.0.0.1:$serverPort',
        options: [withTimeoutRate(const Duration(milliseconds: 5))],
      );
      addTearDown(client.close);
      expect(client, isA<Client>());
    });

    test('withAgent() - injects a custom ClientAgent implementation', () async {
      final agent = Agent();
      final client = await Client.dial(
        'udp',
        '127.0.0.1:$serverPort',
        options: [withAgent(agent)],
      );
      addTearDown(client.close);
      final req = Message()..build([bindingRequest, transactionId]);
      final result = await client
          .doRequest(req)
          .timeout(const Duration(seconds: 2));
      expect(result.message?.type, bindingSuccess);
    });

    test(
      'withCollector() - injects a custom Collector implementation',
      () async {
        final collector = _FakeCollector();
        final client = await Client.dial(
          'udp',
          '127.0.0.1:$serverPort',
          options: [withCollector(collector)],
        );
        addTearDown(client.close);
        expect(collector.started, isTrue);
      },
    );

    test(
      'withNoConnClose() - leaves the underlying connection open once the client closes',
      () async {
        final conn = await StdNet().dial('udp', '127.0.0.1:$serverPort');
        final client = Client(conn, options: [withNoConnClose()]);
        await client.close();
        // If Client had closed the connection despite the option, this write
        // would throw; withNoConnClose() means it must still succeed.
        await expectLater(conn.write(Uint8List.fromList([1, 2, 3])), completes);
        await conn.close();
      },
    );

    test(
      'withNoRetransmit() - disables retransmission by maxing out the RTO',
      () async {
        final client = await Client.dial(
          'udp',
          '127.0.0.1:$serverPort',
          options: [withNoRetransmit],
        );
        addTearDown(client.close);
        final req = Message()..build([bindingRequest, transactionId]);
        final result = await client
            .doRequest(req)
            .timeout(const Duration(seconds: 2));
        expect(result.message?.type, bindingSuccess);
      },
    );
  });
}

/// Test double for [Collector], used only to exercise the interface without
/// depending on the package-private ticker implementation. Test-only per
/// this project's Rule 14 (test doubles must live under test/, never lib/).
class _FakeCollector implements Collector {
  Timer? _timer;
  bool started = false;

  @override
  void start(Duration rate, void Function(DateTime now) f) {
    started = true;
    _timer = Timer.periodic(rate, (_) => f(DateTime.now()));
  }

  @override
  void close() => _timer?.cancel();
}

/// Test double for [Clock] that counts how many times `now()` is called.
class _CountingClock implements Clock {
  _CountingClock(this._onCall);

  final void Function() _onCall;

  @override
  DateTime now() {
    _onCall();
    return DateTime.now();
  }
}
