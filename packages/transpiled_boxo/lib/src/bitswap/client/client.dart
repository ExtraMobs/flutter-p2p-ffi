import 'dart:async';

import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_boxo/bitswap/network.dart';

import '../../blockstore.dart';
import 'internal/blockpresencemanager/blockpresencemanager.dart';
import 'internal/getter/getter.dart';
import 'internal/notifications/notifications.dart';
import 'internal/peermanager/peermanager.dart';
import 'internal/peermanager/peerwantmanager.dart';

/// BlockGetter retrieves blocks from Bitswap or the local blockstore.
abstract interface class BlockGetter {
  Future<blocks.Block> getBlock(Cid cid);
}

/// A minimal no-op Gauge.
class NullGauge implements Gauge {
  const NullGauge();
  @override
  void inc() {}
  @override
  void dec() {}
}

/// Bitswap Client implementing BlockGetter and network Receiver.
class Client implements Receiver, BlockGetter {
  Client({
    required this.network,
    required this.blockstore,
    this.providerFinder,
    PeerManager? pm,
    BlockPresenceManager? bpm,
    NotificationsPubSub? notif,
    this.timeout = const Duration(seconds: 30),
  })  : bpm = bpm ?? BlockPresenceManager(),
        notif = notif ?? NotificationsPubSub(),
        pm = pm ??
            PeerManager(
              (p) => _DefaultPeerQueue(p, network),
              BroadcastControl(),
              const NullGauge(),
              const NullGauge(),
              const NullGauge(),
            );

  final BitSwapNetwork network;
  final Blockstore blockstore;
  final ContentDiscovery? providerFinder;
  final PeerManager pm;
  final BlockPresenceManager bpm;
  final NotificationsPubSub notif;
  final Duration timeout;

  bool _closed = false;

  @override
  Future<blocks.Block> getBlock(Cid cid) async {
    if (await blockstore.has(cid)) {
      return blockstore.get(cid);
    }
    return syncGetBlock(cid, getBlocks).timeout(timeout);
  }

  Future<Stream<blocks.Block>> getBlocks(List<Cid> keys) async {
    return asyncGetBlocks(
      keys,
      notif,
      (wants) {
        pm.broadcastWantHaves(wants);
        for (final p in pm.connectedPeers()) {
          pm.sendWants(p, wants, const []);
        }
      },
      (cancels) {
        pm.sendCancels(cancels);
      },
    );
  }

  @override
  void receiveMessage(PeerId sender, BitSwapMessage incoming) {
    if (_closed) return;

    final receivedBlocks = incoming.blocks();
    final haves = incoming.haves();
    final dontHaves = incoming.dontHaves();

    if (receivedBlocks.isNotEmpty || haves.isNotEmpty || dontHaves.isNotEmpty) {
      bpm.receiveFrom(sender, haves, dontHaves);

      final allKs = <Cid>[
        ...receivedBlocks.map((b) => b.cid()),
        ...haves,
        ...dontHaves,
      ];
      pm.responseReceived(sender, allKs);

      if (receivedBlocks.isNotEmpty) {
        notif.publish(sender, receivedBlocks);
      }
    }
  }

  @override
  void receiveError(Exception error) {}

  @override
  void peerConnected(PeerId peer) {
    pm.connected(peer);
  }

  @override
  void peerDisconnected(PeerId peer) {
    pm.disconnected(peer);
  }

  List<Cid> getWantlist() => pm.currentWants();
  List<Cid> getWantBlocks() => pm.currentWantBlocks();
  List<Cid> getWantHaves() => pm.currentWantHaves();
  bool isOnline() => true;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    notif.shutdown();
  }
}

class _DefaultPeerQueue implements PeerQueue {
  _DefaultPeerQueue(this.peer, this.network);

  final PeerId peer;
  final BitSwapNetwork network;

  @override
  void addBroadcastWantHaves(List<Cid> wantHaves) {
    if (wantHaves.isEmpty) return;
    final msg = BitSwapMessage(false);
    for (final c in wantHaves) {
      msg.addEntry(c, 0, WantType.have, true);
    }
    unawaited(network.sendMessage(peer, msg));
  }

  @override
  void addWants(List<Cid> wantBlocks, List<Cid> wantHaves) {
    if (wantBlocks.isEmpty && wantHaves.isEmpty) return;
    final msg = BitSwapMessage(false);
    for (final c in wantHaves) {
      msg.addEntry(c, 0, WantType.have, true);
    }
    for (final c in wantBlocks) {
      msg.addEntry(c, 0, WantType.block, true);
    }
    unawaited(network.sendMessage(peer, msg));
  }

  @override
  void addCancels(List<Cid> cancels) {
    if (cancels.isEmpty) return;
    final msg = BitSwapMessage(false);
    for (final c in cancels) {
      msg.cancel(c);
    }
    unawaited(network.sendMessage(peer, msg));
  }

  @override
  void responseReceived(List<Cid> ks) {}

  @override
  bool hasMessage() => false;

  @override
  void startup() {}

  @override
  void shutdown() {}
}
