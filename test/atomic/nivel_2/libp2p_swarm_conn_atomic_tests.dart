// test/atomic/nivel_2/libp2p_swarm_conn_atomic_tests.dart
//
// Testes atômicos 1 para 1 para a camada de conexão de nível swarm:
// `MuxedStream` e `Conn` (core/network/network.dart), `SwarmConn` e as adições
// ao `Swarm` (p2p/net/swarm/), e o `closeWithError` que passou a fazer parte do
// contrato de `CapableConn`.
//
// Nível 2: tudo roda sobre um par de sessões Yamux ligadas por um pipe em
// memória, sem socket nem daemon. Os streams exercitados aqui são os mesmos que
// o `BasicUpgrader` produz em produção, não dublês.

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';
import 'package:transpiled_libp2p/src/p2p/net/interface_addrs.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// Um `YamuxTransport` em memória que entrega tudo o que escreve ao seu par.
class _Link implements YamuxTransport {
  _Link._(this._input);
  final StreamController<List<int>> _input;
  late final _Link _peer;
  bool _closed = false;

  static (_Link, _Link) pair() {
    late _Link a;
    late _Link b;
    a = _Link._(StreamController<List<int>>.broadcast());
    b = _Link._(StreamController<List<int>>.broadcast());
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  @override
  Stream<List<int>> get input => _input.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (!_closed) _peer._input.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _input.close();
  }
}

/// Transporte mínimo que devolve sempre a mesma conexão já construída, para
/// que o `Swarm` possa registrá-la por um `dialPeer` real.
class _PairTransport implements Transport {
  _PairTransport(this.addr, [this._conn]);
  final Multiaddr addr;
  CapableConn? _conn;

  set conn(CapableConn value) => _conn = value;

  @override
  bool canDial(Multiaddr a) => a.toString() == addr.toString();

  @override
  Future<CapableConn> dial(Multiaddr a, PeerId peer) async => _conn!;

  @override
  Future<Listener> listen(Multiaddr a) async =>
      throw UnsupportedError('listen not used in these tests');

  @override
  List<int> protocols() => const [4, 6];

  @override
  bool proxy() => false;
}

/// Listener falso que nunca aceita uma conexão e sempre devolve o mesmo
/// endereço vinculado, para exercitar `Swarm.listen` sem socket real.
class _FakeUnspecifiedListener implements Listener {
  _FakeUnspecifiedListener(this._addr);
  final Multiaddr _addr;

  @override
  Future<CapableConn> accept() => Completer<CapableConn>().future;

  @override
  Future<void> close() async {}

  @override
  Multiaddr multiaddr() => _addr;
}

/// Transporte que só sabe escutar (não discar), devolvendo sempre o mesmo
/// endereço vinculado -- o suficiente para popular `Swarm._listeners`.
class _ListenOnlyTransport implements Transport {
  _ListenOnlyTransport(this._boundAddr);
  final Multiaddr _boundAddr;

  @override
  bool canDial(Multiaddr a) => a.toString() == _boundAddr.toString();

  @override
  Future<CapableConn> dial(Multiaddr a, PeerId peer) =>
      throw UnsupportedError('dial not used in these tests');

  @override
  Future<Listener> listen(Multiaddr a) async =>
      _FakeUnspecifiedListener(_boundAddr);

  @override
  List<int> protocols() => const [6];

  @override
  bool proxy() => false;
}

