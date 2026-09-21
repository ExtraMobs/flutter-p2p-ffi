// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

// Upstream: go-libp2p e20bb60ffc4b4ee33640e5fe8f45fccce893cecd,
// p2p/transport/websocket/{websocket.go,conn.go,listener.go}.
// AST: libp2p-index.
//
// Local-only coverage against a real WebSocket server on 127.0.0.1 (no
// external network access), exercising WebsocketTransport.dial()/listen()
// end to end through BasicUpgrader (Noise + yamux), mirroring
// TestWebsocketConnection/TestCanDial-style integration and this project's
// TcpTransport atomic test precedent.
//
// The underlying byte-stream wrapper (conn.go's `Conn` equivalent) is a
// private class in lib/src/p2p/transport/websocket/websocket.dart -- see its
// doc comment for why -- so it carries no individual Rule-24 test
// obligation. Its partial-frame-read buffering is still exercised here: the
// "large payload" test below writes one WebSocket message far bigger than
// the small chunks it is read back in, forcing exactly the multi-read
// buffer-draining path the private wrapper implements, the same way
// yamux/Noise framing above it already reads fixed-size sub-messages via
// repeated small reads on every call in this suite.
void main() async {
  final identity = await generateEd25519KeyPair();
  final remoteIdentity = await generateEd25519KeyPair();
  final remotePeer = PeerId.fromPubKey(remoteIdentity.getPublic());

  Future<
    (CapableConn, CapableConn, Listener, WebsocketTransport, WebsocketTransport)
  >
  dialedPair() async {
    final tServer = WebsocketTransport(
      upgrader: BasicUpgrader(localIdentityKey: remoteIdentity),
    );
    final listener = await tServer.listen(
      Multiaddr.parse('/ip4/127.0.0.1/tcp/0/ws'),
    );
    final boundAddr = listener.multiaddr();

    final tClient = WebsocketTransport(
      upgrader: BasicUpgrader(localIdentityKey: identity),
    );
    final acceptFuture = listener.accept();
    final clientConn = await tClient.dial(boundAddr, remotePeer);
    final serverConn = await acceptFuture;
    return (clientConn, serverConn, listener, tServer, tClient);
  }

  group('WebsocketTransport [Atomic Audit]', () {
    test(
      'listen() - binds a /ws listener and reports its bound multiaddr',
      () async {
        final t = WebsocketTransport(
          upgrader: BasicUpgrader(localIdentityKey: identity),
        );
        final listener = await t.listen(
          Multiaddr.parse('/ip4/127.0.0.1/tcp/0/ws'),
        );
        expect(listener.multiaddr().toString(), contains('/tcp/'));
        expect(listener.multiaddr().toString(), endsWith('/ws'));
        await listener.close();
        await t.close();
      },
    );

    test(
      'listen() - rejects /wss without a configured tls SecurityContext',
      () async {
        final t = WebsocketTransport(
          upgrader: BasicUpgrader(localIdentityKey: identity),
        );
        await expectLater(
          () => t.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0/wss')),
          throwsA(isA<ArgumentError>()),
        );
        await t.close();
      },
    );

    test(
      'dial() - connects to a listening /ws transport and negotiates Noise+yamux',
      () async {
        final (clientConn, serverConn, listener, tServer, tClient) =
            await dialedPair();

        expect(clientConn.remotePeer(), equals(remotePeer));
        expect(clientConn.connState().transport, equals('websocket'));
        expect(serverConn.connState().transport, equals('websocket'));

        await clientConn.close();
        await serverConn.close();
        await listener.close();
        await tServer.close();
        await tClient.close();
      },
    );

    test('dial()/accept() - exchanges bytes over an opened stream', () async {
      final (clientConn, serverConn, listener, tServer, tClient) =
          await dialedPair();

      final msg = Uint8List.fromList('HELLO WORLD'.codeUnits);
      final serverAcceptStream = serverConn.acceptStream();
      final clientStream = await clientConn.openStream();
      await clientStream.write(msg);
      final serverStream = await serverAcceptStream;
      final got = await serverStream.read(msg.length);
      expect(got, equals(msg));

      await clientStream.close();
      await serverStream.close();
      await clientConn.close();
      await serverConn.close();
      await listener.close();
      await tServer.close();
      await tClient.close();
    });

    test(
      'dial()/accept() - a large single write is reassembled correctly from many small reads '
      '(the underlying WebSocket-message buffer must not drop or reorder bytes across a partial read)',
      () async {
        final (clientConn, serverConn, listener, tServer, tClient) =
            await dialedPair();

        final msg = Uint8List.fromList(List.generate(20000, (i) => i % 256));
        final serverAcceptStream = serverConn.acceptStream();
        final clientStream = await clientConn.openStream();
        final writeFuture = clientStream.write(msg);
        final serverStream = await serverAcceptStream;

        final received = BytesBuilder(copy: false);
        while (received.length < msg.length) {
          final chunk = await serverStream.read(37);
          expect(chunk, isNotEmpty);
          received.add(chunk);
        }
        await writeFuture;
        expect(received.toBytes(), equals(msg));

        await clientStream.close();
        await serverStream.close();
        await clientConn.close();
        await serverConn.close();
        await listener.close();
        await tServer.close();
        await tClient.close();
      },
    );

    test('close() - closes every listener created by the transport', () async {
      final t = WebsocketTransport(
        upgrader: BasicUpgrader(localIdentityKey: identity),
      );
      final listener = await t.listen(
        Multiaddr.parse('/ip4/127.0.0.1/tcp/0/ws'),
      );
      await t.close();
      await expectLater(
        () => listener.accept(),
        throwsA(isA<ListenerClosedException>()),
      );
    });
  });
}
