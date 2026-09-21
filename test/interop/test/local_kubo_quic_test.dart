@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

/// Marco G.1 -- QUIC transport (/quic-v1) proved against a real Kubo daemon.
///
/// Discovers and connects to Kubo's QUIC-v1 endpoint, negotiates TLS 1.3
/// handshake inside CRYPTO frames with ALPN `libp2p`, opens a stream,
/// negotiates Bitswap via multistream-select, and retrieves a block by CID.
void main() {
  test('dials Kubo over quic-v1 and retrieves block via Bitswap', () async {
    final executable = await LocalKuboHarness.findExecutable();
    if (executable == null) {
      markTestSkipped('Kubo executable not found');
      return;
    }

    final kubo = await LocalKuboHarness.start(
      executable: executable,
      swarmAddresses: const ['/ip4/127.0.0.1/udp/0/quic-v1'],
    );
    try {
      final addresses = await kubo.effectiveSwarmAddresses();
      expect(addresses, isNotEmpty, reason: 'Kubo reported no QUIC addresses');
      final quicAddr = addresses.first;

      final bytes = Uint8List.fromList('hello quic bitswap block'.codeUnits);
      final cid = Cid.decode(await kubo.putRawBlock(bytes));

      final node = await IpfsNode.fromBuildCfg(
        BuildCfg(
          online: true,
          config: const IpfsConfig(
            offline: false,
            network: NetworkConfig(bootstrapPeers: []),
          ),
        ),
      );
      try {
        await node
            .connect(addrInfoFromString(quicAddr))
            .timeout(const Duration(seconds: 15));

        final downloaded =
            await node.getBlock(cid).timeout(const Duration(seconds: 15));
        expect(downloaded.rawData(), orderedEquals(bytes));
        expect(downloaded.cid(), equals(cid));
      } finally {
        await node.close();
      }
    } finally {
      await kubo.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
