@Tags(['p0'])
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../lib/local_kubo_harness.dart';

/// Marco G.2 -- the TLS 1.3 handshake proved against a peer that really
/// offers TLS.
///
/// Kubo's default security list is TLS first, then Noise, so its plain TCP
/// listener is a real go-libp2p TLS 1.3 endpoint. Offering only `/tls/1.0.0`
/// in multistream-select forces that path and leaves Noise no room to rescue
/// the connection, which is exactly what this milestone has to demonstrate --
/// in both directions, because a node that can dial TLS but not accept it is
/// still unreachable for every peer that dials first.
void main() {
  Future<({LocalKuboHarness kubo, TcpTransport transport, PrivKey key})?>
      setUp() async {
    final executable = await LocalKuboHarness.findExecutable();
    if (executable == null) {
      markTestSkipped(
        'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH',
      );
      return null;
    }
    final kubo = await LocalKuboHarness.start(executable: executable);
    final key = await generateEd25519KeyPair();
    return (
      kubo: kubo,
      key: key,
      transport: TcpTransport(
        upgrader: BasicUpgrader(
          localIdentityKey: key,
          security: [TlsTransport(privKey: key)],
        ),
      ),
    );
  }

  test(
    'completes a TLS 1.3 handshake against a real go-libp2p peer',
    () async {
      final env = await setUp();
      if (env == null) return;
      CapableConn? conn;
      try {
        conn = await env.transport
            .dial(
              Multiaddr.parse('/ip4/127.0.0.1/tcp/${env.kubo.swarmPort}'),
              PeerId.decode(env.kubo.peerId),
            )
            .timeout(const Duration(seconds: 30));
        expect(conn.remotePeer(), equals(PeerId.decode(env.kubo.peerId)));
        expect(conn.connState().security, equals('/tls/1.0.0'));
      } catch (_) {
        printOnFailure('Kubo stderr: ${env.kubo.stderrLog}');
        rethrow;
      } finally {
        await conn?.close();
        await env.kubo.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'accepts a TLS 1.3 handshake dialed by a real go-libp2p peer',
    () async {
      final env = await setUp();
      if (env == null) return;
      Listener? listener;
      CapableConn? conn;
      try {
        final localPeer = PeerId.fromPubKey(env.key.getPublic());
        listener =
            await env.transport.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));
        final accepted = listener.accept();
        await env.kubo.swarmConnect('${listener.multiaddr()}/p2p/$localPeer');
        conn = await accepted.timeout(const Duration(seconds: 30));
        expect(conn.remotePeer(), equals(PeerId.decode(env.kubo.peerId)));
        expect(conn.connState().security, equals('/tls/1.0.0'));
      } catch (_) {
        printOnFailure('Kubo stderr: ${env.kubo.stderrLog}');
        rethrow;
      } finally {
        await conn?.close();
        await listener?.close();
        await env.kubo.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
