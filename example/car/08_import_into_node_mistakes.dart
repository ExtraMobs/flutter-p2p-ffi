// CAR 08 · import into a node: what not to do. The right way:
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/ipld_prime/storage/bsadapter.dart' as bsadapter;
import 'package:p2p_ffi/go/block_format.dart' as block_format;
import 'package:p2p_ffi/go/ipld_prime/traversal/selector/parse.dart' as parse;
import 'package:p2p_ffi/go/ipld_prime/linking/cid.dart' as cid;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/cid.dart' as go_cid;
// 08_import_into_node.dart.
//
//   dart run example/car/08_import_into_node_mistakes.dart
import 'dart:typed_data';

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  final other = await s.newNode('other');
  try {
    // A block above 2 MiB (one raw block of 3 MiB).
    final big = Uint8List(3 << 20);
    final c = go_cid.newPrefixV1(0x55, 0x12).sum(big);
    final bigCar = s.path('big.car');
    final rw = blockstore.openReadWrite(bigCar, [c]);
    await rw.put(s.ctx, block_format.Block(cid: c, rawData: big));
    rw.finalize();
    await mustFail('import a CAR with a block above 2 MiB',
        why: 'other peers do not exchange blocks that big: the import refuses',
        instead: 'chunk big data (UnixFS, operation 06); allowBigBlock: true '
            'only if the block never has to cross the network',
        action: () => dag.dagImportFiles(other, s.ctx, [bigCar]));

    // pinRoots with a root whose DAG is not complete in the CAR: the import
    // succeeds and the error comes per root, not as an exception.
    final partial = s.path('partial.car');
    final ls = cid.defaultLinkSystem()
      ..setReadStorage(bsadapter.Adapter()..wrapped = s.node.blockstore);
    await car.traverseToFile(
        s.ctx, ls, s.root, parse.commonSelectorMatchPoint, partial);
    final r = await dag.dagImportFiles(other, s.ctx, [partial], pinRoots: true);
    await silentlyWrong(
        'assume pinRoots pinned everything because no exception came',
        why: 'pinning is opportunistic: a root whose blocks are missing is '
            'not pinned, and the reason comes in roots[i].pinErrorMsg',
        instead: 'check pinErrorMsg of every root after the import',
        wrong: () => 'no exception, ${r.roots.length} root(s) listed',
        right: () => r.roots.map((m) => brief(m.pinErrorMsg)).join('; '));
  } finally {
    await other.close();
    await s.close();
  }
}
