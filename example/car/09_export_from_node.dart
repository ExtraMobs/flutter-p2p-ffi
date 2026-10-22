// CAR 09 · export a DAG from a node. Common mistakes:
// 09_export_from_node_mistakes.dart.
//
// What: write a whole DAG the node has (a file, a folder, an IPLD object) to
// a CAR.
// When: backing up or moving content between repos, handing it to someone,
// uploading it to a pinning service.
// Kubo: `ipfs dag export` (with `--local-only`, only what the repo has).
// Low level: boxo's gateway backend (`?format=car&dag-scope=all`, which also
// fetches from the network), or a selector over the node's blockstore
// (go-ipld-prime's bsadapter + go-car).
//
//   dart run example/car/09_export_from_node.dart

import 'sample.dart';
import 'package:ipfs_ffi/go/boxo/gateway.dart' as gateway;
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/ipld_prime/storage/bsadapter.dart' as bsadapter;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector/parse.dart' as parse;
import 'package:ipfs_ffi/go/ipld_prime/linking/cid.dart' as cid;
import 'package:ipfs_ffi/go/kubo/core/commands/dag.dart' as dag;

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Kubo (high level)');
    //   CLI:  ipfs dag export <cid> > out.car
    final out = s.path('export.car');
    await dag.dagExportFile(s.node, s.ctx, path.Path('/ipfs/${s.root}'), out);
    print('dagExportFile: ${blockCount(out)} blocks');

    print('\n== Low level (boxo gateway backend)');
    //   Go:   bb, _ := gateway.NewBlocksBackend(node.Blocks)
    //         _, rc, _ := bb.GetCAR(ctx, path, gateway.CarParams{Scope: gateway.DagScopeAll})
    //         io.Copy(f, rc)
    final (_, rc) = await gateway.BlocksBackend(s.node.blocks).getCar(
        s.ctx,
        path.ImmutablePath('/ipfs/${s.root}'),
        gateway.CarParams(scope: gateway.dagScopeAll));
    final viaGateway = s.path('gateway.car');
    final f = os.create(viaGateway);
    io.copy(f, rc);
    f.close();
    rc.close();
    print('gateway getCar: ${blockCount(viaGateway)} blocks');

    print('\n== Low level (selector over the blockstore, local blocks only)');
    //   Go:   ls := cidlink.DefaultLinkSystem()
    //         ls.SetReadStorage(&bsadapter.Adapter{Wrapped: node.Blockstore})
    //         car.TraverseToFile(ctx, &ls, root, selectorparse.CommonSelector_ExploreAllRecursively, out)
    final ls = cid.defaultLinkSystem()
      ..setReadStorage(bsadapter.Adapter()..wrapped = s.node.blockstore);
    final viaSelector = s.path('selector.car');
    await car.traverseToFile(s.ctx, ls, s.root,
        parse.commonSelectorExploreAllRecursively, viaSelector);
    print('traverseToFile: ${blockCount(viaSelector)} blocks');
  } finally {
    await s.close();
  }
}
