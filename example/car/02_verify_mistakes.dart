// CAR 02 · verify integrity: what not to do. The right way: 02_verify.dart.
//
//   dart run example/car/02_verify_mistakes.dart
import 'dart:io';
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'dart:typed_data';


import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    final bytes = File(s.car).readAsBytesSync();
    final corrupted = s.path('corrupted.car');
    File(corrupted).writeAsBytesSync(
        Uint8List.fromList(bytes)..[bytes.length - 100] ^= 0xff);

    int count(String file, bool check) {
      final r = car.openReader(file);
      try {
        return r.inspect(check).blockCount;
      } finally {
        r.close();
      }
    }

    // Counting the blocks is not verifying: Inspect(false) only reads the
    // structure.
    await silentlyWrong('trust a CAR because Inspect(false) counted its blocks',
        why:
            'Inspect(false) does not check the hashes: the flipped byte passes',
        instead: 'inspect(true), or the BlockReader / dagImport, which check',
        wrong: () => '${count(corrupted, false)} blocks, no error',
        right: () {
          try {
            return '${count(corrupted, true)} blocks';
          } on Object catch (e) {
            return 'error: ${brief(e)}';
          }
        });
  } finally {
    await s.close();
  }
}
