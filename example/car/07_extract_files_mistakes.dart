// CAR 07 · extract the files: what not to do. The right way:
// 07_extract_files.dart.
//
//   dart run example/car/07_extract_files_mistakes.dart
import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/boxo/blockservice.dart' as blockservice;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/ipld.dart' as ipld;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    // A partial CAR (here: only the root block, like a `dag-scope=block`
    // response or a cut that kept only part of the DAG).
    final partial = s.path('partial.car');
    final ls = ipld.defaultLinkSystem()
      ..setReadStorage(ipld.Adapter()..wrapped = s.node.blockstore);
    await car.traverseToFile(
        s.ctx, ls, s.root, ipld.commonSelectorMatchPoint, partial);

    await mustFail('extract the files of a partial CAR',
        why: 'the files are made of blocks the CAR does not have: '
            'IpfsNotFound for the first missing one',
        instead: 'check the CAR first (operations 01/03: which roots and '
            'blocks it has), or extract through a node that can fetch the '
            'rest from the network', action: () async {
      final ro = car.openReadOnly(partial);
      try {
        final ds = boxo.newDagService(blockservice.new$(ro, boxo.exchange(ro)));
        final f =
            await boxo.newUnixfsFile(s.ctx, ds, await ds.get(s.ctx, s.root));
        boxo.writeTo(f, s.path('out'));
      } finally {
        ro.close();
      }
    });
  } finally {
    await s.close();
  }
}
