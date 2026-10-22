// CAR 12 · replace the roots. Common mistakes: 12_replace_roots_mistakes.dart.
//
// What: change the root CIDs written in a CAR's header, in place, without
// rewriting the blocks.
// When: the root was only known after writing (operation 06), or the CAR
// should point at a sub-DAG it already contains.
// Kubo: none. Layer: go-car.
//
//   dart run example/car/12_replace_roots.dart
import 'dart:io';
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/cid.dart' as cid;


import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // The new root: the `sub` folder, which the CAR already contains (a
    // CIDv1 dag-pb, the same size as the old root).
    final (sub, _) =
        await s.api.resolvePath(s.ctx, path.Path('/ipfs/${s.root}/sub'));
    final subCid = cid.Cid(sub.value.substring('/ipfs/'.length));

    final copy = s.path('copy.car');
    File(s.car).copySync(copy);
    //   Go:   car.ReplaceRootsInFile(path, []cid.Cid{sub})
    car.replaceRootsInFile(copy, [subCid]);
    final r = car.openReader(copy);
    try {
      final st = r.inspect(false);
      print('roots now: ${r.roots()} (in the CAR: ${st.rootsPresent})');
    } finally {
      r.close();
    }
  } finally {
    await s.close();
  }
}
