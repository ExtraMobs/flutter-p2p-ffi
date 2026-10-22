// CAR 06 · create a CAR from files on disk. Common mistakes:
// 06_create_from_files_mistakes.dart.
//
// What: turn a folder into a UnixFS DAG and write it as a CAR.
// When: publishing or sending files as a CAR (what the `ipfs-car` tool does).
// Kubo: add to the node and export (`ipfs add` + `ipfs dag export`).
// Low level, without a node: the CAR's own read-write blockstore becomes an
// offline block service and a DAG service; boxo's UnixFS importer chunks each
// file into it, and a UnixFS directory ties them together. The root is only
// known at the end, so the CAR opens with a placeholder root of the same
// size, replaced after Finalize.
//
//   dart run example/car/06_create_from_files.dart
import 'dart:io';
import 'package:ipfs_ffi/go/boxo/ipld/unixfs/io.dart' as io;
import 'package:ipfs_ffi/go/boxo/ipld/unixfs/importer.dart' as importer;
import 'package:ipfs_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:ipfs_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/boxo/chunker.dart' as chunker;
import 'package:ipfs_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/ipld_format.dart' as ipld_format;
import 'package:ipfs_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/cid.dart' as cid;
import 'dart:typed_data';


import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (boxo + go-car, no node)');
    // The importer defaults: CIDv0, dag-pb leaves, 256 KiB chunks. The
    // placeholder root is a CIDv0 too, so it has the same size as the real
    // one (ReplaceRootsInFile needs that).
    final placeholder = cid.newPrefixV0(0x12).sum(Uint8List(0));
    final out = s.path('files.car');
    //   Go:   rw, _ := blockstore.OpenReadWrite(out, []cid.Cid{placeholder})
    //         bs := blockservice.New(rw, offline.Exchange(rw))
    //         ds := merkledag.NewDAGService(bs)
    final rw = blockstore.openReadWrite(out, [placeholder]);
    final ds = merkledag.newDagService(blockservice.new$(rw, offline.exchange(rw)));

    // One file: chunked and written into the DAG service (the CAR).
    //   Go:   nd, _ := importer.BuildDagFromReader(ds, chunker.NewSizeSplitter(f, 262144))
    ipld_format.Node file(String path) {
      final f = os.open(path);
      try {
        return importer.buildDagFromReader(ds, chunker.newSizeSplitter(f, 262144));
      } finally {
        f.close();
      }
    }

    // A folder: a UnixFS directory with its children; the directory node is
    // added to the DAG service too.
    //   Go:   dir, _ := uio.NewDirectory(ds); dir.AddChild(ctx, name, nd)
    //         nd, _ := dir.GetNode(); ds.Add(ctx, nd)
    Future<ipld_format.Node> folder(String path) async {
      final dir = io.Directory(ds);
      final entries = Directory(path).listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final e in entries) {
        final name = e.uri.pathSegments.lastWhere((p) => p.isNotEmpty);
        await dir.addChild(
            s.ctx, name, e is Directory ? await folder(e.path) : file(e.path));
      }
      final node = dir.getNode();
      await ds.add(s.ctx, node);
      return node;
    }

    final root = (await folder(s.folder)).cid();
    rw.finalize();
    //   Go:   car.ReplaceRootsInFile(out, []cid.Cid{root})
    car.replaceRootsInFile(out, [root]);
    print('$out: ${blockCount(out)} blocks, root $root');

    print('\n== Kubo (high level)');
    // The same folder with the same parameters (CIDv0, dag-pb leaves, 256 KiB)
    // gives the same root.
    //   CLI:  ipfs add -r --chunker=size-262144 folder && ipfs dag export <cid>
    final p = await s.api
        .unixfs()
        .add(s.ctx, files.newSerialFile(s.folder, false, os.stat(s.folder)), [
      options.unixfs.cidVersion(0),
      options.unixfs.chunker('size-262144'),
    ]);
    final viaKubo = s.path('files.kubo.car');
    await dag.dagExportFile(s.node, s.ctx, p, viaKubo);
    print('$viaKubo: ${blockCount(viaKubo)} blocks, root '
        '${p.value.substring('/ipfs/'.length)}');
    print('same root both ways: ${p.value == '/ipfs/$root'}');
  } finally {
    await s.close();
  }
}
