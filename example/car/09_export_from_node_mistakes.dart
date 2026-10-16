// CAR 09 · export from a node: what not to do. The right way:
// 09_export_from_node.dart.
//
//   dart run example/car/09_export_from_node_mistakes.dart
import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  final other = await s.newNode('other');
  try {
    // A node that only has the root block of the folder (offline: it cannot
    // fetch the rest).
    final partial = s.path('partial.car');
    final ls = ipld.defaultLinkSystem()
      ..setReadStorage(ipld.Adapter()..wrapped = s.node.blockstore);
    await car.traverseToFile(
        s.ctx, ls, s.root, ipld.commonSelectorMatchPoint, partial);
    await kubo.dagImportFiles(other, s.ctx, [partial]);
    final path = boxo.Path('/ipfs/${s.root}');

    await mustFail('export a DAG the offline node does not have entirely',
        why: 'the export walks the whole DAG; a missing block with no '
            'network to fetch it from stops it',
        instead: 'bring the node online (it fetches what is missing), or '
            'export only what you have on purpose with localOnly',
        action: () => kubo.dagExport(other, s.ctx, path));

    await silentlyWrong(
        'use localOnly to "make the export work" and treat the CAR as complete',
        why: 'localOnly skips the missing blocks without a word: the CAR is '
            'partial and cannot be extracted',
        instead: 'use localOnly only when a partial CAR is what you want; '
            'check the result (operation 01) before sending it',
        wrong: () async =>
            '${cidsOf(await kubo.dagExport(other, s.ctx, path, localOnly: true)).length} block(s)',
        right: () async =>
            '${cidsOf(await kubo.dagExport(s.node, s.ctx, path)).length} block(s)');
  } finally {
    await other.close();
    await s.close();
  }
}
