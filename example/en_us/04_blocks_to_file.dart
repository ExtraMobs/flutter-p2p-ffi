// Lesson 04 · How do I read it back? And if a block is missing?
//
// Question: lesson 03 turned a folder into blocks under one CID. How do I get
// the bytes of a file back, how does `<folder-cid>/data.bin` find the file,
// and what happens when one of the blocks is not here?
//
// Answer: reading walks the DAG from the root: get the root node, follow its
// links, get each child, until the leaves; the file is the leaves in order.
// A name inside a folder is just a link with that name. Every "get" goes
// to the blockservice: it looks in the blockstore and, if the block is not
// there, asks the exchange. With the offline exchange there is nobody to ask,
// so a missing block is an error; only the blocks on the path you read are
// needed, the rest of the DAG can be absent.
//
// Needs: lesson 03 (the same stack: datastore → blockstore → offline exchange
// → blockservice → DAGService, and the importer to build the sample). To read
// a file the UnixFS reader also needs the DAGService, to fetch the children.
//
//   dart run example/en_us/04_blocks_to_file.dart
//
// Next question: "Can I take those blocks to another machine without a
// network?" → lesson 05 (CAR files). And "who would the exchange ask?" →
// lesson 16.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = go.context.background();

    // The stack and the sample of lesson 03: a folder with data.bin
    // (600 000 bytes, 3 leaves) and hello.txt (one block).
    final ds = go.ipfs.datastore.sync.mutexWrap(DatastoreMapDatastore());
    final bs = BoxoBlockstore(ds);
    final dag = go.ipfs.boxo.ipld.merkledag.newDagService(go
        .ipfs.boxo.blockservice
        .new$(bs, go.ipfs.boxo.exchange.offline.exchange(bs)));
    IpldFormatNode importBytes(List<int> data) =>
        go.ipfs.boxo.ipld.unixfs.importer.buildDagFromReader(
            dag,
            go.ipfs.boxo.chunker.newSizeSplitter(
                BytesBuffer(Uint8List.fromList(data)),
                go.ipfs.boxo.chunker.defaultBlockSize));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final dir = BoxoIpldUnixfsIoDirectory(dag);
    await dir.addChild(ctx, 'data.bin', importBytes(data));
    await dir.addChild(ctx, 'hello.txt', importBytes(utf8.encode('hello\n')));
    final folderNode = dir.getNode();
    await dag.add(ctx, folderNode);
    final root = folderNode.cid();
    say('the folder: $root');

    // 1. A name inside a folder is a link: get the folder node, find the
    //    link by name, get the node it points to. This is what resolving
    //    the path /ipfs/<root>/data.bin does.
    //    Go:  nd, _ := dag.Get(ctx, root)
    //         lnk, _, _ := nd.ResolveLink([]string{"data.bin"})
    Future<IpldFormatNode> resolve(String name) async {
      final folder = await dag.get(ctx, root);
      final link = folder.links().firstWhere((l) => l.name == name);
      return dag.get(ctx, link.cid!);
    }

    // 2. Reading a file: the UnixFS reader walks its tree and joins the
    //    leaves, getting each block through the DAGService as it goes.
    //    Go:  f, _ := unixfile.NewUnixfsFile(ctx, dag, nd)
    //         data, _ := io.ReadAll(files.ToFile(f))
    Future<Uint8List> read(String name) async {
      final f = await go.ipfs.boxo.ipld.unixfs.file
          .newUnixfsFile(ctx, dag, await resolve(name));
      return go.io.readAll(go.ipfs.boxo.files.toFile(f));
    }

    final back = await read('data.bin');
    say('\nread data.bin: ${back.length} bytes, the same as written: '
        '${_same(back, data)}');
    say('read hello.txt: "${utf8.decode(await read('hello.txt')).trim()}"');

    // 3. The blocks a read needs: the path from the root to the leaves.
    Future<void> walk(Cid c, String name, String indent) async {
      say('$indent$c  ${await bs.getSize(ctx, c)} bytes  $name');
      for (final l in await go.ipfs.ipldFormat.getLinks(ctx, dag, c)) {
        await walk(l.cid!, l.name.isEmpty ? '(leaf)' : l.name, '$indent  ');
      }
    }

    say('\nthe whole DAG, block by block:');
    await walk(root, '(folder)', '  ');

    // 4. Take away one leaf of data.bin, as if it never arrived.
    final dataNode = await resolve('data.bin');
    final leaf = dataNode.links()[1].cid!;
    final saved = await bs.get(ctx, leaf);
    await bs.deleteBlock(ctx, leaf);
    say('\ndeleted the 2nd leaf of data.bin: $leaf');
    say('  hello.txt still reads (another branch): '
        '"${utf8.decode(await read('hello.txt')).trim()}"');
    await mistake('reading data.bin with a leaf missing',
        why: 'the blockstore does not have the block and the offline '
            'exchange has nobody to ask',
        instead: 'bring the block (a CAR, lesson 05) or use an exchange that '
            'fetches from peers (bitswap, lesson 16)',
        action: () => read('data.bin'));

    // 5. Put the block back (here, the copy saved above): it reads again.
    //    The block came from anywhere; its CID proves it is the right one.
    final again = leaf.prefix().sum(saved.rawData!).equals(leaf);
    await bs.put(ctx, saved);
    say('put the leaf back (its bytes hash to its CID: $again): '
        'data.bin reads ${(await read('data.bin')).length} bytes');

    say('\n== Common mistakes\n');
    final never = go.ipfs.cid
        .newPrefixV1(go.multiformats.multicodec.enums.raw,
            go.multiformats.multihash.consts.sha2256)
        .sum(utf8.encode('never stored'));
    await mistake('getting a CID that was never stored',
        why: 'offline, "not here" is final: there is no one else to ask',
        instead: 'check bs.has(ctx, c) first, or go online (lesson 16)',
        action: () => dag.get(ctx, never));
  } finally {
    await P2pService.stop();
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
