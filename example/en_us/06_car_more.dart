// Lesson 06 · What else can I do with a CAR?
//
// Question: lesson 05 wrote and read a CAR. What are CARv1 and CARv2, what is
// the index for, can I change the roots, keep only part of the DAG, or join
// two CARs?
//
// Answer:
//   - CARv1 is the plain format: header (roots) + blocks. It is what
//     `ipfs dag export` writes and what gateways send. Reading one block
//     means scanning the file.
//   - CARv2 wraps a CARv1 (byte for byte) between a small header and an
//     index: CID → offset, so a block is found without scanning. The
//     read-write blockstore of lesson 05 writes CARv2.
//   - The roots live in the header; they can be rewritten in place if the
//     new CIDs take the same bytes.
//   - A subset is a walk of the DAG with an IPLD selector ("this path",
//     "only the root", "everything") written as a new CAR.
//   - Merging is copying the blocks of each CAR into a new one, with the
//     roots of all of them.
//
// Needs: lesson 05 (a CAR of the sample). The selector walk also needs a
// LinkSystem (go-ipld-prime's way to load blocks by link) reading from the
// CAR, the UnixFS layer (so a selector can walk by file names) and the
// dag-pb prototype chooser (so dag-pb blocks are decoded as UnixFS nodes).
//
//   dart run example/en_us/06_car_more.dart
//
// Next question: "Doing all of this by hand is a lot of stack; does an IPFS
// node give me the stack ready, on disk?" → lesson 07.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson06_');
  String at(String name) => '${tmp.path}/$name';
  try {
    final ctx = go.context.background();
    final s = await Sample.build(ctx);
    final v2 = at('folder.v2.car');
    await s.writeCar(ctx, v2);
    int count(String path) {
      final r = go.ipld.car.v2.openReader(path);
      try {
        return r.inspect(true).blockCount;
      } finally {
        r.close();
      }
    }

    // 1. CARv2 → CARv1 and back. The v1 inside a v2 is the same bytes.
    //    Go:  car.ExtractV1File(v2, v1); car.WrapV1File(v1, again)
    final v1 = at('folder.v1.car');
    go.ipld.car.v2.extractV1File(v2, v1);
    final again = at('folder.again.car');
    go.ipld.car.v2.wrapV1File(v1, again);
    say('CARv2 ${File(v2).lengthSync()} bytes → CARv1 '
        '${File(v1).lengthSync()} bytes (version '
        '${go.ipld.car.v2.readVersion(File(v1).readAsBytesSync())}) → CARv2 '
        '${File(again).lengthSync()} bytes');
    final r = go.ipld.car.v2.openReader(again);
    try {
      final h = r.header;
      say('  the v2 header: the v1 data at ${h.dataOffset}..'
          '${h.dataOffset + h.dataSize}, the index at ${h.indexOffset}');
    } finally {
      r.close();
    }

    // 2. The index: where each block starts. Built from a v1 (one scan),
    //    saved next to it, loaded back.
    //    Go:  idx, _ := car.GenerateIndexFromFile(v1)
    //         off, _ := index.GetFirst(idx, root)
    //         index.WriteTo(idx, f); idx2, _ := index.ReadFrom(f2)
    final idx = go.ipld.car.v2.generateIndexFromFile(v1);
    say('\nthe index of the v1: the root block is at byte '
        '${go.ipld.car.v2.index.getFirst(idx, s.root)}');
    final idxFile = '$v1.idx';
    final w = go.os.create(idxFile);
    final n = go.ipld.car.v2.index.writeTo(idx, w);
    w.close();
    final rd = go.os.open(idxFile);
    final loaded = go.ipld.car.v2.index.readFrom(rd);
    rd.close();
    say('  saved $n bytes to ${idxFile.split('/').last}; loaded back: the '
        'root at byte ${go.ipld.car.v2.index.getFirst(loaded, s.root)}');

    // 3. Replace the roots: here the CAR is made to start at data.bin
    //    (a CIDv0 like the folder, so the same size).
    //    Go:  car.ReplaceRootsInFile(path, []cid.Cid{dataBin})
    final folder = await s.dag.get(ctx, s.root);
    final dataBin = folder.links().first.cid!;
    final copy = at('copy.car');
    File(v2).copySync(copy);
    go.ipld.car.v2.replaceRootsInFile(copy, [dataBin]);
    final rc = go.ipld.car.v2.openReader(copy);
    try {
      say('\nroots replaced: ${rc.roots()} (in the CAR: '
          '${rc.inspect(false).rootsPresent})');
    } finally {
      rc.close();
    }

    // 4. A subset: walk the DAG with a selector and write what it visits.
    //    Go:  ls := cidlink.DefaultLinkSystem()
    //         unixfsnode.AddUnixFSReificationToLinkSystem(&ls)
    //         src, _ := storage.OpenReadable(f); ls.SetReadStorage(src)
    //         car.TraverseToFile(ctx, &ls, root, selector, out,
    //             car.WithTraversalPrototypeChooser(
    //                 dagpb.AddSupportToChooser(bsfetcher.DefaultPrototypeChooser)))
    final dagPbChooser = go.ipld.car.v2.options.withTraversalPrototypeChooser(
        go.ipld.codecDagpb.addSupportToChooser(
            go.ipfs.boxo.fetcher.impl.blockservice.defaultPrototypeChooser));
    Future<int> select(String name, IpldPrimeDatamodelNode selector,
        [List<CarV2Option>? opts]) async {
      final f = go.os.open(v2);
      try {
        final ls = go.ipld.ipldPrime.linking.cid.defaultLinkSystem();
        go.ipfs.unixfsnode.addUnixFsReificationToLinkSystem(ls);
        ls.setReadStorage(go.ipld.car.v2.storage.openReadable(f));
        final out = at('$name.car');
        await go.ipld.car.v2.traverseToFile(
            ctx, ls, s.root, selector, out, opts ?? [dagPbChooser]);
        return count(out);
      } finally {
        f.close();
      }
    }

    say('\nsubsets of the folder (${count(v2)} blocks):');
    say('  only the root block:  '
        '${await select('root', go.ipld.ipldPrime.traversal.selector.parse.commonSelectorMatchPoint)} block');
    say('  the path hello.txt:   '
        '${await select('hello', go.ipfs.unixfsnode.unixFsPathSelector('hello.txt'))}'
        ' blocks (the folder, hello.txt)');
    say('  the path data.bin:    '
        '${await select('data', go.ipfs.unixfsnode.unixFsPathSelector('data.bin'))}'
        ' blocks (the folder, data.bin, its 3 leaves)');
    say('  everything:           '
        '${await select('all', go.ipld.ipldPrime.traversal.selector.parse.commonSelectorExploreAllRecursively)}'
        ' blocks');

    // 5. Merge: a new CAR with the roots of both and the blocks of both.
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, append(rootsA, rootsB...))
    //         for each: br, _ := car.NewBlockReader(f); for { b, _ := br.Next(); rw.Put(ctx, b) }
    //         rw.Finalize()
    final note = Uint8List.fromList(utf8.encode('a second CAR'));
    final noteCid = go.ipfs.cid
        .newPrefixV1(go.multiformats.multicodec.enums.raw,
            go.multiformats.multihash.consts.sha2256)
        .sum(note);
    final second = at('second.car');
    final sw = go.ipld.car.v2.blockstore.openReadWrite(second, [noteCid]);
    await sw.put(ctx, BlockFormatBlock(cid: noteCid, rawData: note));
    sw.finalize();
    final merged = at('merged.car');
    final rw =
        go.ipld.car.v2.blockstore.openReadWrite(merged, [s.root, noteCid]);
    for (final source in [v1, second]) {
      final f = go.os.open(source);
      try {
        final br = CarV2BlockReader(f);
        final batch = <BlockFormatBlock>[];
        while (true) {
          try {
            batch.add(br.next());
          } on GolangEofException {
            break;
          }
        }
        await rw.putMany(ctx, batch);
      } finally {
        f.close();
      }
    }
    rw.finalize();
    final rm = go.ipld.car.v2.openReader(merged);
    try {
      say('\nmerged: ${rm.inspect(true).blockCount} blocks, roots '
          '${rm.roots()}');
    } finally {
      rm.close();
    }

    say('\n== Common mistakes\n');
    await mistake('extracting the v1 of a CAR that already is v1',
        why: 'there is no v2 wrapper to remove',
        instead: 'check go.ipld.car.v2.readVersion first',
        action: () => go.ipld.car.v2.extractV1File(v1, at('x.car')));
    await mistake('wrapping a CAR that already is v2 (then reading it)',
        why: 'wrapV1File takes the v2 header as v1 data: it writes without a '
            'word and the file only fails when read',
        instead: 'check go.ipld.car.v2.readVersion first; wrap only v1',
        action: () {
      final twice = at('twice.car');
      go.ipld.car.v2.wrapV1File(v2, twice);
      count(twice);
    });
    await mistake('replacing the root with a CID of another size',
        why: 'the header is rewritten in place: the new roots must take the '
            'same bytes (here a CIDv1 over a CIDv0)',
        instead: 'a CID of the same version and codec, or copy the blocks '
            'into a new CAR (step 5) with the new roots',
        action: () => go.ipld.car.v2.replaceRootsInFile(copy, [
              go.ipfs.cid.newCidV1(
                  go.multiformats.multicodec.enums.dagPb, dataBin.hash())
            ]));
    await silentlyWrong('selecting by path without the dag-pb chooser',
        why: 'go-car decodes dag-pb as generic data, the UnixFS layer finds '
            'no "data.bin" in it, and the walk stops at the root',
        instead:
            'pass go.ipld.car.v2.withTraversalPrototypeChooser(...) as in step 4',
        wrong: () async =>
            '${await select('nochooser', go.ipfs.unixfsnode.unixFsPathSelector('data.bin'), [])} blocks',
        right: () async =>
            '${await select('chooser', go.ipfs.unixfsnode.unixFsPathSelector('data.bin'))} blocks');
    await mistake('merging into one of the source CARs',
        why: 'openReadWrite on an existing file resumes it, and only a CARv2 '
            'it wrote itself can be resumed; a v1 is refused',
        instead: 'write to a new file, then replace the source if needed',
        action: () => go.ipld.car.v2.blockstore
            .openReadWrite(v1, [s.root, noteCid]).discard());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