void main() async {
  final localIdentity = await generateEd25519KeyPair();
  final localPeer = PeerId.fromPubKey(localIdentity.getPublic());
  final remoteIdentity = await generateEd25519KeyPair();
  final remotePeer = PeerId.fromPubKey(remoteIdentity.getPublic());

  final localAddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
  final remoteAddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');

  /// Constrói um par de `UpgradedCapableConn` sobre um pipe Yamux em memória.
  /// `a` é o lado cliente (abre streams) e `b` o lado servidor (aceita).
  (UpgradedCapableConn, UpgradedCapableConn) connPair() {
    final (linkA, linkB) = _Link.pair();
    final sessionA = YamuxSession(linkA, isClient: true);
    final sessionB = YamuxSession(linkB, isClient: false);
    final transport = _PairTransport(remoteAddr);

    final a = UpgradedCapableConn(
      transport: transport,
      localPeer: localPeer,
      remotePeer: remotePeer,
      remotePublicKey: remoteIdentity.getPublic(),
      localMultiaddr: localAddr,
      remoteMultiaddr: remoteAddr,
      direction: Direction.outbound,
      session: sessionA,
      bridge: linkA,
    );
    final b = UpgradedCapableConn(
      transport: transport,
      localPeer: remotePeer,
      remotePeer: localPeer,
      remotePublicKey: localIdentity.getPublic(),
      localMultiaddr: remoteAddr,
      remoteMultiaddr: localAddr,
      direction: Direction.inbound,
      session: sessionB,
      bridge: linkB,
    );
    return (a, b);
  }

  /// Um `SwarmConn` sobre o lado cliente do par, mais o lado servidor cru e o
  /// swarm dono, para os testes que precisam dos três.
  (SwarmConn, UpgradedCapableConn, Swarm) swarmConnPair() {
    final (a, b) = connPair();
    final swarm = Swarm(localPeer: localPeer);
    return (SwarmConn(conn: a, swarm: swarm, id: 1), b, swarm);
  }

  group('MuxedStream [Atomic Audit]', () {
    test('write() - entrega os bytes ao stream aceito do outro lado', () async {
      final (a, b) = connPair();
      final acceptFuture = b.acceptStream();
      final out = await a.openStream();
      final incoming = await acceptFuture;

      await out.write(Uint8List.fromList([1, 2, 3, 4]));
      expect(await incoming.read(4), equals(Uint8List.fromList([1, 2, 3, 4])));

      await a.close();
      await b.close();
    });

    test('read() - respeita o comprimento máximo pedido', () async {
      final (a, b) = connPair();
      final acceptFuture = b.acceptStream();
      final out = await a.openStream();
      final incoming = await acceptFuture;

      await out.write(Uint8List.fromList([9, 8, 7, 6, 5]));
      final first = await incoming.read(2);
      expect(first, hasLength(lessThanOrEqualTo(2)));
      expect(first, isNotEmpty);

      await a.close();
      await b.close();
    });

    test('isClosed - é falso enquanto o stream está vivo', () async {
      final (a, b) = connPair();
      final out = await a.openStream();
      expect(out.isClosed, isFalse);
      await a.close();
      await b.close();
    });

    test('close() - encerra o stream e marca isClosed', () async {
      final (a, b) = connPair();
      final out = await a.openStream();
      await out.close();
      expect(out.isClosed, isTrue);
      await a.close();
      await b.close();
    });

    test('reset() - derruba o stream sem fechar a conexão', () async {
      final (a, b) = connPair();
      final out = await a.openStream();
      await out.reset();
      expect(out.isClosed, isTrue);
      expect(a.isClosed, isFalse);
      await a.close();
      await b.close();
    });

    test('resetWithError() - derruba o stream como um reset simples, já que '
        'o Yamux não carrega código de erro por stream', () async {
      final (a, b) = connPair();
      final out = await a.openStream();
      await out.resetWithError(0x12);
      expect(out.isClosed, isTrue);
      await a.close();
      await b.close();
    });

    test('closeWrite() - fecha só o lado de escrita', () async {
      final (a, b) = connPair();
      final acceptFuture = b.acceptStream();
      final out = await a.openStream();
      final incoming = await acceptFuture;

      await out.write(Uint8List.fromList([42]));
      await out.closeWrite();
      expect(await incoming.read(1), equals(Uint8List.fromList([42])));

      await a.close();
      await b.close();
    });

    test('closeRead() - completa sem derrubar a conexão', () async {
      final (a, b) = connPair();
      final out = await a.openStream();
      await out.closeRead();
      expect(a.isClosed, isFalse);
      await a.close();
      await b.close();
    });

    test('setDeadline() - é inócuo no stream cru: o prazo é aplicado pelo '
        'SwarmStream que o embrulha', () async {
      final (a, b) = connPair();
      final acceptFuture = b.acceptStream();
      final out = await a.openStream();
      final incoming = await acceptFuture;

      await out.setDeadline(DateTime.now().subtract(const Duration(days: 1)));
      await out.write(Uint8List.fromList([7]));
      expect(await incoming.read(1), equals(Uint8List.fromList([7])));

      await a.close();
      await b.close();
    });

    test('setReadDeadline() - idem, não bloqueia a leitura seguinte', () async {
      final (a, b) = connPair();
      final acceptFuture = b.acceptStream();
      final out = await a.openStream();
      final incoming = await acceptFuture;

      await incoming.setReadDeadline(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      await out.write(Uint8List.fromList([5]));
      expect(await incoming.read(1), equals(Uint8List.fromList([5])));

      await a.close();
      await b.close();
    });

    test(
      'setWriteDeadline() - idem, não bloqueia a escrita seguinte',
      () async {
        final (a, b) = connPair();
        final acceptFuture = b.acceptStream();
        final out = await a.openStream();
        final incoming = await acceptFuture;

        await out.setWriteDeadline(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        await out.write(Uint8List.fromList([3]));
        expect(await incoming.read(1), equals(Uint8List.fromList([3])));

        await a.close();
        await b.close();
      },
    );
  });

  group('CapableConn [Atomic Audit]', () {
    test(
      'closeWithError() - fecha a conexão pela interface do transporte',
      () async {
        final (a, b) = connPair();
        final CapableConn capable = a;
        await capable.closeWithError(connGarbageCollected);
        expect(capable.isClosed, isTrue);
        await b.close();
      },
    );
  });

  group('UpgradedCapableConn [Atomic Audit]', () {
    test('closeWithError() - degrada para close(), porque o Yamux não carrega '
        'código de erro de conexão', () async {
      final (a, b) = connPair();
      await a.closeWithError(connGarbageCollected);
      expect(a.isClosed, isTrue);
      await b.close();
    });
  });

  group('ConnClosedException [Atomic Audit]', () {
    test('toString() - descreve a conexão fechada', () {
      expect(
        const ConnClosedException().toString(),
        equals('connection closed'),
      );
    });
  });

  group('SwarmConn [Atomic Audit]', () {
    test('id() - combina os 10 primeiros caracteres do peer remoto com o '
        'ordinal da conexão', () async {
      final (conn, b, _) = swarmConnPair();
      final expectedPrefix = remotePeer.toString().substring(0, 10);
      expect(conn.id(), equals('$expectedPrefix-1'));
      await conn.close();
      await b.close();
    });

    test('newStream() - abre um SwarmStream registrado na conexão', () async {
      final (conn, b, _) = swarmConnPair();
      final acceptFuture = b.acceptStream();
      final stream = await conn.newStream();

      expect(stream, isA<SwarmStream>());
      expect(stream.stat().direction, equals(Direction.outbound));
      expect(conn.getStreams(), contains(stream));
      await acceptFuture;

      await conn.close();
      await b.close();
    });

    test(
      'newStream() - lança ConnClosedException numa conexão já fechada',
      () async {
        final (conn, b, _) = swarmConnPair();
        await conn.close();
        await expectLater(
          conn.newStream(),
          throwsA(isA<ConnClosedException>()),
        );
        await b.close();
      },
    );

    test('adoptInboundStream() - registra um stream de entrada com direção '
        'inbound', () async {
      final (conn, b, _) = swarmConnPair();
      final acceptFuture = conn.capableConn.acceptStream();
      final outbound = await b.openStream();
      final adopted = conn.adoptInboundStream(await acceptFuture);

      expect(adopted.stat().direction, equals(Direction.inbound));
      expect(conn.getStreams(), contains(adopted));

      await outbound.close();
      await conn.close();
      await b.close();
    });

    test('removeStream() - desregistra o stream da conexão', () async {
      final (conn, b, _) = swarmConnPair();
      final acceptFuture = b.acceptStream();
      final stream = await conn.newStream();
      expect(conn.getStreams(), hasLength(1));

      conn.removeStream(stream as SwarmStream);
      expect(conn.getStreams(), isEmpty);
      await acceptFuture;

      await conn.close();
      await b.close();
    });

    test('getStreams() - lista os streams abertos e é imutável', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.getStreams(), isEmpty);

      final acceptFuture = b.acceptStream();
      await conn.newStream();
      await acceptFuture;
      expect(conn.getStreams(), hasLength(1));
      expect(() => conn.getStreams().clear(), throwsA(isA<UnsupportedError>()));

      await conn.close();
      await b.close();
    });

    test(
      'isClosed - falso enquanto viva, verdadeiro depois de close()',
      () async {
        final (conn, b, _) = swarmConnPair();
        expect(conn.isClosed, isFalse);
        await conn.close();
        expect(conn.isClosed, isTrue);
        await b.close();
      },
    );

    test('close() - fecha o transporte, esvazia os streams e desregistra do '
        'swarm', () async {
      final (conn, b, _) = swarmConnPair();
      final acceptFuture = b.acceptStream();
      await conn.newStream();
      await acceptFuture;

      await conn.close();

      expect(conn.isClosed, isTrue);
      expect(conn.getStreams(), isEmpty);
      expect(conn.capableConn.isClosed, isTrue);
      await b.close();
    });

    test('close() - é idempotente', () async {
      final (conn, b, _) = swarmConnPair();
      await conn.close();
      await conn.close();
      expect(conn.isClosed, isTrue);
      await b.close();
    });

    test(
      'closeWithError() - fecha propagando o código ao transporte',
      () async {
        final (conn, b, _) = swarmConnPair();
        await conn.closeWithError(connGarbageCollected);
        expect(conn.isClosed, isTrue);
        expect(conn.capableConn.isClosed, isTrue);
        await b.close();
      },
    );

    test('capableConn - expõe a conexão de transporte embrulhada', () async {
      final (a, b) = connPair();
      final swarm = Swarm(localPeer: localPeer);
      final conn = SwarmConn(conn: a, swarm: swarm, id: 7);
      expect(identical(conn.capableConn, a), isTrue);
      await conn.close();
      await b.close();
    });

    test('localPeer() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.localPeer(), equals(localPeer));
      await conn.close();
      await b.close();
    });

    test('remotePeer() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.remotePeer(), equals(remotePeer));
      await conn.close();
      await b.close();
    });

    test('remotePublicKey() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.remotePublicKey(), equals(remoteIdentity.getPublic()));
      await conn.close();
      await b.close();
    });

    test('connState() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.connState().streamMultiplexer, equals(goYamuxProtocolId));
      await conn.close();
      await b.close();
    });

    test('localMultiaddr() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.localMultiaddr(), equals(localAddr));
      await conn.close();
      await b.close();
    });

    test('remoteMultiaddr() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.remoteMultiaddr(), equals(remoteAddr));
      await conn.close();
      await b.close();
    });

    test('scope() - delega ao transporte', () async {
      final (conn, b, _) = swarmConnPair();
      expect(conn.scope(), isA<ConnScope>());
      await conn.close();
      await b.close();
    });

    test(
      'stat() - reporta numStreams a partir do conjunto registrado',
      () async {
        final (conn, b, _) = swarmConnPair();
        expect(conn.stat().numStreams, equals(0));
        expect(conn.stat().direction, equals(Direction.outbound));

        final acceptFuture = b.acceptStream();
        await conn.newStream();
        await acceptFuture;
        expect(conn.stat().numStreams, equals(1));

        await conn.close();
        await b.close();
      },
    );

    test('toString() - descreve a conexão nos dois sentidos', () async {
      final (conn, b, _) = swarmConnPair();
      final text = conn.toString();
      expect(text, startsWith('<swarm.Conn['));
      expect(text, contains(localAddr.toString()));
      expect(text, contains(remoteAddr.toString()));
      await conn.close();
      await b.close();
    });
  });

  group('Conn [Atomic Audit]', () {
    test('id() - identifica a conexão pela interface', () async {
      final (swarmConn, b, _) = swarmConnPair();
      final Conn conn = swarmConn;
      expect(conn.id(), isNotEmpty);
      expect(conn.id(), contains('-'));
      await conn.close();
      await b.close();
    });

    test('newStream() - abre um stream pela interface', () async {
      final (swarmConn, b, _) = swarmConnPair();
      final Conn conn = swarmConn;
      final acceptFuture = b.acceptStream();
      final stream = await conn.newStream();
      expect(stream, isA<NetworkStream>());
      expect(stream.id, isNotEmpty);
      await acceptFuture;
      await conn.close();
      await b.close();
    });

    test('getStreams() - reflete os streams abertos pela interface', () async {
      final (swarmConn, b, _) = swarmConnPair();
      final Conn conn = swarmConn;
      expect(conn.getStreams(), isEmpty);
      final acceptFuture = b.acceptStream();
      await conn.newStream();
      await acceptFuture;
      expect(conn.getStreams(), hasLength(1));
      await conn.close();
      await b.close();
    });

    test('isClosed - reflete o estado pela interface', () async {
      final (swarmConn, b, _) = swarmConnPair();
      final Conn conn = swarmConn;
      expect(conn.isClosed, isFalse);
      await conn.close();
      expect(conn.isClosed, isTrue);
      await b.close();
    });

    test('close() - fecha pela interface', () async {
      final (swarmConn, b, _) = swarmConnPair();
      final Conn conn = swarmConn;
      await conn.close();
      expect(conn.isClosed, isTrue);
      await b.close();
    });

    test('closeWithError() - fecha com código pela interface', () async {
      final (swarmConn, b, _) = swarmConnPair();
      final Conn conn = swarmConn;
      await conn.closeWithError(connGarbageCollected);
      expect(conn.isClosed, isTrue);
      await b.close();
    });
  });

  group('Swarm [Atomic Audit]', () {
    test('nextStreamId() - devolve ordinais crescentes a partir de 1', () {
      final swarm = Swarm(localPeer: localPeer);
      expect(swarm.nextStreamId(), equals(1));
      expect(swarm.nextStreamId(), equals(2));
      expect(swarm.nextStreamId(), equals(3));
    });

    test('removeConn() - desregistra a conexão do swarm', () async {
      final (a, b) = connPair();
      final transport = _PairTransport(remoteAddr)..conn = a;
      final swarm = Swarm(localPeer: localPeer, transports: [transport]);
      swarm.peerstore.addAddrs(remotePeer, [remoteAddr], tempAddrTtl);

      final conn = await swarm.dialPeer(NetworkContext.empty, remotePeer);
      expect(swarm.connsToPeer(remotePeer), isNotEmpty);

      swarm.removeConn(conn);
      expect(swarm.connsToPeer(remotePeer), isEmpty);

      await b.close();
      await swarm.close();
    });

    test(
      'notifyDisconnected() - despacha Disconnected a cada notifiee',
      () async {
        final (a, b) = connPair();
        final swarm = Swarm(localPeer: localPeer);
        final conn = SwarmConn(conn: a, swarm: swarm, id: 1);

        final seen = <Conn>[];
        swarm.notify(NotifyBundle(disconnectedF: (_, c) => seen.add(c)));

        swarm.notifyDisconnected(conn);
        expect(seen, equals([conn]));

        await conn.close();
        await b.close();
      },
    );

    test(
      'interfaceCache - expõe sempre a mesma instância de InterfaceAddrsCache do swarm',
      () {
        final swarm = Swarm(localPeer: localPeer);
        expect(swarm.interfaceCache, isA<InterfaceAddrsCache>());
        expect(identical(swarm.interfaceCache, swarm.interfaceCache), isTrue);
      },
    );

    test(
      'interfaceListenAddressesSync() - resolve enderecos nao especificados usando o cache que listen() ja atualizou',
      () async {
        final unspecified = Multiaddr.parse('/ip4/0.0.0.0/tcp/4003');
        final swarm = Swarm(
          localPeer: localPeer,
          transports: [_ListenOnlyTransport(unspecified)],
        );
        // Go: `Swarm.Listen` atualiza `interfaceAddrsCache` antes de vincular
        // (swarm.go), o que é o que torna a versão síncrona utilizável logo
        // em seguida sem nova consulta de I/O.
        await swarm.listen([unspecified]);

        final resolved = swarm.interfaceListenAddressesSync();
        expect(resolved, isNotEmpty);
        expect(resolved.any((a) => a.toString().contains('0.0.0.0')), isFalse);
        expect(
          resolved.map((a) => a.toString()),
          contains('/ip4/127.0.0.1/tcp/4003'),
        );

        await swarm.close();
      },
    );
  });
}
