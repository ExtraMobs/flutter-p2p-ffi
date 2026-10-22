// CAR 14 · merge: what not to do. The right way: 14_merge.dart.
//
//   dart run example/car/14_merge_mistakes.dart
import 'dart:io';
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    // Merging into one of the sources (a CARv1, as `ipfs dag export` writes).
    final source = s.path('source.car');
    File(s.car).copySync(source);
    await mustFail('use one of the source CARs as the destination',
        why: 'openReadWrite on an existing file resumes it, and only a CARv2 '
            'it wrote itself (same roots) can be resumed; a v1 is refused',
        instead: 'write to a new file, then replace the source if needed',
        action: () => blockstore.openReadWrite(source, [s.root]).discard());
  } finally {
    await s.close();
  }
}
