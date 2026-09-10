@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

void main() {
  test(
    'downloads a known-provider raw block from local Kubo via Bitswap',
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
        final bytes = Uint8List.fromList(
          'known-provider local Kubo Bitswap fixture'.codeUnits,
        );
        final cid = await kubo.putRawBlock(bytes);
        final kuboVersion = await kubo.version();
        printOnFailure('Kubo $kuboVersion provider=${kubo.peerId} cid=$cid');

        node = await IpfsNode.fromBuildCfg(
          BuildCfg(
            online: true,
            config: const IpfsConfig(
              offline: false,
              network: NetworkConfig(bootstrapPeers: []),
            ),
          ),
        );
        await node.connect(addrInfoFromString(kubo.swarmAddress));

        final parsedCid = Cid.decode(cid);
        final downloaded = await node.getBlock(parsedCid);
        expect(downloaded.rawData(), orderedEquals(bytes));

        expect(await node.blockstore.has(parsedCid), isTrue);
        final stored = await node.blockstore.get(parsedCid);
        expect(stored.rawData(), orderedEquals(bytes));
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
