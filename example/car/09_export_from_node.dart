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
import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Kubo (high level)');
    //   CLI:  ipfs dag export <cid> > out.car
    final out = s.path('export.car');
    await kubo.dagExportFile(s.node, s.ctx, boxo.Path('/ipfs/${s.root}'), out);
    print('dagExportFile: ${blockCount(out)} blocks');

    print('\n== Low level (boxo gateway backend)');
    //   Go:   bb, _ := gateway.NewBlocksBackend(node.Blocks)
    //         _, rc, _ := bb.GetCAR(ctx, path, gateway.CarParams{Scope: gateway.DagScopeAll})
    //         io.Copy(f, rc)
    final (_, rc) = await boxo.BlocksBackend(s.node.blocks).getCar(
        s.ctx,
        boxo.ImmutablePath('/ipfs/${s.root}'),
        boxo.CarParams(scope: boxo.dagScopeAll));
    final viaGateway = s.path('gateway.car');
    final f = go.create(viaGateway);
    go.copy(f, rc);
    f.close();
    rc.close();
    print('gateway getCar: ${blockCount(viaGateway)} blocks');

    print('\n== Low level (selector over the blockstore, local blocks only)');
    //   Go:   ls := cidlink.DefaultLinkSystem()
    //         ls.SetReadStorage(&bsadapter.Adapter{Wrapped: node.Blockstore})
    //         car.TraverseToFile(ctx, &ls, root, selectorparse.CommonSelector_ExploreAllRecursively, out)
    final ls = ipld.defaultLinkSystem()
      ..setReadStorage(ipld.Adapter()..wrapped = s.node.blockstore);
    final viaSelector = s.path('selector.car');
    await car.traverseToFile(s.ctx, ls, s.root,
        ipld.commonSelectorExploreAllRecursively, viaSelector);
    print('traverseToFile: ${blockCount(viaSelector)} blocks');
  } finally {
    await s.close();
  }
}
