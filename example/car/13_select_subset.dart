// CAR 13 · select a subset into a new CAR. Common mistakes:
// 13_select_subset_mistakes.dart.
//
// What: a CAR with only part of a DAG: one file of a folder, the first bytes
// of a file, one block, or whatever an IPLD selector describes.
// When: sending one file of a large folder with the proof of its path, or a
// byte range of a large file (what trustless gateways answer).
// Kubo: none (`ipfs dag export` is always the whole DAG).
// Low level: boxo's gateway backend, by path + scope + byte range (from the
// node, fetching from the network if needed), or an IPLD selector with the
// UnixFS layer (from any CAR or blockstore).
//
//   dart run example/car/13_select_subset.dart
import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipld.dart' as ipld;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (boxo gateway backend, from the node)');
    //   Go:   _, rc, _ := bb.GetCAR(ctx, path, gateway.CarParams{Scope: gateway.DagScopeEntity,
    //             Range: &gateway.DagByteRange{From: 0, To: &to}})
    final backend = boxo.BlocksBackend(s.node.blocks);
    Future<int> blocksOf(String path, boxo.CarParams params) async {
      final (_, rc) =
          await backend.getCar(s.ctx, boxo.ImmutablePath(path), params);
      final n = cidsOf(go.readAll(rc)).length;
      rc.close();
      return n;
    }

    final file = '/ipfs/${s.root}/data.bin';
    print('data.bin, whole file (entity): '
        '${await blocksOf(file, boxo.CarParams(scope: boxo.dagScopeEntity))} '
        'blocks (the folder, the file root, 3 chunks)');
    print(
        'data.bin, first 100 bytes: ${await blocksOf(file, boxo.CarParams(scope: boxo.dagScopeEntity, range: boxo.DagByteRange(from: 0, to: 99)))} '
        'blocks (the folder, the file root, 1 chunk)');
    print('only the root block (block): '
        '${await blocksOf('/ipfs/${s.root}', boxo.CarParams(scope: boxo.dagScopeBlock))} block');

    print('\n== Low level (IPLD selector with UnixFS, from a CAR file)');
    // The source is a CAR on disk; the UnixFS layer lets the selector walk
    // by file names. The dag-pb prototype chooser makes go-car decode dag-pb
    // as typed nodes, which the UnixFS layer needs.
    //   Go:   ls := cidlink.DefaultLinkSystem(); unixfsnode.AddUnixFSReificationToLinkSystem(&ls)
    //         src, _ := storage.OpenReadable(f); ls.SetReadStorage(src)
    //         car.TraverseToFile(ctx, &ls, root, unixfsnode.UnixFSPathSelector("sub/note.md"), out,
    //             car.WithTraversalPrototypeChooser(dagpb.AddSupportToChooser(bsfetcher.DefaultPrototypeChooser)))
    final f = go.open(s.car);
    try {
      final ls = ipld.defaultLinkSystem();
      ipld.addUnixFsReificationToLinkSystem(ls);
      ls.setReadStorage(car.openReadable(f));
      final out = s.path('note.car');
      await car.traverseToFile(
          s.ctx, ls, s.root, ipld.unixFsPathSelector('sub/note.md'), out, [
        car.withTraversalPrototypeChooser(
            ipld.addSupportToChooser(boxo.defaultPrototypeChooser))
      ]);
      print(
          'sub/note.md: ${blockCount(out)} blocks (the folder, sub, the file)');
    } finally {
      f.close();
    }
  } finally {
    await s.close();
  }
}
