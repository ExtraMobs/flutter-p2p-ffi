@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

void main() {
  test(
    'Kubo downloads a raw block hosted and served by local Dart IPFS node via Bitswap (Marco C.1)',
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
        kubo = await LocalKuboHarness.start(executable: executable);
        final kuboVersion = await kubo.version();

        // Start Dart node listening on loopback with ephemeral TCP port
        node = await IpfsNode.fromBuildCfg(
          BuildCfg(
            online: true,
            config: const IpfsConfig(
              offline: false,
              network: NetworkConfig(
                listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
                bootstrapPeers: [],
              ),
            ),
          ),
        );

        expect(node.isOnline, isTrue);
        expect(node.swarmAddresses, isNotEmpty);
        final dartSwarmAddr = node.swarmAddresses.first;

        // Store a unique test block in the Dart node blockstore
        final testBytes = Uint8List.fromList(
          'dart-ipfs-seeding-block-payload-${DateTime.now().millisecondsSinceEpoch}'.codeUnits,
        );
        final cid = await node.putRawBlock(testBytes);
        printOnFailure('Kubo ($kuboVersion) connecting to Dart ($dartSwarmAddr) serving cid=$cid');

        // Connect nodes in the swarm
        await node.connect(addrInfoFromString(kubo.swarmAddress));
        await kubo.swarmConnect(dartSwarmAddr);

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
