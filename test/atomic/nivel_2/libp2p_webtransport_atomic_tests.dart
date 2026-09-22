import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('functions - WebTransport [Atomic Audit]', () {
    test('isWebtransportMultiaddr() - validates multiaddresses correctly', () {
      final valid = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      );
      final (ok1, count1) = isWebtransportMultiaddr(valid);
      expect(ok1, isTrue);
      expect(count1, equals(0));

      final withCert = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport/certhash/b2uaraocy6yrdblb4sfptaddgimjmmpy',
      );
      final (ok2, count2) = isWebtransportMultiaddr(withCert);
      expect(ok2, isTrue);
      expect(count2, equals(1));

      final invalid = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      final (ok3, _) = isWebtransportMultiaddr(invalid);
      expect(ok3, isFalse);
    });

    test('extractCertHashes() - extracts sha256 cert hashes', () {
      final certBytes = Uint8List.fromList(utf8.encode('dummy-test-cert'));
      final comp = addrComponentForCert(certBytes);
      final addr = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      ).encapsulate(Multiaddr.parse('/certhash/${comp.value}'));
      final extracted = extractCertHashes(addr);
      expect(extracted, isNotEmpty);
      expect(extracted.first.length, equals(32));
    });

    test(
      'addrComponentForCert() - creates certhash component from cert bytes',
      () {
        final certBytes = Uint8List.fromList(utf8.encode('dummy-test-cert'));
        final comp = addrComponentForCert(certBytes);
        expect(comp.protocol.code, equals(Protocols.certhash));
        expect(comp.value, isNotEmpty);
      },
    );
  });

  group('WebtransportTransport [Atomic Audit]', () {
    test('canDial() - checks multiaddr compatibility', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      expect(
        transport.canDial(
          Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1/webtransport'),
        ),
        isTrue,
      );
      expect(
        transport.canDial(Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1')),
        isFalse,
      );
      expect(
        transport.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')),
        isFalse,
      );
      await transport.close();
    });

    test('protocols() - returns supported protocols', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      expect(
        transport.protocols(),
        containsAll([
          Protocols.ip4,
          Protocols.udp,
          Protocols.quicV1,
          Protocols.webtransport,
        ]),
      );
      await transport.close();
    });

    test('proxy() - returns proxy flag', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      expect(transport.proxy(), isFalse);
      await transport.close();
    });

    test('resolve() - resolves multiaddr identity', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      final addr = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      );
      final resolved = await transport.resolve(addr);
      expect(resolved.toString(), equals(addr.toString()));
      await transport.close();
    });

    test('addCertHashes() - appends the current and next certhashes once the '
        'transport is listening', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);
      final listener = await transport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1/webtransport'),
      );

      final baseAddr = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      );
      final withCert = transport.addCertHashes(baseAddr);

      expect(withCert.toString(), contains('/certhash/'));
      final (ok, count) = isWebtransportMultiaddr(withCert);
      expect(ok, isTrue);
      // Two, not one: upstream advertises the certificate in use and the
      // one that replaces it (`cert_manager.go:201-215`), so a peer holding
      // a cached multiaddr can still dial across a rollover.
      expect(count, equals(2));
      // The hashes have to be the listener's own, which is the whole point
      // of a certhash -- the previous implementation hashed `privKey.raw()`,
      // the raw private key, so the component could never match the
      // certificate the TLS handshake actually presented.
      expect(
        extractCertHashes(withCert).map((h) => h.toString()),
        orderedEquals(
          extractCertHashes(listener.multiaddr()).map((h) => h.toString()),
        ),
      );

      await listener.close();
      await transport.close();
    });

    test('addCertHashes() - leaves the address untouched while no listener has '
        'created a certificate yet', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      final baseAddr = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      );
      // Go answers the same way, with `ok == false`
      // (`transport.go:436-441`): before the transport listens there is no
      // certificate to name.
      expect(
        transport.addCertHashes(baseAddr).toString(),
        equals(baseAddr.toString()),
      );

      await transport.close();
    });

    test('listen() - binds and advertises multiaddr', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      final listener = await transport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1/webtransport'),
      );
      expect(
        listener.multiaddr().toString(),
        contains('/quic-v1/webtransport'),
      );
      expect(listener.multiaddr().toString(), contains('/certhash/'));
      await listener.close();
      await transport.close();
    });

    test('dial() - connects and exchanges streams', () async {
      final serverKey = await generateEd25519KeyPair();
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());
      final serverTransport = WebtransportTransport(privKey: serverKey);

      final listener = await serverTransport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1/webtransport'),
      );
      final boundAddr = listener.multiaddr();

      final clientKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final clientTransport = WebtransportTransport(privKey: clientKey);

      final acceptFuture = listener.accept();
      final dialFuture = clientTransport.dial(boundAddr, serverPeer);

      final clientConn = await dialFuture;
      final serverConn = await acceptFuture;

      expect(clientConn.localPeer(), equals(clientPeer));
      expect(clientConn.remotePeer(), equals(serverPeer));
      expect(clientConn.connState().streamMultiplexer, equals('webtransport'));
      expect(clientConn.connState().transport, equals('webtransport'));
      expect(clientConn.isClosed, isFalse);

      final clientStreamFuture = clientConn.openStream();
      final serverStreamFuture = serverConn.acceptStream();

      final clientStream = await clientStreamFuture;
      final serverStream = await serverStreamFuture;

      final testData = utf8.encode('webtransport stream payload');
      await clientStream.write(Uint8List.fromList(testData));
      final receivedData = await serverStream.read();
      expect(utf8.decode(receivedData), equals('webtransport stream payload'));

      final replyData = utf8.encode('webtransport server pong');
      await serverStream.write(Uint8List.fromList(replyData));
      final replyReceived = await clientStream.read();
      expect(utf8.decode(replyReceived), equals('webtransport server pong'));

      await clientStream.close();
      await serverStream.close();

      await clientConn.close();
      await serverConn.close();
      await listener.close();
      await clientTransport.close();
      await serverTransport.close();
    });

    test('close() - closes transport and throws on closed dial', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebtransportTransport(privKey: key);

      final listener = await transport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1/webtransport'),
      );
      expect(listener, isNotNull);

      await transport.close();
      expect(
        () => transport.dial(
          Multiaddr.parse('/ip4/127.0.0.1/udp/1234/quic-v1/webtransport'),
          PeerId.fromPubKey(key.getPublic()),
        ),
        throwsStateError,
      );
    });
  });
}
