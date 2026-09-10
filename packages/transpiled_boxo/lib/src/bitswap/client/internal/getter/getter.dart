import 'dart:async';

import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import '../notifications/notifications.dart';

typedef GetBlocksFunc = Future<Stream<Block>> Function(List<Cid> keys);

/// SyncGetBlock takes a block cid and an async function for getting several
/// blocks that returns a channel, and uses that function to return the
/// block synchronously.
Future<Block> syncGetBlock(Cid k, GetBlocksFunc gb) async {
  if (!k.defined) {
    throw Exception('undefined cid in GetBlock: $k'); // ipld.ErrNotFound
  }

  final promise = await gb([k]);
  
  try {
    final block = await promise.first;
    return block;
  } catch (e) {
    if (e is StateError && e.message == 'No element') {
      throw Exception('promise channel was closed');
    }
    rethrow;
  }
}

typedef WantFunc = void Function(List<Cid> keys);

/// AsyncGetBlocks take a set of block cids, a pubsub channel for incoming
/// blocks, a want function, and a close function, and returns a channel of
/// incoming blocks.
Future<Stream<Block>> asyncGetBlocks(
    List<Cid> keys,
    PubSub notif,
    WantFunc want,
    void Function(List<Cid>) cwants) async {
  
  // If there are no keys supplied, just return a closed channel
  if (keys.isEmpty) {
    return const Stream.empty();
  }

  // Use a PubSub notifier to listen for incoming blocks for each key
  final remaining = keys.map((e) => e.encode()).toSet();
  final promise = notif.subscribe(keys);

  // Send the want request for the keys to the network
  want(keys);

  final out = StreamController<Block>();

  void cleanup() {
    final remCids = keys.where((k) => remaining.contains(k.encode())).toList();
    if (remCids.isNotEmpty) {
      cwants(remCids);
    }
  }

  promise.listen(
    (blk) {
      remaining.remove(blk.cid().encode());
      out.add(blk);
    },
    onError: out.addError,
    onDone: () {
      out.close();
      cleanup();
    },
    cancelOnError: false,
  );
  
  out.onCancel = () {
    // Note: Since we are using an async stream, if canceled, clean up remaining wants
    cleanup();
  };

  return out.stream;
}
