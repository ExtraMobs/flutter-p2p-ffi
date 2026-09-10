@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

void main() {
  test(
    'Kubo discovers Dart node via DHT provide and downloads served block via Bitswap (Marco C.2)',
    () async {
      final executable = await LocalKuboHarness.findExecutable();
      if (executable == null) {
        markTestSkipped(
          'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH',
        );
        return;
      }

      LocalKuboHarness? kubo;
      IpfsNode? node;
      try {
        kubo = await LocalKuboHarness.start(
          executable: executable,
          routingType: 'dhtserver',
          clearBootstrap: false,
        );
        final kuboVersion = await kubo.version();
        printOnFailure('Started Kubo $kuboVersion at ${kubo.swarmAddress}');

        // Start Dart node connected to Kubo as bootstrap peer
        node = await IpfsNode.fromBuildCfg(
          BuildCfg(
            online: true,
            config: IpfsConfig(
              offline: false,
              network: NetworkConfig(
                listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
                bootstrapPeers: [kubo.swarmAddress],
              ),
            ),
            shutdownTimeout: const Duration(seconds: 5),
          ),
        );

        expect(node.isOnline, isTrue);
        expect(node.swarmAddresses, isNotEmpty);
        final dartSwarmAddr = node.swarmAddresses.first;
        final dartPeerId = node.peerId.toBase58();

        // Store a unique test block in the Dart node blockstore
        final testBytes = Uint8List.fromList(
          'dart-ipfs-dht-serving-block-${DateTime.now().millisecondsSinceEpoch}'.codeUnits,
        );
        final cid = await node.putRawBlock(testBytes);
        printOnFailure('Dart ($dartPeerId at $dartSwarmAddr) announcing cid=$cid to DHT');

        // Connect Dart node to Kubo in the swarm first
        await node.connect(addrInfoFromString(kubo.swarmAddress));

        // Dart node provides the CID to the DHT
        await node.provide(cid);

        // Kubo discovers the Dart node as provider via DHT findprovs
        final providers = await kubo.findProviders(cid.toString());
        printOnFailure('Kubo findprovs result: $providers');
        expect(providers, contains(dartPeerId));

        // Kubo fetches the block from the Dart node via Bitswap
        final downloadedBytes = await kubo.getRawBlock(cid.toString());
        expect(downloadedBytes, orderedEquals(testBytes));
      } catch (_) {
        if (kubo != null) {
          try {
            printOnFailure(await kubo.diagnostics());
          } catch (error) {
            printOnFailure('Kubo diagnostics unavailable: $error');
          }
        }
        printOnFailure('Kubo stdout:\n${kubo?.stdoutLog}');
        printOnFailure('Kubo stderr:\n${kubo?.stderrLog}');
        rethrow;
      } finally {
        if (node != null) await node.close();
        await kubo?.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
