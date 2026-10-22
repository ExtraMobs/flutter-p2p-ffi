// CAR 07 · extract the files: what not to do. The right way:
// 07_extract_files.dart.
//
//   dart run example/car/07_extract_files_mistakes.dart

import 'sample.dart';
import 'package:ipfs_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:ipfs_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:ipfs_ffi/go/boxo/ipld/unixfs/file.dart' as file;
import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/ipld_prime/storage/bsadapter.dart' as bsadapter;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector/parse.dart' as parse;
import 'package:ipfs_ffi/go/ipld_prime/linking/cid.dart' as cid;

Future<void> main() async {
  final s = await Sample.open();
  try {
    // A partial CAR (here: only the root block, like a `dag-scope=block`
    // response or a cut that kept only part of the DAG).
    final partial = s.path('partial.car');
    final ls = cid.defaultLinkSystem()
      ..setReadStorage(bsadapter.Adapter()..wrapped = s.node.blockstore);
    await car.traverseToFile(
        s.ctx, ls, s.root, parse.commonSelectorMatchPoint, partial);

    await mustFail('extract the files of a partial CAR',
        why: 'the files are made of blocks the CAR does not have: '
            'GolangNotFoundException for the first missing one',
        instead: 'check the CAR first (operations 01/03: which roots and '
            'blocks it has), or extract through a node that can fetch the '
            'rest from the network', action: () async {
      final ro = blockstore.openReadOnly(partial);
      try {
        final ds = merkledag
            .newDagService(blockservice.new$(ro, offline.exchange(ro)));
        final f =
            await file.newUnixfsFile(s.ctx, ds, await ds.get(s.ctx, s.root));
        files.writeTo(f, s.path('out'));
      } finally {
        ro.close();
      }
    });
  } finally {
    await s.close();
  }
}
