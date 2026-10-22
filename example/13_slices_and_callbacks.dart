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

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsEof, IpfsService;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:ipfs_ffi/multiformats.dart' as mf;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex13_');
  final repoPath = '${tmp.path}/repo';

  // Service, plugins and a new repo: the same as example 09.
  await IpfsService.start();
  kubo.PluginLoader('')
    ..initialize()
    ..inject();
  final cfg = kubo
      .initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')]));
  kubo.profiles['test']!.transform(cfg);
  kubo.init(repoPath, cfg);
  final ctx = go.background();
  final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));

  try {
    // A directory with two files in the node (CIDv1: the chunks become raw blocks).
    final dir = Directory('${tmp.path}/folder')..createSync();
    File('${dir.path}/hi.txt').writeAsStringSync('hi\n');
    File('${dir.path}/big.bin').writeAsBytesSync(
        Uint8List.fromList(List.generate(600000, (i) => i * 7 % 251)));
    final p = await kubo.newCoreApi(n).unixfs().add(
        ctx,
        boxo.newSerialFile(dir.path, false, go.stat(dir.path)),
        [kubo.unixfs.cidVersion(1)]);
    final root = mf.Cid(p.value.substring('/ipfs/'.length));
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
    final backend = boxo.BlocksBackend(n.blocks);
    for (final (name, range) in [
      ('whole', null),
      ('100 bytes', boxo.DagByteRange(from: 0, to: 99)),
    ]) {
      final (_, rc) = await backend.getCar(
          ctx,
          boxo.ImmutablePath('/ipfs/$root/big.bin'),
          boxo.CarParams(scope: boxo.dagScopeEntity, range: range));
      final out = '${tmp.path}/gateway.car';
      final f = go.create(out);
      go.copy(f, rc);
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
    final ls = ipld.defaultLinkSystem();
    ipld.addUnixFsReificationToLinkSystem(ls);
    ls.setReadStorage(ipld.Adapter()..wrapped = n.blockstore);
    final hi = '${tmp.path}/hi.car';
    await car
        .traverseToFile(ctx, ls, root, ipld.unixFsPathSelector('hi.txt'), hi, [
      car.withTraversalPrototypeChooser(
          ipld.addSupportToChooser(boxo.defaultPrototypeChooser))
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
    final ssb = ipld.SelectorSpecBuilder(ipld.PrototypeAny());
    final links = await ssb.exploreFields((f) async {
      f.insert(
          'Links',
          ssb.exploreAll(await ssb.exploreFields((g) {
            g.insert('Hash', ssb.matcher());
          })));
    });
    final plain = ipld.defaultLinkSystem()
      ..setReadStorage(ipld.Adapter()..wrapped = n.blockstore);
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
