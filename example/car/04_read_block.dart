// CAR 04 · read a block by CID. Common mistakes: 04_read_block_mistakes.dart.
//
// What: get one block out of a CAR without reading the whole file.
// When: serving blocks from a stored CAR, or checking whether it has a block.
// Kubo: import, then ask the node for the block (`ipfs dag import` +
// `ipfs block get`).
// Low level: go-car's read-only blockstore, which uses the index (the CARv2
// one, or one built in memory for a CARv1).
//
//   dart run example/car/04_read_block.dart

import 'sample.dart';
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;

Future<void> main() async {
  final s = await Sample.open();
  final other = await s.newNode('other');
  try {
    final target = s.root; // the folder's block

    print('== Low level (go-car)');
    //   Go:   ro, _ := blockstore.OpenReadOnly(path); defer ro.Close()
    //         ok, _ := ro.Has(ctx, c); n, _ := ro.GetSize(ctx, c); b, _ := ro.Get(ctx, c)
    final ro = blockstore.openReadOnly(s.car);
    try {
      print('has it: ${await ro.has(s.ctx, target)}');
      print('size: ${await ro.getSize(s.ctx, target)} bytes');
      final b = await ro.get(s.ctx, target);
      print('block ${b.cid}: ${b.rawData!.length} bytes');
    } finally {
      ro.close();
    }

    print('\n== Kubo (high level)');
    //   CLI:  ipfs dag import folder.car && ipfs block get <cid>
    await dag.dagImportFiles(other, s.ctx, [s.car]);
    final api = coreapi.newCoreApi(other);
    final data =
        io.readAll(await api.block().get(s.ctx, path.Path('/ipfs/$target')));
    print('the same block from the node: ${data.length} bytes');
  } finally {
    await other.close();
    await s.close();
  }
}
