import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('functions - WebRTC Direct [Atomic Audit]', () {
    test('isWebRtcDirectMultiaddr() - validates multiaddresses correctly', () {
      final valid = Multiaddr.parse('/ip4/127.0.0.1/udp/4001/webrtc-direct');
      final (ok1, count1) = isWebRtcDirectMultiaddr(valid);
      expect(ok1, isTrue);
      expect(count1, equals(0));

      final withCert = Multiaddr.parse(
        '/ip4/127.0.0.1/udp/4001/webrtc-direct/certhash/b2uaraocy6yrdblb4sfptaddgimjmmpy',
      );
      final (ok2, count2) = isWebRtcDirectMultiaddr(withCert);
      expect(ok2, isTrue);
      expect(count2, equals(1));

      final invalid = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      final (ok3, _) = isWebRtcDirectMultiaddr(invalid);
      expect(ok3, isFalse);
    });
  });

  group('WebRtcTransport [Atomic Audit]', () {
    test('canDial() - checks multiaddr compatibility', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebRtcTransport(privKey: key);

      expect(
        transport.canDial(
          Multiaddr.parse('/ip4/127.0.0.1/udp/4001/webrtc-direct'),
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
      final transport = WebRtcTransport(privKey: key);

      expect(
        transport.protocols(),
        containsAll([Protocols.ip4, Protocols.udp, Protocols.webrtcDirect]),
      );
      await transport.close();
    });

    test('proxy() - returns proxy flag', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebRtcTransport(privKey: key);

      expect(transport.proxy(), isFalse);
      await transport.close();
    });

    test(
      'addCertHashes() - appends certhash component to multiaddress',
      () async {
        final key = await generateEd25519KeyPair();
        final transport = WebRtcTransport(privKey: key);

        final baseAddr = Multiaddr.parse(
          '/ip4/127.0.0.1/udp/4001/webrtc-direct',
        );
        final withCert = transport.addCertHashes(baseAddr);

        expect(withCert.toString(), contains('/certhash/'));
        final (ok, count) = isWebRtcDirectMultiaddr(withCert);
        expect(ok, isTrue);
        expect(count, equals(1));

        await transport.close();
      },
    );

    test('listen() - binds and advertises multiaddr', () async {
      final key = await generateEd25519KeyPair();
      final transport = WebRtcTransport(privKey: key);

      final listener = await transport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/webrtc-direct'),
      );
      expect(listener.multiaddr().toString(), contains('/webrtc-direct'));
      expect(listener.multiaddr().toString(), contains('/certhash/'));
      await listener.close();
      await transport.close();
    });

    test('dial() - connects and exchanges streams', () async {
      final serverKey = await generateEd25519KeyPair();
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());
      final serverTransport = WebRtcTransport(privKey: serverKey);

      final listener = await serverTransport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/webrtc-direct'),
      );
      final boundAddr = listener.multiaddr();

      final clientKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final clientTransport = WebRtcTransport(privKey: clientKey);

      final acceptFuture = listener.accept();
      final dialFuture = clientTransport.dial(boundAddr, serverPeer);

      final clientConn = await dialFuture;
      final serverConn = await acceptFuture;

      expect(clientConn.localPeer(), equals(clientPeer));
      expect(clientConn.remotePeer(), equals(serverPeer));
      expect(clientConn.connState().streamMultiplexer, equals('webrtc-direct'));
      expect(clientConn.connState().transport, equals('webrtc-direct'));
      expect(clientConn.isClosed, isFalse);

      final clientStreamFuture = clientConn.openStream();
      final serverStreamFuture = serverConn.acceptStream();

      final clientStream = await clientStreamFuture;
      final serverStream = await serverStreamFuture;

      final testData = utf8.encode('webrtc-direct stream data');
      await clientStream.write(Uint8List.fromList(testData));
      final receivedData = await serverStream.read();
      expect(utf8.decode(receivedData), equals('webrtc-direct stream data'));

      final replyData = utf8.encode('webrtc-direct server pong');
      await serverStream.write(Uint8List.fromList(replyData));
      final replyReceived = await clientStream.read();
      expect(utf8.decode(replyReceived), equals('webrtc-direct server pong'));

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
      final transport = WebRtcTransport(privKey: key);

      final listener = await transport.listen(
        Multiaddr.parse('/ip4/127.0.0.1/udp/0/webrtc-direct'),
      );
      expect(listener, isNotNull);

      await transport.close();
      expect(
        () => transport.dial(
          Multiaddr.parse('/ip4/127.0.0.1/udp/1234/webrtc-direct'),
          PeerId.fromPubKey(key.getPublic()),
        ),
        throwsStateError,
      );
    });
  });
}
