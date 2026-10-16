// CAR 13 · select a subset: what not to do. The right way:
// 13_select_subset.dart.
//
//   dart run example/car/13_select_subset_mistakes.dart
import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipld.dart' as ipld;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    // A UnixFS selector without the dag-pb prototype chooser.
    Future<int> select(List<car.Option> opts) async {
      final f = go.open(s.car);
      try {
        final ls = ipld.defaultLinkSystem();
        ipld.addUnixFsReificationToLinkSystem(ls);
        ls.setReadStorage(car.openReadable(f));
        final out = s.path('out.car');
        await car.traverseToFile(
            s.ctx, ls, s.root, ipld.unixFsPathSelector('hello.txt'), out, opts);
        return blockCount(out);
      } finally {
        f.close();
      }
    }

    await silentlyWrong(
        'select a file by name without the dag-pb prototype chooser',
        why: 'go-car then decodes dag-pb as generic data; the UnixFS layer '
            'does not recognize it, so the folder has no "hello.txt" and the '
            'walk stops at the root',
        instead:
            'pass car.withTraversalPrototypeChooser(ipld.addSupportToChooser('
            'boxo.defaultPrototypeChooser))',
        wrong: () async => '${await select([])} block(s)',
        right: () async => '${await select([
                  car.withTraversalPrototypeChooser(
                      ipld.addSupportToChooser(boxo.defaultPrototypeChooser))
                ])} block(s)');

    // exploreFields with a large batch: the `fields` object Go hands to the
    // callback is only valid during the call.
    final ssb = ipld.SelectorSpecBuilder(ipld.PrototypeAny());
    await mustFail('build a selector with exploreFields(batchSize: 1024)',
        why: 'with a batch, Go goes on before Dart runs the callback; the '
            'insert arrives after the builder finished: "panic: misuse"',
        instead: 'keep the default batch (1) for callbacks that receive Go '
            'objects',
        action: () => ssb.exploreFields((f) => f.insert('Links', ssb.matcher()),
            batchSize: 1024));

    // A mutable path in the gateway backend.
    await mustFail('getCar of an /ipns/ path',
        why: 'the gateway backend serves immutable content: the path must '
            'start with /ipfs/',
        instead: 'resolve the name first (api.name().resolve or '
            'api.resolvePath) and pass the /ipfs/ path',
        action: () => boxo.BlocksBackend(s.node.blocks).getCar(
            s.ctx, boxo.ImmutablePath('/ipns/example.org'), boxo.CarParams()));
  } finally {
    await s.close();
  }
}
