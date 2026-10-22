// CAR 10 · convert v1/v2: what not to do. The right way:
// 10_convert_v1_v2.dart.
//
//   dart run example/car/10_convert_v1_v2_mistakes.dart

import 'sample.dart';
import 'package:p2p_ffi/go/car/v2.dart' as car;

Future<void> main() async {
  final s = await Sample.open();
  try {
    await mustFail('extract the v1 of a CAR that already is v1',
        why: 'there is no v2 wrapper to remove',
        instead: 'check the version first (car.readVersion, operation 01)',
        action: () => car.extractV1File(s.car, s.path('x.car')));

    // Wrapping a v2 is accepted, but the result is broken: the error only
    // shows up when someone reads it.
    final v2 = s.path('folder.v2.car');
    car.wrapV1File(s.car, v2);
    await mustFail('wrap again a CAR that already is v2 (and read the result)',
        why: 'wrapV1File treats the v2 header as v1 data: the file is written '
            'without complaint and only fails when read',
        instead: 'check the version first; wrap only v1', action: () {
      final twice = s.path('twice.car');
      car.wrapV1File(v2, twice);
      final r = car.openReader(twice);
      try {
        r.inspect(true);
      } finally {
        r.close();
      }
    });
  } finally {
    await s.close();
  }
}
