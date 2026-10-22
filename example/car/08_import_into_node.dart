// CAR 08 · import a CAR into a node. Common mistakes:
// 08_import_into_node_mistakes.dart.
//
// What: store every block of a CAR in the node's repo, and pin its roots so
// the garbage collector keeps them.
// When: making the content of a CAR available to the node (to serve it, to
// read it through the CoreAPI, to keep it).
// Kubo: `ipfs dag import --pin-roots` (checks every block and pins).
// Low level: read the blocks with go-car and put them into the node's
// blockstore (boxo), then pin the root through the CoreAPI.
//
//   dart run example/car/08_import_into_node.dart
import 'package:p2p_ffi/go/boxo/path.dart' as boxo_path;
import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/p2p_ffi.dart' show GolangEofException;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  final a = await s.newNode('a'), b = await s.newNode('b');
  try {
    final path = boxo_path.Path('/ipfs/${s.root}');

    print('== Kubo (high level)');
    //   CLI:  ipfs dag import --pin-roots folder.car
    final r = await dag.dagImportFiles(a, s.ctx, [s.car], pinRoots: true);
    print('imported ${r.blockCount} blocks (${r.blockBytesCount} bytes); '
        'roots: ${[
      for (final m in r.roots)
        '${m.cid} ${m.pinErrorMsg.isEmpty ? 'pinned' : m.pinErrorMsg}'
    ]}');

    print('\n== Low level (go-car + boxo blockstore)');
    //   Go:   br, _ := car.NewBlockReader(f)
    //         for { blk, err := br.Next(); ...; node.Blockstore.Put(ctx, blk) }
    //         api.Pin().Add(ctx, path.FromCid(root))
    final f = os.open(s.car);
    var n = 0;
    try {
      final br = car.BlockReader(f);
      while (true) {
        try {
          await b.blockstore.put(s.ctx, br.next());
          n++;
        } on GolangEofException {
          break;
        }
      }
    } finally {
      f.close();
    }
    final api = coreapi.newCoreApi(b);
    await api.pin().add(s.ctx, path);
    final (_, pinned) = await api.pin().isPinned(s.ctx, path);
    print('put $n blocks; root pinned: $pinned');
  } finally {
    await a.close();
    await b.close();
    await s.close();
  }
}
