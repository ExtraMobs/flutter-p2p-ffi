import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('Full Transport & Security Matrix Validation (Marco G.7) [Atomic Audit]', () {
    late PrivKey localKey;
    late PeerId localPeer;
    late BasicUpgrader upgrader;
    late TcpTransport tcpTransport;
    late WebsocketTransport wsTransport;
    late QuicTransport quicTransport;
    late WebtransportTransport wtTransport;
    late List<Transport> allTransports;
    late List<SecureTransport> secTransports;
    late Swarm swarm;

    setUp(() async {
      localKey = await generateEd25519KeyPair();
      localPeer = PeerId.fromPubKey(localKey.getPublic());
      final peerstore = MemoryPeerstore();
      peerstore.addPrivKey(localPeer, localKey);
      peerstore.addPubKey(localPeer, localKey.getPublic());

      secTransports = [
        TlsTransport(privKey: localKey),
        NoiseTransport(privKey: localKey),
      ];

      upgrader = BasicUpgrader(
        localIdentityKey: localKey,
        security: secTransports,
      );

      tcpTransport = TcpTransport(upgrader: upgrader);
      wsTransport = WebsocketTransport(upgrader: upgrader);
      quicTransport = QuicTransport(privKey: localKey);
      wtTransport = WebtransportTransport(privKey: localKey);

      allTransports = [
        quicTransport,
        wtTransport,
        wsTransport,
        tcpTransport,
      ];

      swarm = Swarm(
        localPeer: localPeer,
        peerstore: peerstore,
        eventBus: BasicBus(),
        transports: allTransports,
      );
    });

    tearDown(() async {
      await swarm.close();
    });

    test(
      'Kubo swarm address types are claimed by exactly one transport via canDial()',
      () {
        final kuboSwarmAddresses = <String>[
          '/ip4/127.0.0.1/tcp/4001',
          '/ip6/::1/tcp/4001',
          '/ip4/127.0.0.1/udp/4001/quic-v1',
          '/ip6/::1/udp/4001/quic-v1',
          '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
          '/ip6/::1/udp/4001/quic-v1/webtransport',
        ];

        for (final addrStr in kuboSwarmAddresses) {
          final ma = Multiaddr.parse(addrStr);
          final matchingTransports = allTransports
              .where((t) => t.canDial(ma))
              .toList();

          expect(
            matchingTransports,
            isNotEmpty,
            reason:
                'Swarm should have a matching transport for Kubo swarm address: $addrStr',
          );

          expect(
            matchingTransports.length,
            equals(1),
            reason:
                'Exactly one transport should claim address $addrStr without ambiguity',
          );
        }
      },
    );

    test(
      'Address dispatch matches expected transport for each protocol family',
      () {
        // 1. TCP
        expect(
          tcpTransport.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')),
          isTrue,
        );
        expect(
          tcpTransport.canDial(Multiaddr.parse('/ip6/::1/tcp/4001')),
          isTrue,
        );
        expect(
          tcpTransport.canDial(
            Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1'),
          ),
          isFalse,
        );

        // 2. WebSocket
        expect(
          wsTransport.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/ws')),
          isTrue,
        );
        expect(
          wsTransport.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/wss')),
          isTrue,
        );
        expect(
          wsTransport.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')),
          isFalse,
        );

        // 3. QUIC
        expect(
          quicTransport.canDial(
            Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1'),
          ),
          isTrue,
        );
        expect(
          quicTransport.canDial(Multiaddr.parse('/ip6/::1/udp/4001/quic-v1')),
          isTrue,
        );
        expect(
          quicTransport.canDial(
            Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1/webtransport'),
          ),
          isFalse,
        );

        // 4. WebTransport
        expect(
          wtTransport.canDial(
            Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1/webtransport'),
          ),
          isTrue,
        );
        expect(
          wtTransport.canDial(
            Multiaddr.parse('/ip6/::1/udp/4001/quic-v1/webtransport'),
          ),
          isTrue,
        );
        expect(
          wtTransport.canDial(
            Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1'),
          ),
          isFalse,
        );
      },
    );

    test('Security protocols negotiation matrix (TLS 1.3 and Noise)', () async {
      expect(secTransports.length, equals(2));
      expect(secTransports[0].id(), equals('/tls/1.0.0'));
      expect(secTransports[1].id(), equals('/noise'));

      // Both peer key identities match
      final tlsTpt = secTransports[0];
      final noiseTpt = secTransports[1];

      expect(tlsTpt.id(), equals(tlsProtocolId));
      expect(noiseTpt.id(), equals('/noise'));
    });

    test(
      'End-to-end loopback stream exchanges succeed on QUIC and WebTransport',
      () async {
        // Test QUIC
        final qListener = await quicTransport.listen(
          Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1'),
        );
        final qAccept = qListener.accept();
        final qDial = quicTransport.dial(qListener.multiaddr(), localPeer);
        final qClientConn = await qDial;
        final qServerConn = await qAccept;
        final qClientStream = await qClientConn.openStream();
        // Opening a stream puts no bytes on the wire on a natively
        // multiplexed transport: the peer only learns the stream exists when
        // a frame for it arrives (RFC 9000 s. 2.1). So the first write has to
        // precede the accept, which is what every real libp2p stream does by
        // writing its multistream-select header right after opening.
        final qServerStreamFuture = qServerConn.acceptStream();
        await qClientStream.write(
          Uint8List.fromList(utf8.encode('matrix quic test')),
        );
        final qServerStream = await qServerStreamFuture;
        final qReceived = await qServerStream.read();
        expect(utf8.decode(qReceived), equals('matrix quic test'));
        await qClientStream.close();
        await qServerStream.close();
        await qClientConn.close();
        await qServerConn.close();
        await qListener.close();

        // Test WebTransport
        final wtListener = await wtTransport.listen(
          Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1/webtransport'),
        );
        final wtAccept = wtListener.accept();
        final wtDial = wtTransport.dial(wtListener.multiaddr(), localPeer);
        final wtClientConn = await wtDial;
        final wtServerConn = await wtAccept;
        final wtClientStream = await wtClientConn.openStream();
        final wtServerStreamFuture = wtServerConn.acceptStream();
        await wtClientStream.write(
          Uint8List.fromList(utf8.encode('matrix webtransport test')),
        );
        final wtServerStream = await wtServerStreamFuture;
        final wtReceived = await wtServerStream.read();
        expect(utf8.decode(wtReceived), equals('matrix webtransport test'));
        await wtClientStream.close();
        await wtServerStream.close();
        await wtClientConn.close();
        await wtServerConn.close();
        await wtListener.close();

      },
    );
  });
}
