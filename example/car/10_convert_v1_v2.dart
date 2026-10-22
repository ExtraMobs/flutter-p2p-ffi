// CAR 10 · convert between CARv1 and CARv2. Common mistakes:
// 10_convert_v1_v2_mistakes.dart.
//
// What: CARv1 is header + blocks; CARv2 wraps the same CARv1 with a fixed
// header and adds an index at the end (finding a block without reading the
// whole file).
// When: v1 → v2 to serve blocks by CID from a large CAR; v2 → v1 for tools
// that only read v1 (`ipfs dag export` writes v1; `ipfs dag import` reads
// both).
// Kubo: none. Layer: go-car.
//
//   dart run example/car/10_convert_v1_v2.dart
import 'dart:io';
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/bytes.dart' as bytes;
import 'dart:typed_data';


import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // v1 → v2 (with an index).
    //   Go:   car.WrapV1File(v1, v2)
    final v2 = s.path('folder.v2.car');
    car.wrapV1File(s.car, v2);
    print('v1 ${File(s.car).lengthSync()} bytes → v2 ${File(v2).lengthSync()} '
        'bytes (version ${car.readVersion(File(v2).readAsBytesSync())})');

    // v2 → v1: the v1 inside comes back byte for byte.
    //   Go:   car.ExtractV1File(v2, v1)
    final back = s.path('folder.back.car');
    car.extractV1File(v2, back);
    print('v2 → v1, the same bytes as the original: '
        '${File(back).readAsBytesSync().toString() == File(s.car).readAsBytesSync().toString()}');

    // In memory: from bytes (an io.ReadSeeker) to a buffer (an io.Writer).
    //   Go:   var buf bytes.Buffer; car.WrapV1(bytes.NewReader(v1), &buf)
    final buf = bytes.Buffer(Uint8List(0));
    car.wrapV1(File(s.car).readAsBytesSync(), buf);
    print('wrapV1 in memory: ${buf.bytes().length} bytes, version '
        '${car.readVersion(buf.bytes())}');
  } finally {
    await s.close();
  }
}
