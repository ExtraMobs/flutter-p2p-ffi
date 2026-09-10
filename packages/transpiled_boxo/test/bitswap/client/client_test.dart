import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
// Client tambem existe no circuitv2 do transpiled_libp2p; aqui o alvo e o
// Client do bitswap, importado logo abaixo.
import 'package:transpiled_libp2p/transpiled_libp2p.dart' hide Stats, Client;
import 'package:transpiled_boxo/bitswap/client.dart';
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_boxo/bitswap/network.dart';
import 'package:transpiled_boxo/src/blockstore.dart';

class FakeNetwork implements BitSwapNetwork {
  final List<Receiver> receivers = [];
  final List<BitSwapMessage> sentMessages = [];
  final Set<PeerId> connectedPeersSet = {};

  @override
  void start(List<Receiver> r) {
    receivers.addAll(r);
  }

  @override
  void stop() {}

  @override
  Future<void> sendMessage(PeerId peer, BitSwapMessage message) async {
    sentMessages.add(message);
  }

  @override
  Future<void> connect(AddrInfo peer) async {
    connectedPeersSet.add(peer.id);
  }

  @override
  Future<void> disconnectFrom(PeerId peer) async {
    connectedPeersSet.remove(peer);
  }

  @override
  bool isConnectedToPeer(PeerId peer) => connectedPeersSet.contains(peer);

  @override
  Future<MessageSender> newMessageSender(PeerId peer, MessageSenderOpts opts) async {
    throw UnimplementedError();
  }

  @override
  P2pHost host() => throw UnimplementedError();

  @override
  Stats stats() => Stats();

  @override
  PeerId self() => PeerId.decode('12D3KooWD3otHYgKUsJpbqEZkUyF1UJYzMW6t8ru2tUwLm3pnHs4');

  @override
  Duration latency(PeerId peer) => Duration.zero;

  @override
  Future<PingResult> ping(PeerId peer) async => PingResult(Duration.zero);

  @override
  void protect(PeerId peer, String tag) {}

  @override
  void tagPeer(PeerId peer, String tag, int weight) {}

  @override
  bool unprotect(PeerId peer, String tag) => false;

  @override
  void untagPeer(PeerId peer, String tag) {}
}

void main() {
  group('Bitswap Client', () {
    test('retrieves block already in blockstore without network request', () async {
      final network = FakeNetwork();
      final blockstore = Blockstore(MapDatastore());
      final block = blocks.BasicBlock(
        Uint8List.fromList([1, 2, 3, 4]),
        Cid.decode('bafkreiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
      );
      await blockstore.put(block);

      final client = Client(
        network: network,
        blockstore: blockstore,
      );

      final result = await client.getBlock(block.cid());
      expect(result.rawData(), orderedEquals(block.rawData()));
      expect(network.sentMessages, isEmpty);
      await client.close();
    });

    test('retrieves block via network receiveMessage', () async {
      final network = FakeNetwork();
      final blockstore = Blockstore(MapDatastore());
      final client = Client(
        network: network,
        blockstore: blockstore,
        timeout: const Duration(seconds: 5),
      );
      network.start([client]);

      final peer = PeerId.decode('12D3KooWPAfko2Q2pSAzf4ZGKZaG2n6yNJkByJsS4FqPp6nQr54B');
      client.peerConnected(peer);

      final testCid = Cid.decode('bafkreiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      final testBlock = blocks.BasicBlock(Uint8List.fromList([10, 20, 30]), testCid);

      // Request block asynchronously
      final getFuture = client.getBlock(testCid);

      // Simulate incoming message with block
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final incoming = BitSwapMessage(false);
      incoming.addBlock(testBlock);
      client.receiveMessage(peer, incoming);

      final received = await getFuture;
      expect(received.rawData(), orderedEquals(testBlock.rawData()));
      await client.close();
    });

    test('peer connectedness lifecycle in client', () async {
      final network = FakeNetwork();
      final blockstore = Blockstore(MapDatastore());
      final client = Client(
        network: network,
        blockstore: blockstore,
      );
      final peer = PeerId.decode('12D3KooWPAfko2Q2pSAzf4ZGKZaG2n6yNJkByJsS4FqPp6nQr54B');

      client.peerConnected(peer);
      expect(client.pm.connectedPeers(), contains(peer));

      client.peerDisconnected(peer);
      expect(client.pm.connectedPeers(), isNot(contains(peer)));

      expect(client.isOnline(), isTrue);
      await client.close();
    });
  });
}
