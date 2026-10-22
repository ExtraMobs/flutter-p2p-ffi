// CAR 13 · select a subset: what not to do. The right way:
// 13_select_subset.dart.
//
//   dart run example/car/13_select_subset_mistakes.dart

import 'sample.dart';
import 'package:ipfs_ffi/go/boxo/gateway.dart' as gateway;
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/boxo/fetcher/impl/blockservice.dart'
    as blockservice;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/car/v2/storage.dart' as storage;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/ipld_prime/node/basicnode.dart' as basicnode;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector/builder.dart'
    as builder;
import 'package:ipfs_ffi/go/codec_dagpb.dart' as codec_dagpb;
import 'package:ipfs_ffi/go/unixfsnode.dart' as unixfsnode;
import 'package:ipfs_ffi/go/ipld_prime/linking/cid.dart' as cid;

Future<void> main() async {
  final s = await Sample.open();
  try {
    // A UnixFS selector without the dag-pb prototype chooser.
    Future<int> select(List<car.Option> opts) async {
      final f = os.open(s.car);
      try {
        final ls = cid.defaultLinkSystem();
        unixfsnode.addUnixFsReificationToLinkSystem(ls);
        ls.setReadStorage(storage.openReadable(f));
        final out = s.path('out.car');
        await car.traverseToFile(s.ctx, ls, s.root,
            unixfsnode.unixFsPathSelector('hello.txt'), out, opts);
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
            'pass car.withTraversalPrototypeChooser(codec_dagpb.addSupportToChooser('
            'blockservice.defaultPrototypeChooser))',
        wrong: () async => '${await select([])} block(s)',
        right: () async => '${await select([
                  car.withTraversalPrototypeChooser(
                      codec_dagpb.addSupportToChooser(
                          blockservice.defaultPrototypeChooser))
                ])} block(s)');

    // exploreFields with a large batch: the `fields` object Go hands to the
    // callback is only valid during the call.
    final ssb = builder.SelectorSpecBuilder(basicnode.PrototypeAny());
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
        action: () => gateway.BlocksBackend(s.node.blocks).getCar(s.ctx,
            path.ImmutablePath('/ipns/example.org'), gateway.CarParams()));
  } finally {
    await s.close();
  }
}
