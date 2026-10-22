// CAR 01 · inspect: what not to do. The right way: 01_inspect.dart. Each
// mistake below is made on purpose and the example prints the error Go
// returns.
//
//   dart run example/car/01_inspect_mistakes.dart
import 'dart:io';
import 'package:p2p_ffi/go/car/v2.dart' as car;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    // Opening as a CAR a file that is not one (a renamed file, a download
    // cut at the start, a JSON).
    final text = s.path('not_a_car.car');
    File(text).writeAsStringSync('{"this": "is not a CAR"}');
    await mustFail('open with openReader a file that is not a CAR',
        why: 'go-car checks the header and rejects the file',
        instead: 'handle the error: a CAR you receive may come from anywhere',
        action: () => car.openReader(text).close());

    // On Windows an open Reader keeps the file mapped: overwriting or
    // deleting it fails until the Reader is closed.
    if (Platform.isWindows) {
      final copy = s.path('copy.car');
      File(s.car).copySync(copy);
      final r = car.openReader(copy);
      await mustFail('overwrite a CAR while its Reader is still open',
          why: 'the file is mapped in the memory of the ipfs_host',
          instead: 'close the Reader (r.close(), in a finally) before '
              'touching the file',
          action: () => File(copy).writeAsStringSync('other content'));
      r.close();
    } else {
      print('(on linux overwriting an open CAR does not fail, but the Reader '
          'then reads the new file: the fix is the same, close it first)');
    }
  } finally {
    await s.close();
  }
}
