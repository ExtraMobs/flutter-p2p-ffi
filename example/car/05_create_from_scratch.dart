// CAR 05 · create a CAR from scratch, block by block. Common mistakes:
// 05_create_from_scratch_mistakes.dart.
//
// What: write your own blocks (bytes you produced) into a new CAR file.
// When: packaging data that did not come from IPFS (records, messages,
// objects) to hand to someone or to import later.
// Kubo: store IPLD objects in the node (`ipfs dag put`) and export them
// (`ipfs dag export`).
// Low level: go-car's read-write blockstore; each CID is computed in Go from
// the bytes, with no node at all.
//
//   dart run example/car/05_create_from_scratch.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:ipfs_ffi/multiformats.dart' as mf;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // The CID of each block: version 1, raw codec (0x55), sha2-256 (0x12).
    //   Go:   pre := cid.NewPrefixV1(cid.Raw, multihash.SHA2_256); c, _ := pre.Sum(data)
    final prefix = mf.newPrefixV1(0x55, 0x12);
    final records = [
      for (final r in ['first', 'second', 'third']) utf8.encode('record: $r')
    ];
    final cids = [for (final d in records) prefix.sum(d)];

    // The roots go in at open time; blocks are added with Put/PutMany and
    // Finalize writes the index and the CARv2 header.
    //   Go:   rw, _ := blockstore.OpenReadWrite(path, []cid.Cid{cids[0]})
    //         rw.Put(ctx, blocks.NewBlockWithCid(data, c)); rw.Finalize()
    final out = s.path('records.car');
    final rw = car.openReadWrite(out, [cids.first]);
    await rw.put(s.ctx, ipld.Block(cid: cids[0], rawData: records[0]));
    await rw.putMany(s.ctx, [
      for (var i = 1; i < records.length; i++)
        ipld.Block(cid: cids[i], rawData: records[i])
    ]);
    rw.finalize();
    final r = car.openReader(out);
    try {
      print('$out: CARv${r.version}, ${r.inspect(true).blockCount} blocks, '
          'root ${r.roots().single}');
    } finally {
      r.close();
    }

    print('\n== Kubo (high level)');
    // IPLD objects (DAG-JSON in, DAG-CBOR stored): the second links to the
    // first, and the export follows the link.
    //   CLI:  ipfs dag put <<< '{"n": 1}'; ipfs dag export <cid> > objects.car
    final first = await kubo.dagPut(
        s.api, s.ctx, Uint8List.fromList(utf8.encode('{"n": 1}')));
    final second = await kubo.dagPut(s.api, s.ctx,
        Uint8List.fromList(utf8.encode('{"n": 2, "prev": {"/": "$first"}}')));
    final objects = s.path('objects.car');
    await kubo.dagExportFile(
        s.node, s.ctx, boxo.Path('/ipfs/$second'), objects);
    print('$objects: ${blockCount(objects)} blocks (the object and the one it '
        'links to)');
  } finally {
    await s.close();
  }
}
