// CAR 14 · merge CARs into one. Common mistakes: 14_merge_mistakes.dart.
//
// What: one CAR with the blocks and the roots of several.
// When: shipping several DAGs in one file, or joining the parts of a CAR that
// was split.
// Kubo: import all of them into a node (`ipfs dag import a.car b.car`); kubo
// exports one root per CAR, so the merged file is the low-level way.
// Low level: a new read-write blockstore with all the roots, fed by the
// BlockReader of each CAR (duplicates are stored once).
//
//   dart run example/car/14_merge.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/go/block_format.dart' as block_format;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/p2p_ffi.dart' show GolangEofException;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  final other = await s.newNode('other');
  try {
    // A second CAR: one raw block (operation 05).
    final note = Uint8List.fromList(utf8.encode('a second CAR'));
    final noteCid = cid.newPrefixV1(0x55, 0x12).sum(note);
    final second = s.path('second.car');
    final w = blockstore.openReadWrite(second, [noteCid]);
    await w.put(s.ctx, block_format.Block(cid: noteCid, rawData: note));
    w.finalize();

    print('== Low level (go-car)');
    //   Go:   rw, _ := blockstore.OpenReadWrite(out, append(rootsA, rootsB...))
    //         for each CAR: br, _ := car.NewBlockReader(f); for { blk, _ := br.Next(); rw.Put(ctx, blk) }
    //         rw.Finalize()
    final out = s.path('merged.car');
    final rw = blockstore.openReadWrite(out, [s.root, noteCid]);
    for (final source in [s.car, second]) {
      final f = os.open(source);
      try {
        final br = car.BlockReader(f);
        final batch = <block_format.Block>[];
        while (true) {
          try {
            batch.add(br.next());
          } on GolangEofException {
            break;
          }
        }
        await rw.putMany(s.ctx, batch);
      } finally {
        f.close();
      }
    }
    rw.finalize();
    final r = car.openReader(out);
    try {
      print('$out: ${r.inspect(true).blockCount} blocks, roots ${r.roots()}');
    } finally {
      r.close();
    }

    print('\n== Kubo (high level)');
    //   CLI:  ipfs dag import --pin-roots folder.car second.car
    final imported =
        await dag.dagImportFiles(other, s.ctx, [s.car, second], pinRoots: true);
    print('imported ${imported.blockCount} blocks, '
        '${imported.roots.length} roots pinned');
  } finally {
    await other.close();
    await s.close();
  }
}
