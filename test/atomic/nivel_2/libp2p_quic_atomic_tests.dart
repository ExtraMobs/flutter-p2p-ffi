import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('QuicTransport [Atomic Audit]', () {
    test('canDial() - matches valid QUIC multiaddrs', () async {
      final key = await generateEd25519KeyPair();
      final transport = QuicTransport(privKey: key);

      expect(transport.canDial(Multiaddr.parse('/ip4/127.0.0.1/udp/4001/quic-v1')), isTrue);
      expect(transport.canDial(Multiaddr.parse('/ip6/::1/udp/4001/quic-v1')), isTrue);
      expect(transport.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isFalse);
      expect(transport.canDial(Multiaddr.parse('/ip4/127.0.0.1/udp/4001')), isFalse);
      await transport.close();
    });

    test('protocols() - returns supported protocols', () async {
      final key = await generateEd25519KeyPair();
      final transport = QuicTransport(privKey: key);

      expect(transport.protocols(), containsAll([Protocols.ip4, Protocols.udp, Protocols.quicV1]));
      await transport.close();
    });

    test('proxy() - returns proxy flag', () async {
      final key = await generateEd25519KeyPair();
      final transport = QuicTransport(privKey: key);

      expect(transport.proxy(), isFalse);
      await transport.close();
    });

    test('listen() - binds UDP listener on multiaddr', () async {
      final key = await generateEd25519KeyPair();
      final transport = QuicTransport(privKey: key);

      final listener = await transport.listen(Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1'));
      final boundAddr = listener.multiaddr();

      expect(boundAddr.toString(), contains('/udp/'));
      expect(boundAddr.toString(), contains('/quic-v1'));

      await listener.close();
      await transport.close();
    });

    test('dial() - establishes connection, authenticates peer, and multiplexes streams', () async {
      final serverKey = await generateEd25519KeyPair();
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());
      final serverTransport = QuicTransport(privKey: serverKey);

      final listener = await serverTransport.listen(Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1'));
      final boundAddr = listener.multiaddr();

      final clientKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final clientTransport = QuicTransport(privKey: clientKey);

      final acceptFuture = listener.accept();
      final dialFuture = clientTransport.dial(boundAddr, serverPeer);

      final clientConn = await dialFuture;
      final serverConn = await acceptFuture;

      expect(clientConn.localPeer(), equals(clientPeer));
      expect(clientConn.remotePeer(), equals(serverPeer));
      expect(clientConn.connState().streamMultiplexer, equals('quic'));
      expect(clientConn.connState().security, equals('/tls/1.0.0'));
      expect(clientConn.connState().transport, equals('quic-v1'));
      expect(clientConn.isClosed, isFalse);

      // Test stream multiplexing over QUIC
      final clientStreamFuture = clientConn.openStream();
      final serverStreamFuture = serverConn.acceptStream();

      final clientStream = await clientStreamFuture;
      final serverStream = await serverStreamFuture;

      final testData = utf8.encode('hello quic over libp2p');
      await clientStream.write(Uint8List.fromList(testData));
      final receivedData = await serverStream.read();
      expect(utf8.decode(receivedData), equals('hello quic over libp2p'));

      final replyData = utf8.encode('pong from quic server');
      await serverStream.write(Uint8List.fromList(replyData));
      final replyReceived = await clientStream.read();
      expect(utf8.decode(replyReceived), equals('pong from quic server'));

      await clientStream.close();
      await serverStream.close();

      await clientConn.close();
      await serverConn.close();
      await listener.close();
      await clientTransport.close();
      await serverTransport.close();
    });

    test('close() - closes transport and all listeners', () async {
      final key = await generateEd25519KeyPair();
      final transport = QuicTransport(privKey: key);

      final listener = await transport.listen(Multiaddr.parse('/ip4/127.0.0.1/udp/0/quic-v1'));
      expect(listener, isNotNull);

      await transport.close();
      expect(() => transport.dial(Multiaddr.parse('/ip4/127.0.0.1/udp/1234/quic-v1'), PeerId.fromPubKey(key.getPublic())),
          throwsStateError);
    });
  });
}
