// Step 13: slicing a CAR straight from the node, and Go callbacks calling Dart.
// Example 12 slices from one CAR into another; here the slice comes from the
// node's own blocks, in two ways: boxo's gateway (by path, with scope and byte
// range, like an HTTP gateway's `?dag-scope=`) and any IPLD selector over the
// blockstore. On the way, the on-demand callback: Go functions that take a
// function (a CAR's index, the selector builder) take a Dart function.
//
//   dart run example/13_slices_and_callbacks.dart
//
// As in examples 10 to 12, each step carries the same code in Go.
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/go/boxo/gateway.dart' as gateway;
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/boxo/fetcher/impl/blockservice.dart' as blockservice;
import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/ipld_prime/storage/bsadapter.dart' as bsadapter;
import 'package:ipfs_ffi/go/ipld_prime/node/basicnode.dart' as basicnode;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector/builder.dart' as builder;
import 'package:ipfs_ffi/go/codec_dagpb.dart' as codec_dagpb;
import 'package:ipfs_ffi/go/unixfsnode.dart' as unixfsnode;
import 'package:ipfs_ffi/go/ipld_prime/linking/cid.dart' as cid;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/cid.dart' as go_cid;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsEof, IpfsService;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex13_');
  final repoPath = '${tmp.path}/repo';

  // Service, plugins and a new repo: the same as example 09.
  await IpfsService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final cfg = config
      .initWithIdentity(config.createIdentity(null, [options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  fsrepo.init(repoPath, cfg);
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));

  try {
    // A directory with two files in the node (CIDv1: the chunks become raw blocks).
    final dir = Directory('${tmp.path}/folder')..createSync();
    File('${dir.path}/hi.txt').writeAsStringSync('hi\n');
    File('${dir.path}/big.bin').writeAsBytesSync(
        Uint8List.fromList(List.generate(600000, (i) => i * 7 % 251)));
    final p = await coreapi.newCoreApi(n).unixfs().add(
        ctx,
        files.newSerialFile(dir.path, false, os.stat(dir.path)),
        [options.unixfs.cidVersion(1)]);
    final root = go_cid.Cid(p.value.substring('/ipfs/'.length));
    print('0. directory at $root');

    // 1. Boxo's gateway over the node: the CAR of a path. Scope `entity` = the
    // blocks that prove the path and the whole file; with a range, only the
    // chunks of the requested bytes. The CAR comes in an io.ReadCloser, copied
    // into a file (io.Copy). It fetches what is missing from the network, if the
    // node is online.
    //   Go:   bb, _ := gateway.NewBlocksBackend(node.Blocks)
    //         _, rc, _ := bb.GetCAR(ctx, path, gateway.CarParams{Scope: gateway.DagScopeEntity,
    //             Range: &gateway.DagByteRange{From: 0, To: &to}})
    //         f, _ := os.Create(out); io.Copy(f, rc)
    final backend = gateway.BlocksBackend(n.blocks);
    for (final (name, range) in [
      ('whole', null),
      ('100 bytes', gateway.DagByteRange(from: 0, to: 99)),
    ]) {
      final (_, rc) = await backend.getCar(
          ctx,
          path.ImmutablePath('/ipfs/$root/big.bin'),
          gateway.CarParams(scope: gateway.dagScopeEntity, range: range));
      final out = '${tmp.path}/gateway.car';
      final f = os.create(out);
      io.copy(f, rc);
      f.close();
      rc.close();
      print('1. gateway, big.bin $name: ${blocks(out)} blocks');
    }

    // 2. An IPLD selector over the node's local blockstore: bsadapter makes the
    // blockstore the storage of a LinkSystem. With the UnixFS layer, the
    // selector walks the directory's names; the gateway's prototype chooser
    // makes go-car decode typed dag-pb (without it, the directory has no
    // "hi.txt").
    //   Go:   ls := cidlink.DefaultLinkSystem()
    //         unixfsnode.AddUnixFSReificationToLinkSystem(&ls)
    //         ls.SetReadStorage(&bsadapter.Adapter{Wrapped: node.Blockstore})
    //         car.TraverseToFile(ctx, &ls, root, unixfsnode.UnixFSPathSelector("hi.txt"), out,
    //             car.WithTraversalPrototypeChooser(dagpb.AddSupportToChooser(bsfetcher.DefaultPrototypeChooser)))
    final ls = cid.defaultLinkSystem();
    unixfsnode.addUnixFsReificationToLinkSystem(ls);
    ls.setReadStorage(bsadapter.Adapter()..wrapped = n.blockstore);
    final hi = '${tmp.path}/hi.car';
    await car
        .traverseToFile(ctx, ls, root, unixfsnode.unixFsPathSelector('hi.txt'), hi, [
      car.withTraversalPrototypeChooser(
          codec_dagpb.addSupportToChooser(blockservice.defaultPrototypeChooser))
    ]);
    print(
        '2. UnixFS selector "hi.txt": ${blocks(hi)} blocks (the directory and the file)');

    // 3. The selector builder, an alternative to JSON. exploreFields takes a Go
    // function that builds the fields; in Dart, a Dart function: Go calls it and
    // waits for the answer (an on-demand callback, batch 1 here: `fields` is
    // only valid during the call).
    //   Go:   ssb := builder.NewSelectorSpecBuilder(basicnode.Prototype.Any)
    //         sel := ssb.ExploreFields(func(f builder.ExploreFieldsSpecBuilder) {
    //             f.Insert("Links", ssb.ExploreAll(ssb.ExploreFields(func(g ...) {
    //                 g.Insert("Hash", ssb.Matcher()) }))) })
    final ssb = builder.SelectorSpecBuilder(basicnode.PrototypeAny());
    final links = await ssb.exploreFields((f) async {
      f.insert(
          'Links',
          ssb.exploreAll(await ssb.exploreFields((g) {
            g.insert('Hash', ssb.matcher());
          })));
    });
    final plain = cid.defaultLinkSystem()
      ..setReadStorage(bsadapter.Adapter()..wrapped = n.blockstore);
    final children = '${tmp.path}/children.car';
    await car.traverseToFile(ctx, plain, root, links.node(), children);
    print('3. the root and its direct children: ${blocks(children)} blocks');

    // 4. A CAR's index, walked with a callback. Go sends the arguments in batches
    // (batchSize; default 1024, measured) and waits for Dart: false, or an
    // exception, stop Go. While forEach runs, the index is "in use" (isBusy, and
    // IpfsService.busy reports it): calling it from inside the callback may wait
    // on a lock Go holds; if it does, the host detects it and throws
    // IpfsDeadlockException instead of hanging.
    //   Go:   idx, _ := car.GenerateIndexFromFile(path)
    //         idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    final watch = IpfsService.busy
        .listen((c) => print('   (index ${c.busy ? 'in use' : 'free'})'));
    final idx = car.generateIndexFromFile(hi);
    var seen = 0;
    await idx.asIterableIndex()!.forEach((mh, offset) {
      seen++;
      print('4. entry: multihash of ${mh.length} bytes at byte $offset '
          '(isBusy: ${idx.isBusy})');
    });
    await Future<void>.delayed(
        Duration.zero); // the "free" notice arrives afterwards
    await watch.cancel();
    print('4. $seen entries');

    // 5. Go's known errors arrive as subclasses of IpfsException: the end of a
    // read is IpfsEof (Go's io.EOF).
    //   Go:   for { b, err := br.Next(); if errors.Is(err, io.EOF) { break } }
    final br = car.BlockReader(File(hi).readAsBytesSync());
    var read = 0;
    try {
      while (true) {
        br.next();
        read++;
      }
    } on IpfsEof {
      print('5. BlockReader: $read blocks, then IpfsEof');
    }
  } finally {
    await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}

/// How many blocks the CAR in [file] has (the Reader maps the file: close it).
int blocks(String file) {
  final r = car.openReader(file);
  try {
    return r.inspect(false).blockCount;
  } finally {
    r.close();
  }
}
