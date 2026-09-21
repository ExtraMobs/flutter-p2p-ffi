@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

/// Marco G.7 -- the transport matrix proved against a real Kubo daemon.
///
/// `canDial()` is a predicate over the multiaddr string: it opens no socket,
/// runs no handshake and moves no byte, so it cannot prove reach. Loopback
/// exchanges between two Dart nodes prove no more, because both sides share
/// whatever defect the transport has and understand each other precisely
/// because of it.
///
/// The proof this file demands instead: a real Kubo daemon, its own effective
/// `Addresses.Swarm` list, and for every single address a fresh Dart node that
/// connects, opens a Bitswap stream and recovers a block whose Cid validates.
/// A fresh node per address keeps a connection already established over
/// another transport from silently serving the next block.
void main() {
  /// The eight address shapes a default Kubo publishes.
  const swarmAddresses = <String>[
    '/ip4/127.0.0.1/tcp/0',
    '/ip4/127.0.0.1/udp/0/quic-v1',
    '/ip4/127.0.0.1/udp/0/quic-v1/webtransport',
    '/ip4/127.0.0.1/udp/0/webrtc-direct',
  ];

  test(
    'dials every address a real Kubo publishes and recovers a block by Bitswap',
    () async {
      final executable = await LocalKuboHarness.findExecutable();
      if (executable == null) {
        markTestSkipped(
          'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH',
        );
        return;
      }

      LocalKuboHarness? kubo;
      try {
        kubo = await LocalKuboHarness.start(
          executable: executable,
          swarmAddresses: swarmAddresses,
        );
        final addresses = await kubo.effectiveSwarmAddresses();
        printOnFailure('Kubo ${await kubo.version()} addresses: $addresses');
        expect(
          addresses,
          isNotEmpty,
          reason: 'Kubo reported no loopback swarm address to dial',
        );

        final failures = <String, Object>{};
        for (final address in addresses) {
          final bytes = Uint8List.fromList(
            'transport matrix fixture for $address'.codeUnits,
          );
          final cid = Cid.decode(await kubo.putRawBlock(bytes));

          IpfsNode? node;
          try {
            node = await IpfsNode.fromBuildCfg(
              BuildCfg(
                online: true,
                config: const IpfsConfig(
                  offline: false,
                  network: NetworkConfig(bootstrapPeers: []),
                ),
              ),
            );
            await node
                .connect(addrInfoFromString(address))
                .timeout(const Duration(seconds: 15));
            final downloaded =
                await node.getBlock(cid).timeout(const Duration(seconds: 30));
            expect(downloaded.rawData(), orderedEquals(bytes));
            expect(downloaded.cid(), equals(cid));
          } catch (error) {
            failures[address] = error;
          } finally {
            if (node != null) await node.close();
          }
        }

        expect(
          failures,
          isEmpty,
          reason: 'transports that could not reach the real Kubo daemon:\n'
              '${failures.entries.map((e) => '  ${e.key}\n    ${e.value}').join('\n')}',
        );
      } catch (_) {
        printOnFailure('Kubo stdout:\n${kubo?.stdoutLog}');
        printOnFailure('Kubo stderr:\n${kubo?.stderrLog}');
        rethrow;
      } finally {
        await kubo?.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
