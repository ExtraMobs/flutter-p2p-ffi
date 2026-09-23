@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:async';

import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../lib/local_kubo_harness.dart';

/// Interop test for Fase B (Section 6.7 item 4 in FASES_A_B_C.md):
/// Proves that BasicConnectionGater integrated in BasicUpgrader / TcpTransport
/// rejects inbound connection attempts from a real Kubo daemon whose IP address
/// is blocked in the gater, and permits connections once unblocked.
void main() {
  test(
    'BasicConnectionGater rejects incoming connection dialed by a real Kubo peer when blocked',
    () async {
      final executable = await LocalKuboHarness.findExecutable();
      if (executable == null) {
        markTestSkipped(
          'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH',
        );
        return;
      }

      LocalKuboHarness? kubo;
      Listener? listener;
      try {
        kubo = await LocalKuboHarness.start(executable: executable);
        final key = await generateEd25519KeyPair();
        final gater = BasicConnectionGater();

        final upgrader = BasicUpgrader(
          localIdentityKey: key,
          security: [TlsTransport(privKey: key)],
          gater: gater,
        );
        final transport = TcpTransport(upgrader: upgrader, gater: gater);

        final localPeer = PeerId.fromPubKey(key.getPublic());
        listener =
            await transport.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));

        // 1. Block loopback IP (127.0.0.1) from which Kubo connects
        final loopbackIp = Ip.tryParse('127.0.0.1')!;
        await gater.blockAddr(loopbackIp);

        // Attempting to connect from Kubo must fail because interceptAccept rejects it immediately
        var connectFailed = false;
        try {
          await kubo
              .swarmConnect('${listener.multiaddr()}/p2p/$localPeer')
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          connectFailed = true;
        }
        expect(
          connectFailed,
          isTrue,
          reason:
              'Kubo connection should have been rejected by ConnectionGater',
        );

        // 2. Unblock the loopback IP
        await gater.unblockAddr(loopbackIp);

        // Kubo should now connect successfully
        final acceptedFuture = listener.accept();
        await kubo.swarmConnect('${listener.multiaddr()}/p2p/$localPeer');
        final conn = await acceptedFuture.timeout(const Duration(seconds: 15));
        expect(conn.remotePeer(), equals(PeerId.decode(kubo.peerId)));
        await conn.close();
      } catch (_) {
        if (kubo != null) {
          printOnFailure('Kubo stderr:\n${kubo.stderrLog}');
        }
        rethrow;
      } finally {
        await listener?.close();
        await kubo?.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
