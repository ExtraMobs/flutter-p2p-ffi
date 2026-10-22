// Step 12: CAR files at the low level, Go's go-car
// (github.com/ipld/go-car/v2) called straight from Dart, in the `car` namespace.
// Example 07 uses `ipfs dag export/import` (the node reads and writes the whole
// CAR); here the file is opened and handled without a node: reading the version
// and the roots, counting the blocks, walking block by block, converting
// CARv1 ↔ CARv2, building and saving the index, creating a CAR block by block and
// slicing a DAG with an IPLD selector.
//
//   dart run example/12_car_low_level.dart
//
// As in examples 10 and 11, each step carries the same code in Go: the functions
// are go-car's (pkg.go.dev/github.com/ipld/go-car/v2), generated, in the same
// argument order.
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
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex12_');
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

  try {
    // The node only comes in to make a sample CAR: a directory with two files,
    // exported by `ipfs dag export` (example 07). From here down, nothing uses
    // the node.
    final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));
    final dir = Directory('${tmp.path}/folder')..createSync();
    File('${dir.path}/hi.txt').writeAsStringSync('hi, CAR\n');
    File('${dir.path}/big.bin').writeAsBytesSync(
        Uint8List.fromList(List.generate(400000, (i) => i * 7 % 251)));
    final p = await kubo.newCoreApi(n).unixfs().add(
        ctx,
        boxo.newSerialFile(dir.path, false, go.stat(dir.path)),
        [kubo.unixfs.cidVersion(1)]);
    final root = mf.Cid(p.value.substring('/ipfs/'.length));
    final v1 = '${tmp.path}/folder.car';
    await kubo.dagExportFile(n, ctx, p, v1);
    await n.close();
    print('0. ${File(v1).lengthSync()} bytes in $v1, root $root');

    // 1. Open and inspect. Inspect reads the whole file (and, with true, checks
    // each block's hash). The counters are maps from multicodec code (0x70
    // dag-pb, 0x55 raw, 0x12 sha2-256) to count.
    //   Go:   r, _ := car.OpenReader(path)
    //         st, _ := r.Inspect(true)
    final r = car.openReader(v1);
    final st = r.inspect(true);
    print('1. CARv${r.version}, roots ${r.roots()}, ${st.blockCount} blocks, '
        'codecs ${st.codecCounts}, largest block ${st.maxBlockLength} bytes');
    r.close();

    // 2. Block by block, the way `ipfs dag import` reads: the BlockReader takes
    // the bytes or an open file (os.Open). The end is Go's io.EOF, which arrives
    // as IpfsEof (like Go's errors.Is, it also works when wrapped).
    //   Go:   f, _ := os.Open(path)
    //         br, _ := car.NewBlockReader(f)
    //         for { b, err := br.Next(); if err == io.EOF { break } ... }
    final f = go.open(v1);
    final br = car.BlockReader(f);
    var i = 0;
    while (true) {
      try {
        final b = br.next();
        print('2. block ${i++}: ${b.cid} (${b.rawData!.length} bytes)');
      } on IpfsEof {
        break; // Go's io.EOF: done
      }
    }
    f.close();

    // 3. CARv1 → CARv2: v2 puts a header in front and the index at the end
    // (finding a block without reading the whole file). The Header is a Go
    // struct; its methods come along (hasIndex).
    //   Go:   car.WrapV1File(v1, v2)
    //         r2, _ := car.OpenReader(v2); r2.Header.HasIndex()
    final v2 = '${tmp.path}/folder.v2.car';
    car.wrapV1File(v1, v2);
    final r2 = car.openReader(v2);
    final h = r2.header;
    print('3. CARv${r2.version}: data at ${h.dataOffset}..'
        '${h.dataOffset + h.dataSize}, index at ${h.indexOffset} '
        '(hasIndex: ${h.hasIndex()})');
    r2.close();

    // 4. The index on its own: generate it from a CARv1, look up a block's
    // offset and save the bytes in a Go bytes.Buffer (any io.Writer works: an
    // os.File writes straight to disk).
    //   Go:   idx, _ := car.GenerateIndexFromFile(v1)
    //         off, _ := index.GetFirst(idx, root)
    //         var buf bytes.Buffer; index.WriteTo(idx, &buf)
    final idx = car.generateIndexFromFile(v1);
    final buf = go.Buffer(Uint8List(0));
    car.writeTo(idx, buf);
    print(
        '4. index ${idx.codec() == mf.carMultihashIndexSorted ? 'multihash-sorted' : idx.codec()}: '
        'root at byte ${car.getFirst(idx, root)}, ${buf.bytes().length} bytes serialized');

    // 5. A new CAR, block by block, without a node. The CID comes from the
    // prefix (version 1, raw codec, sha2-256) applied to the bytes; Go's Block
    // is built in Dart (cid + data). Finalize writes the index and closes.
    //   Go:   pre := cid.NewPrefixV1(cid.Raw, multihash.SHA2_256)
    //         c, _ := pre.Sum(data)
    //         rw, _ := blockstore.OpenReadWrite(path, []cid.Cid{c})
    //         rw.Put(ctx, blocks.NewBlockWithCid(data, c)); rw.Finalize()
    final pre = mf.newPrefixV1(0x55, 0x12);
    final created = '${tmp.path}/new.car';
    final datas = [
      for (final s in ['one', 'two', 'three']) Uint8List.fromList(s.codeUnits)
    ];
    final cids = [for (final d in datas) pre.sum(d)];
    final rw = car.openReadWrite(created, [cids.first]);
    for (var k = 0; k < datas.length; k++) {
      await rw.put(ctx, ipld.Block(cid: cids[k], rawData: datas[k]));
    }
    rw.finalize();
    // and read back through the read-only blockstore (it uses the index)
    final ro = car.openReadOnly(created);
    final keys = await ro.allKeysChan(ctx).toList();
    print('5. $created: ${keys.length} blocks, '
        '"${String.fromCharCodes((await ro.get(ctx, cids[1])).rawData!)}" by CID');
    ro.close();

    // 6. Slicing with an IPLD selector: the LinkSystem reads from the open CAR
    // and only what the selector reaches goes to the new file. MatchPoint = just
    // the root; ExploreAllRecursively = the whole DAG; or a selector in JSON.
    //   Go:   ls := cidlink.DefaultLinkSystem()
    //         src, _ := storage.OpenReadable(f); ls.SetReadStorage(src)
    //         car.TraverseToFile(ctx, &ls, root, selectorparse.CommonSelector_MatchPoint, out)
    final ls = ipld.defaultLinkSystem();
    final src = go.open(v1);
    ls.setReadStorage(car.openReadable(src));
    final rootOnly = '${tmp.path}/root.car';
    await car.traverseToFile(
        ctx, ls, root, ipld.commonSelectorMatchPoint, rootOnly);
    final whole = '${tmp.path}/whole.car';
    await car.traverseToFile(
        ctx, ls, root, ipld.commonSelectorExploreAllRecursively, whole);
    src.close();
    final a = car.openReader(rootOnly), b = car.openReader(whole);
    print('6. just the root: ${a.inspect(false).blockCount} block; '
        'the whole DAG: ${b.inspect(false).blockCount} blocks');
    a.close();
    b.close();
  } finally {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
