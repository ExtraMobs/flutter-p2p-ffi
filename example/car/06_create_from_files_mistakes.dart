// CAR 06 · create from files: what not to do. The right way:
// 06_create_from_files.dart.
//
//   dart run example/car/06_create_from_files_mistakes.dart
import 'dart:io';
import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'dart:typed_data';

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    // The CAR was written with a CIDv1 placeholder root (36 bytes), but the
    // DAG was built with CIDv0 (34 bytes): the header no longer fits.
    final copy = s.path('copy.car');
    File(s.car).copySync(copy); // its root is a CIDv1
    final v0 = cid.newPrefixV0(0x12).sum(Uint8List(0));
    await mustFail('replace the placeholder root with a CID of another size',
        why: 'ReplaceRootsInFile rewrites the header in place: the new roots '
            'must take exactly the same bytes',
        instead: 'make the placeholder with the same CID version (and codec) '
            'the importer will produce',
        action: () => car.replaceRootsInFile(copy, [v0]));
  } finally {
    await s.close();
  }
}
