// CAR 07 · extract the files of a CAR. Common mistakes:
// 07_extract_files_mistakes.dart.
//
// What: turn the UnixFS DAG inside a CAR back into files and folders on disk.
// When: you received a CAR of files (from a gateway, from `ipfs-car`, from
// another node) and want the files.
// Kubo: import, then get (`ipfs dag import` + `ipfs get`).
// Low level, without a node: the CAR's read-only blockstore becomes an
// offline block service and a DAG service, and boxo's UnixFS reader writes
// the files out.
//
//   dart run example/car/07_extract_files.dart
import 'dart:io';
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/file.dart' as file;
import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  final other = await s.newNode('other');
  try {
    bool same(String out) =>
        File('$out/data.bin').readAsBytesSync().toString() ==
            s.data.toString() &&
        File('$out/sub/note.md').existsSync();

    print('== Low level (boxo + go-car, no node)');
    //   Go:   ro, _ := blockstore.OpenReadOnly(path); defer ro.Close()
    //         ds := merkledag.NewDAGService(blockservice.New(ro, offline.Exchange(ro)))
    //         nd, _ := ds.Get(ctx, root); f, _ := unixfile.NewUnixfsFile(ctx, ds, nd)
    //         files.WriteTo(f, out)
    final ro = blockstore.openReadOnly(s.car);
    try {
      final ds =
          merkledag.newDagService(blockservice.new$(ro, offline.exchange(ro)));
      final root = ro.roots().single;
      final f = await file.newUnixfsFile(s.ctx, ds, await ds.get(s.ctx, root));
      final out = s.path('extracted');
      files.writeTo(f, out);
      print('$out: the same files: ${same(out)}');
    } finally {
      ro.close();
    }

    print('\n== Kubo (high level)');
    //   CLI:  ipfs dag import folder.car && ipfs get <cid> -o out
    final r = await dag.dagImportFiles(other, s.ctx, [s.car]);
    final api = coreapi.newCoreApi(other);
    final out = s.path('extracted.kubo');
    files.writeTo(
        await api.unixfs().get(s.ctx, path.Path('/ipfs/${s.root}')), out);
    print(
        'imported ${r.blockCount} blocks; $out: the same files: ${same(out)}');
  } finally {
    await other.close();
    await s.close();
  }
}
