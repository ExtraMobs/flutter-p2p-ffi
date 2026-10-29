// Lesson 05 · How do I carry blocks without a network?
//
// Question: my blocks are in a blockstore (lessons 03-04). How do I send a
// whole DAG to another machine, or keep it as one file, without IPFS
// networking?
//
// Answer: a CAR file (Content-Addressed aRchive): a header naming the roots,
// then the blocks one after the other, each with its CID. A CAR is a
// blockstore in a file: written with the CAR's read-write blockstore, read
// with its read-only one, which plugs into the same stack of lesson 03 in
// place of the in-memory blockstore. Whoever receives it trusts nothing: each
// block is checked against its CID (lesson 02). It is what `ipfs dag export`
// writes, what gateways serve with `?format=car`, and what `ipfs dag import`
// reads.
//
// Needs: lessons 03-04 (the sample DAG and the stack). To write a CAR: the
// roots at open time (the CIDs the receiver should start from) and every
// block of the DAG. To extract files from it: a blockservice and a DAGService
// over the CAR (offline, so every block has to be in the CAR).
//
//   dart run example/en_us/05_car_files.dart
//
// Next question: "CARv1, CARv2, index, roots... and if I only want part of
// the DAG, or to join two CARs?" → lesson 06.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson05_');
  try {
    final ctx = goContext.background();
    final s = await Sample.build(ctx);
    say('the sample folder: ${s.root}');

    // 1. Which blocks: walk the DAG from the root, parent before children
    //    (the order `ipfs dag export` writes). Each Get by the CID of a link
    //    returns the block under that exact CID, codec included.
    Future<List<BlockFormatBlock>> dagBlocks(Cid c) async => [
          await s.store.get(ctx, c),
          for (final l in await goIpldFormat.getLinks(ctx, s.dag, c))
            ...await dagBlocks(l.cid!),
        ];

    // 2. Write: open the CAR with its roots, put the blocks, finalize.
    //    Finalize writes the header (CARv2) and an index (lesson 06).
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, []cid.Cid{root})
    //         rw.PutMany(ctx, blks); rw.Finalize()
    final out = '${tmp.path}/folder.car';
    Future<void> writeCar(String path, List<BlockFormatBlock> all) async {
      final rw = goCar.v2.blockstore.openReadWrite(path, [s.root]);
      await rw.putMany(ctx, all);
      rw.finalize();
    }

    final all = await dagBlocks(s.root);
    await writeCar(out, all);
    say('\nwrote $out: ${all.length} blocks, ${File(out).lengthSync()} bytes');

    // 3. Inspect: version, roots, how many blocks, are the roots inside.
    //    The Reader maps the file: always close it.
    //    Go:  r, _ := car.OpenReader(out); defer r.Close(); st, _ := r.Inspect(false)
    final r = goCar.v2.openReader(out);
    try {
      final st = r.inspect(false);
      say('CARv${r.version}, roots ${r.roots()}, ${st.blockCount} blocks '
          '(the roots are in it: ${st.rootsPresent})');
      say('  by codec ${st.codecCounts} (0x70 dag-pb), sizes '
          '${st.minBlockLength}..${st.maxBlockLength} bytes');
    } finally {
      r.close();
    }

    // 4. List the blocks in file order. The BlockReader checks the hash of
    //    each block as it reads; the end is Go's io.EOF.
    //    Go:  br, _ := car.NewBlockReader(f)
    //         for { b, err := br.Next(); if errors.Is(err, io.EOF) { break } }
    final f = goOs.open(out);
    try {
      final br = CarV2BlockReader(f);
      say('\nblocks in the file:');
      while (true) {
        try {
          final b = br.next();
          say('  ${b.cid}  ${b.rawData!.length} bytes');
        } on GolangEofException {
          break;
        }
      }
    } finally {
      f.close();
    }

    // 5. The CAR as a blockstore: Get one block by CID (through the index),
    //    and extract the files by putting it under the stack of lesson 04.
    //    Go:  ro, _ := blockstore.OpenReadOnly(out); defer ro.Close()
    //         dag := merkledag.NewDAGService(blockservice.New(ro, offline.Exchange(ro)))
    //         nd, _ := dag.Get(ctx, root); f, _ := unixfile.NewUnixfsFile(ctx, dag, nd)
    //         files.WriteTo(f, dir)
    Future<void> extract(String carPath, String dir) async {
      final ro = goCar.v2.blockstore.openReadOnly(carPath);
      try {
        final dag = goBoxo.ipld.merkledag.newDagService(
            goBoxo.blockservice.new$(ro, goBoxo.exchange.offline.exchange(ro)));
        final root = ro.roots().single;
        goBoxo.files.writeTo(
            await goBoxo.ipld.unixfs.file
                .newUnixfsFile(ctx, dag, await dag.get(ctx, root)),
            dir);
      } finally {
        ro.close();
      }
    }

    final ro = goCar.v2.blockstore.openReadOnly(out);
    try {
      final b = await ro.get(ctx, s.root);
      say('\nthe root block, read from the CAR: ${b.rawData!.length} bytes');
    } finally {
      ro.close();
    }
    final dir = '${tmp.path}/extracted';
    await extract(out, dir);
    final back = File('$dir/data.bin').readAsBytesSync();
    say('extracted to $dir: ${Directory(dir).listSync().length} entries; '
        'data.bin is the same: ${_same(back, s.data)}');

    say('\n== Common mistakes\n');
    final notCar = '${tmp.path}/not_a_car.car';
    File(notCar).writeAsStringSync('{"this": "is not a CAR"}');
    await mistake('opening a file that is not a CAR',
        why: 'go-car checks the header and rejects it',
        instead: 'handle the error: a CAR you receive may come from anywhere',
        action: () => goCar.v2.openReader(notCar).close());

    // One byte flipped near the end, in the data of a leaf.
    final good = File(out).readAsBytesSync();
    final corrupted = '${tmp.path}/corrupted.car';
    File(corrupted).writeAsBytesSync(
        Uint8List.fromList(good)..[good.length - 2000] ^= 0xff);
    String inspect(String path, bool check) {
      final r = goCar.v2.openReader(path);
      try {
        return '${r.inspect(check).blockCount} blocks, no error';
      } on GolangException catch (e) {
        return 'error: ${brief(e)}';
      } finally {
        r.close();
      }
    }

    await silentlyWrong('trusting a CAR because inspect(false) counted it',
        why: 'inspect(false) reads only the structure, not the hashes',
        instead: 'inspect(true), the BlockReader or `ipfs dag import`, which '
            'check every block',
        wrong: () => inspect(corrupted, false),
        right: () => inspect(corrupted, true));

    final unfinished = '${tmp.path}/unfinished.car';
    final rw = goCar.v2.blockstore.openReadWrite(unfinished, [s.root]);
    await rw.put(ctx, await s.store.get(ctx, s.root));
    await mistake('reading a CAR whose writer was never finalized',
        why: 'the header is only written by finalize()',
        instead: 'finalize() when done (or discard() to give up)',
        action: () => goCar.v2.openReader(unfinished).close());
    rw.discard();

    // Copying "every block of the blockstore" instead of walking the DAG.
    // A blockstore keys blocks by multihash only: AllKeysChan gives each
    // one back as a raw CIDv1, without the codec it was stored under.
    String rootsInside(String path) {
      final r = goCar.v2.openReader(path);
      try {
        final st = r.inspect(false);
        return 'roots in the CAR: ${st.rootsPresent}, codecs ${st.codecCounts}';
      } finally {
        r.close();
      }
    }

    final byKeys = '${tmp.path}/by_keys.car';
    await silentlyWrong('writing a CAR from blockstore.allKeysChan()',
        why: 'the blockstore keeps multihashes, not CIDs: every block comes '
            'back as raw (0x55), so the dag-pb root is not found',
        instead: 'walk the DAG from the root (step 1), or `ipfs dag export`',
        wrong: () async {
          await writeCar(byKeys, [
            await for (final c in s.store.allKeysChan(ctx))
              await s.store.get(ctx, c),
          ]);
          return rootsInside(byKeys);
        },
        right: () => rootsInside(out));

    // A CAR with the 2nd leaf of data.bin left out.
    final dataBin = (await s.dag.get(ctx, s.root)).links().first.cid!;
    final missing = (await s.dag.get(ctx, dataBin)).links()[1].cid!;
    final partial = '${tmp.path}/partial.car';
    await writeCar(partial, [
      for (final b in all)
        if (b.cid != missing) b,
    ]);
    await mistake('extracting the files of a partial CAR',
        why: 'offline, every block must be in the CAR; one is not',
        instead: 'check what the CAR has first (steps 3-4), or import it into '
            'a node that can fetch the rest (lesson 16)',
        action: () => extract(partial, '${tmp.path}/out'));
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
