@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart' show BasicHost;

void main() {
  group('IpfsNode [Atomic Audit]', () {
    test('peerHost - exposes the composed host and active observed-address manager', () async {
      final offline = await IpfsNode.fromBuildCfg(BuildCfg());
      addTearDown(offline.close);
      expect(offline.peerHost, isNull);
      final node = await IpfsNode.fromBuildCfg(BuildCfg(
        online: true,
        config: const IpfsConfig(network: NetworkConfig(mdnsEnabled: false)),
      ));
      addTearDown(node.close);
      final host = node.peerHost! as BasicHost;
      expect(host.id, node.peerId);
      expect(host.observedAddrsManager, isNotNull);
    });

    test('fromBuildCfg() - two nodes discover each other without bootstrap', () async {
      final first = await IpfsNode.fromBuildCfg(BuildCfg(online: true));
      addTearDown(first.close);
      final second = await IpfsNode.fromBuildCfg(BuildCfg(online: true));
      addTearDown(second.close);
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(deadline) &&
          !first.peerHost!.network.peers().contains(second.peerId)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(first.peerHost!.network.peers(), contains(second.peerId));
      expect(second.peerHost!.network.peers(), contains(first.peerId));
    }, tags: ['network'], timeout: const Timeout(Duration(seconds: 40)));

    test('fromBuildCfg() - serves a block through its WebSocket listener', () async {
      final provider = await IpfsNode.fromBuildCfg(BuildCfg(
        online: true,
        config: const IpfsConfig(network: NetworkConfig(
          listenAddresses: ['/ip4/127.0.0.1/tcp/0/ws'],
          mdnsEnabled: false,
        )),
      ));
      addTearDown(provider.close);
      final consumer = await IpfsNode.fromBuildCfg(BuildCfg(
        online: true,
        config: const IpfsConfig(network: NetworkConfig(mdnsEnabled: false)),
      ));
      addTearDown(consumer.close);
      final bytes = Uint8List.fromList(List.generate(32768, (i) => i % 251));
      final cid = await provider.putRawBlock(bytes);
      final address = provider.swarmAddresses.firstWhere((a) =>
          a.startsWith('/ip4/127.0.0.1/') && a.contains('/ws/p2p/'));
      expect(address, contains('/ws/p2p/'));
      await consumer.connect(addrInfoFromString(address));
      expect((await consumer.getBlock(cid)).rawData(), bytes);
    }, timeout: const Timeout(Duration(seconds: 40)));
  });
}
