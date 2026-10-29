// Lesson 03 · How does a file become blocks?
//
// Question: a CID names some bytes (lesson 02), but a block is small (256 KiB
// by default, 1-2 MiB at most on the network). How does a 600 KB file, or a
// whole folder, get one CID?
//
// Answer: the file is cut into chunks; each chunk is a block (a leaf) with
// its own CID; a parent node lists the CIDs of the leaves; the CID of the
// parent names the whole file. Folders are one more node, which lists the
// CIDs of its files by name. That tree of nodes linked by CID is a DAG
// (a Merkle DAG: changing one byte changes the leaf, its parent, and so on
// up to the root). The format of files and folders is UnixFS, written in
// dag-pb nodes.
//
// Needs: lesson 02 (CID). And, technically, this stack, from the bottom up;
// each layer needs the one below it:
//
//   datastore     key → bytes. Here a map in memory; in a node (lesson 07)
//                 flatfs, leveldb or pebble on disk.
//   blockstore    CID → block, stored in the datastore.
//   exchange      where to get a block the blockstore does not have. Here
//                 offline: nowhere. In a node, bitswap (lesson 16).
//   blockservice  blockstore + exchange: "give me this CID", from here or
//                 from outside.
//   DAGService    blockservice + codecs: blocks become nodes with links.
//   chunker       cuts the bytes into chunks.
//   importer      chunks → leaves → parents, written into the DAGService.
//
//   dart run example/en_us/03_file_to_blocks.dart
//
// Next question: "How do I get my file back out of those blocks, and what
// if one of them is missing?" → lesson 04.
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = goContext.background();

    // 1. The stack, bottom-up.
    //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
    //         bs := blockstore.NewBlockstore(ds)
    //         bserv := blockservice.New(bs, offline.Exchange(bs))
    //         dag := merkledag.NewDAGService(bserv)
    final ds = goDatastore.sync.mutexWrap(DatastoreMapDatastore());
    final bs = BoxoBlockstore(ds);
    final bserv =
        goBoxo.blockservice.new$(bs, goBoxo.exchange.offline.exchange(bs));
    final dag = goBoxo.ipld.merkledag.newDagService(bserv);
    Future<int> blocksStored() => bs.allKeysChan(ctx).length;

    // 2. A file of 600 000 bytes, chunked at 256 KiB.
    //    Go:  nd, _ := importer.BuildDagFromReader(dag,
    //             chunker.NewSizeSplitter(bytes.NewBuffer(data), chunker.DefaultBlockSize))
    final chunk =
        goBoxo.chunker.defaultBlockSize; // the default chunk size of `ipfs add`
    IpldFormatNode importBytes(Uint8List data, [int? size]) =>
        goBoxo.ipld.unixfs.importer.buildDagFromReader(dag,
            goBoxo.chunker.newSizeSplitter(BytesBuffer(data), size ?? chunk));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final file = importBytes(data);
    say('a file of ${data.length} bytes → root ${file.cid()}');
    for (final l in file.links()) {
      say('  leaf ${l.cid}  ${l.size} bytes');
    }
    say('  ${file.links().length} leaves + 1 root = '
        '${await blocksStored()} blocks in the blockstore');
    // 262 158 = 262 144 bytes of data + 14 of UnixFS envelope: these
    // defaults (CIDv0, `Qm...`) wrap each leaf in a dag-pb node. With CIDv1
    // (`ipfs add --cid-version=1`, lesson 08) leaves are raw, exactly 262 144.
    say('  (a full leaf is 262 158 bytes: 262 144 of data + the dag-pb '
        'envelope of CIDv0)');

    // 3. Same chunk, same block: a file made of the same 256 KiB three times
    //    has three links to ONE leaf, stored once (deduplication for free).
    final repeated = Uint8List(3 * chunk)
      ..setAll(0, data.sublist(0, chunk))
      ..setAll(chunk, data.sublist(0, chunk))
      ..setAll(2 * chunk, data.sublist(0, chunk));
    final before = await blocksStored();
    final rep = importBytes(repeated);
    say('\n3 × the first chunk → root ${rep.cid()}');
    say('  links: ${rep.links().map((l) => l.cid).toSet().length} '
        'distinct of ${rep.links().length}; new blocks stored: '
        '${await blocksStored() - before} (the root; the leaf was already '
        'there, it is the first leaf of the file above)');

    // 4. The CID depends on how the file was cut: the same bytes with
    //    another chunk size are another DAG, with another root.
    final before128 = await blocksStored();
    final other = importBytes(data, 128 * 1024);
    say('\nthe same file at 128 KiB → root ${other.cid()} '
        '(${other.links().length} leaves)');
    say('  same bytes, same root? ${other.cid() == file.cid()}');
    // Its last leaf is the same 75 712 bytes as the last 256 KiB leaf
    // (600 000 = 2 × 256 KiB + 75 712 = 4 × 128 KiB + 75 712).
    final shared = other.links().last.cid == file.links().last.cid;
    say('  new blocks stored: ${await blocksStored() - before128} '
        '(5 leaves + root, but the last leaf is shared: $shared)');

    // 5. A folder: one more node, linking to its entries by name.
    //    Go:  dir, _ := uio.NewDirectory(dag)
    //         dir.AddChild(ctx, "data.bin", file); dir.AddChild(...)
    //         nd, _ := dir.GetNode(); dag.Add(ctx, nd)
    final dir = BoxoIpldUnixfsIoDirectory(dag);
    await dir.addChild(ctx, 'data.bin', file);
    await dir.addChild(ctx, 'repeated.bin', rep);
    final folder = dir.getNode();
    await dag.add(ctx, folder);
    say('\na folder → root ${folder.cid()}');
    for (final l in folder.links()) {
      say('  ${l.name.padRight(12)} ${l.cid}  ${l.size} bytes (with its '
          'tree)');
    }
    say('  blocks in the blockstore now: ${await blocksStored()}');
    say('\nthe folder CID names everything below it: change one byte of '
        'data.bin and its leaf, data.bin and the folder all get new CIDs.');
  } finally {
    await P2pService.stop();
  }
}
