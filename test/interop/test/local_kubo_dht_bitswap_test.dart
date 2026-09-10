@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

void main() {
  test('DHT discovers local Kubo provider before Bitswap download', () async {
    final executable = await LocalKuboHarness.findExecutable();
    if (executable == null) {
      markTestSkipped('Kubo executable not found');
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
      final bytes = Uint8List.fromList(
        'DHT to Bitswap local proof ${kubo.peerId}'.codeUnits,
      );
      final cidText = await kubo.putRawBlock(bytes);
      await kubo.provide(cidText);
      printOnFailure('Kubo providers: ${await kubo.findProviders(cidText)}');
      node = await IpfsNode.fromBuildCfg(
        BuildCfg(
          online: true,
          config: IpfsConfig(
            offline: false,
            network: NetworkConfig(bootstrapPeers: [kubo.swarmAddress]),
          ),
        ),
      );
      final cid = Cid.decode(cidText);
      final block = await node.getBlockFromDht(cid);
      expect(block.rawData(), orderedEquals(bytes));
      expect(await node.blockstore.has(cid), isTrue);
    } finally {
      await node?.close();
      await kubo?.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
