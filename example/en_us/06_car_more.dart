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

import 'package:p2p_ffi/go/block_format.dart' as blocks;
import 'package:p2p_ffi/go/boxo/fetcher/impl/blockservice.dart'
    as fetcher_blockservice;
import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as car_blockstore;
import 'package:p2p_ffi/go/car/v2/index.dart' as index;
import 'package:p2p_ffi/go/car/v2/storage.dart' as storage;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/codec_dagpb.dart' as codec_dagpb;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/ipld_prime/datamodel.dart' as datamodel;
import 'package:p2p_ffi/go/ipld_prime/linking/cid.dart' as cidlink;
import 'package:p2p_ffi/go/ipld_prime/traversal/selector/parse.dart' as parse;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/go/unixfsnode.dart' as unixfsnode;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson06_');
  String at(String name) => '${tmp.path}/$name';
  try {
    final ctx = context.background();
    final s = await Sample.build(ctx);
    final v2 = at('folder.v2.car');
    await s.writeCar(ctx, v2);
    int count(String path) {
      final r = car.openReader(path);
      try {
        return r.inspect(true).blockCount;
      } finally {
        r.close();
      }
    }

    // 1. CARv2 → CARv1 and back. The v1 inside a v2 is the same bytes.
    //    Go:  car.ExtractV1File(v2, v1); car.WrapV1File(v1, again)
    final v1 = at('folder.v1.car');
    car.extractV1File(v2, v1);
    final again = at('folder.again.car');
    car.wrapV1File(v1, again);
    say('CARv2 ${File(v2).lengthSync()} bytes → CARv1 '
        '${File(v1).lengthSync()} bytes (version '
        '${car.readVersion(File(v1).readAsBytesSync())}) → CARv2 '
        '${File(again).lengthSync()} bytes');
    final r = car.openReader(again);
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
    final idx = car.generateIndexFromFile(v1);
    say('\nthe index of the v1: the root block is at byte '
        '${index.getFirst(idx, s.root)}');
    final idxFile = '$v1.idx';
    final w = os.create(idxFile);
    final n = index.writeTo(idx, w);
    w.close();
    final rd = os.open(idxFile);
    final loaded = index.readFrom(rd);
    rd.close();
    say('  saved $n bytes to ${idxFile.split('/').last}; loaded back: the '
        'root at byte ${index.getFirst(loaded, s.root)}');

    // 3. Replace the roots: here the CAR is made to start at data.bin
    //    (a CIDv0 like the folder, so the same size).
    //    Go:  car.ReplaceRootsInFile(path, []cid.Cid{dataBin})
    final folder = await s.dag.get(ctx, s.root);
    final dataBin = folder.links().first.cid!;
    final copy = at('copy.car');
    File(v2).copySync(copy);
    car.replaceRootsInFile(copy, [dataBin]);
    final rc = car.openReader(copy);
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
    final dagPbChooser = car.withTraversalPrototypeChooser(codec_dagpb
        .addSupportToChooser(fetcher_blockservice.defaultPrototypeChooser));
    Future<int> select(String name, datamodel.Node selector,
        [List<car.Option>? opts]) async {
      final f = os.open(v2);
      try {
        final ls = cidlink.defaultLinkSystem();
        unixfsnode.addUnixFsReificationToLinkSystem(ls);
        ls.setReadStorage(storage.openReadable(f));
        final out = at('$name.car');
        await car.traverseToFile(
            ctx, ls, s.root, selector, out, opts ?? [dagPbChooser]);
        return count(out);
      } finally {
        f.close();
      }
    }

    say('\nsubsets of the folder (${count(v2)} blocks):');
    say('  only the root block:  '
        '${await select('root', parse.commonSelectorMatchPoint)} block');
    say('  the path hello.txt:   '
        '${await select('hello', unixfsnode.unixFsPathSelector('hello.txt'))}'
        ' blocks (the folder, hello.txt)');
    say('  the path data.bin:    '
        '${await select('data', unixfsnode.unixFsPathSelector('data.bin'))}'
        ' blocks (the folder, data.bin, its 3 leaves)');
    say('  everything:           '
        '${await select('all', parse.commonSelectorExploreAllRecursively)}'
        ' blocks');

    // 5. Merge: a new CAR with the roots of both and the blocks of both.
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, append(rootsA, rootsB...))
    //         for each: br, _ := car.NewBlockReader(f); for { b, _ := br.Next(); rw.Put(ctx, b) }
    //         rw.Finalize()
    final note = Uint8List.fromList(utf8.encode('a second CAR'));
    final noteCid =
        cid.newPrefixV1(multicodec.raw, multicodec.sha2256).sum(note);
    final second = at('second.car');
    final sw = car_blockstore.openReadWrite(second, [noteCid]);
    await sw.put(ctx, blocks.Block(cid: noteCid, rawData: note));
    sw.finalize();
    final merged = at('merged.car');
    final rw = car_blockstore.openReadWrite(merged, [s.root, noteCid]);
    for (final source in [v1, second]) {
      final f = os.open(source);
      try {
        final br = car.BlockReader(f);
        final batch = <blocks.Block>[];
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
    final rm = car.openReader(merged);
    try {
      say('\nmerged: ${rm.inspect(true).blockCount} blocks, roots '
          '${rm.roots()}');
    } finally {
      rm.close();
    }

    say('\n== Common mistakes\n');
    await mistake('extracting the v1 of a CAR that already is v1',
        why: 'there is no v2 wrapper to remove',
        instead: 'check car.readVersion first',
        action: () => car.extractV1File(v1, at('x.car')));
    await mistake('wrapping a CAR that already is v2 (then reading it)',
        why: 'wrapV1File takes the v2 header as v1 data: it writes without a '
            'word and the file only fails when read',
        instead: 'check car.readVersion first; wrap only v1', action: () {
      final twice = at('twice.car');
      car.wrapV1File(v2, twice);
      count(twice);
    });
    await mistake('replacing the root with a CID of another size',
        why: 'the header is rewritten in place: the new roots must take the '
            'same bytes (here a CIDv1 over a CIDv0)',
        instead: 'a CID of the same version and codec, or copy the blocks '
            'into a new CAR (step 5) with the new roots',
        action: () => car.replaceRootsInFile(
            copy, [cid.newCidV1(multicodec.dagPb, dataBin.hash())]));
    await silentlyWrong('selecting by path without the dag-pb chooser',
        why: 'go-car decodes dag-pb as generic data, the UnixFS layer finds '
            'no "data.bin" in it, and the walk stops at the root',
        instead: 'pass car.withTraversalPrototypeChooser(...) as in step 4',
        wrong: () async =>
            '${await select('nochooser', unixfsnode.unixFsPathSelector('data.bin'), [])} blocks',
        right: () async =>
            '${await select('chooser', unixfsnode.unixFsPathSelector('data.bin'))} blocks');
    await mistake('merging into one of the source CARs',
        why: 'openReadWrite on an existing file resumes it, and only a CARv2 '
            'it wrote itself can be resumed; a v1 is refused',
        instead: 'write to a new file, then replace the source if needed',
        action: () =>
            car_blockstore.openReadWrite(v1, [s.root, noteCid]).discard());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
