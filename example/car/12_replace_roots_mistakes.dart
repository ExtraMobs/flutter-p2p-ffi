// CAR 12 · replace the roots: what not to do. The right way:
// 12_replace_roots.dart.
//
//   dart run example/car/12_replace_roots_mistakes.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/multiformats.dart' as mf;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    final copy = s.path('copy.car');
    File(s.car).copySync(copy);

    await mustFail('replace the root with a CID of another size (CIDv0)',
        why: 'the header is rewritten in place: the new roots must take '
            'exactly the same bytes as the old ones',
        instead: 'use CIDs of the same version and codec, or rewrite the CAR '
            '(operation 14 copies the blocks into a new one)',
        action: () => car.replaceRootsInFile(
            copy, [mf.newPrefixV0(0x12).sum(Uint8List(0))]));

    bool rootsPresent(String file) {
      final r = car.openReader(file);
      try {
        return r.inspect(false).rootsPresent;
      } finally {
        r.close();
      }
    }

    // A same-size CID that is not in the CAR: go-car accepts it.
    final foreign = mf.newPrefixV1(0x70, 0x12).sum(Uint8List.fromList([7]));
    await silentlyWrong('replace the root with a CID that is not in the CAR',
        why: 'go-car does not check: the CAR now names a root nobody can '
            'resolve from it',
        instead: 'only use CIDs the CAR contains (operation 03 lists them); '
            'check rootsPresent afterwards',
        wrong: () {
          car.replaceRootsInFile(copy, [foreign]);
          return 'rootsPresent: ${rootsPresent(copy)}';
        },
        right: () => 'rootsPresent: ${rootsPresent(s.car)}');
  } finally {
    await s.close();
  }
}
