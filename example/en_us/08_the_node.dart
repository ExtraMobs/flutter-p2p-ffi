// Lesson 08 · What does the node build for me?
//
// Question: lesson 07 made a repo. What is a "node" on top of it, and how
// does it relate to the stack I built by hand in lessons 03-06?
//
// Answer: the node (kubo's IpfsNode) opens the repo and builds the whole
// stack from it, the same layers as lesson 03, on disk:
//   blockstore → n.blockstore (with a GC lock, lesson 09)
//   blockservice (blockstore + exchange) → n.blocks; the exchange is offline
//     here, bitswap when the node is online (lessons 16-17)
//   MFS, a mutable file tree over the DAG → n.filesRoot (lesson 10)
//   and, online only, the libp2p host, routing, pubsub (part C).
// The CoreAPI is the friendly face over all of that: `unixfs().add/get/ls`,
// `pin()`, `block()`, `dag()`, `name()`, `key()`... the same functions the
// `ipfs` command line calls inside.
//
// Needs: lesson 07 (an initialized repo, the plugins). Technically, an
// offline node needs only the repo; an online one also a libp2p host, which
// needs the identity and the addresses of the config.
//
//   dart run example/en_us/08_the_node.dart
//
// Next question: "I added a file without pinning it; will it stay?" → lesson 09.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/file.dart' as unixfs_file;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson08_');
  final ctx = context.background();
  try {
    // 1. A repo as in lesson 07, then the node on it.
    //    Go:  n, _ := core.NewNode(ctx, &node.BuildCfg{Repo: r, Online: false})
    //         api, _ := coreapi.NewCoreAPI(n)
    loadPlugins();
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    fsrepo.init('${tmp.path}/repo', cfg);
    final n = await core.newNode(ctx,
        node.BuildCfg(repo: fsrepo.open('${tmp.path}/repo'), online: false));
    final api = coreapi.newCoreApi(n);
    say('an offline node on ${tmp.path}/repo');

    // 2. add: the importer of lesson 03, with kubo's defaults (CIDv0,
    //    256 KiB chunks), into the node's blockstore. The same bytes give
    //    the same CID as the sample built by hand.
    //    Go:  p, _ := api.Unixfs().Add(ctx, files.NewBytesFile(data))
    final s = await Sample.build(ctx);
    final byHand = (await s.dag.get(ctx, s.root)).links().first.cid!;
    final p = await api.unixfs().add(ctx, files.newBytesFile(s.data));
    say('\nadd data.bin through the node: $p');
    say('  the same CID as data.bin in lesson 03: ${p.value == '/ipfs/$byHand'}');

    // CIDv1 changes the defaults: raw leaves, a `bafy...` root.
    final v1 = await api
        .unixfs()
        .add(ctx, files.newBytesFile(s.data), [options.unixfs.cidVersion(1)]);
    final v1Root = cid.decode(v1.value.substring('/ipfs/'.length));
    final leaves = await api.unixfs().ls(ctx, v1).toList();
    say('with CIDv1: $v1');
    say('  leaves: ${leaves.map((e) => e.size).join(', ')} bytes, codec of a '
        'leaf 0x${leaves.first.cid!.type().toRadixString(16)} (raw: '
        '${leaves.first.cid!.type() == multicodec.raw}), root codec 0x'
        '${v1Root.type().toRadixString(16)} (dag-pb)');

    // 3. get and ls through the CoreAPI.
    //    Go:  nd, _ := api.Unixfs().Get(ctx, p); data, _ := io.ReadAll(files.ToFile(nd))
    final back = io.readAll(files.toFile(await api.unixfs().get(ctx, p)));
    say('\nget: ${back.length} bytes, the same: ${sameBytes(back, s.data)}');

    // 4. The node's own layers are the stack of lesson 03: a DAGService
    //    over n.blocks reads the same file, without the CoreAPI.
    //    Go:  dag := merkledag.NewDAGService(n.Blocks)
    final nodeDag = merkledag.newDagService(n.blocks);
    final f = await unixfs_file.newUnixfsFile(
        ctx, nodeDag, await nodeDag.get(ctx, byHand));
    say('read through n.blocks + merkledag: '
        '${io.readAll(files.toFile(f)).length} bytes');
    say('  in n.blockstore: ${await n.blockstore.has(ctx, byHand)}');

    // 5. CAR export and import with the node (lesson 05 with kubo doing the
    //    walk): `ipfs dag export` and `ipfs dag import`.
    final out = '${tmp.path}/data.car';
    await dag.dagExportFile(n, ctx, p, out);
    final other = await newNode(ctx, '${tmp.path}/other');
    final imported = await dag.dagImportFiles(other, ctx, [out]);
    final otherApi = coreapi.newCoreApi(other);
    final copied =
        io.readAll(files.toFile(await otherApi.unixfs().get(ctx, p)));
    say('\nexported $p to a CAR, imported into a second node: '
        '${imported.blockCount} blocks, the file reads '
        '${copied.length} bytes there');
    await other.close();

    say('\n== Common mistakes\n');
    final never = path.Path(
        '/ipfs/${cid.newPrefixV1(multicodec.raw, multicodec.sha2256).sum(utf8.encode('never added'))}');
    await mistake('getting, offline, a CID the node never had',
        why: 'an offline node has the offline exchange of lesson 04: nobody '
            'to ask',
        instead: 'add or import it first, or start the node online '
            '(lesson 17)',
        action: () async =>
            io.readAll(files.toFile(await api.unixfs().get(ctx, never))));
    await n.close();
    await mistake('using the CoreAPI after closing its node',
        why: 'close() shut the blockstore, the repo and everything built on '
            'them',
        instead: 'close the node last, when nothing uses it any more',
        action: () => api.unixfs().add(ctx, files.newBytesFile(s.data)));
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
