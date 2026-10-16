// CAR 01 · inspect. Common mistakes: 01_inspect_mistakes.dart.
//
// What: read the version, the roots and what a CAR file holds, without
// importing it into any node.
// When: before importing a CAR you received, or to learn the size and the
// block types of a stored CAR.
// Kubo: none; `ipfs dag import` only reads a CAR by importing it.
// Layer: go-car.
//
//   dart run example/car/01_inspect.dart
import 'dart:io';

import 'package:ipfs_ffi/car.dart' as car;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // Open: the Reader maps the file; always close it.
    //   Go:   r, _ := car.OpenReader(path); defer r.Close()
    final r = car.openReader(s.car);
    try {
      print('version: CARv${r.version}');
      print('roots: ${r.roots()}');
      // What is inside. With true it also checks the hash of every block
      // (operation 02); here it only counts.
      //   Go:   st, _ := r.Inspect(false)
      final st = r.inspect(false);
      print('blocks: ${st.blockCount}; by codec ${st.codecCounts} '
          '(0x70 dag-pb, 0x55 raw); by hash ${st.mhTypeCounts} (0x12 sha2-256)');
      print('block sizes: ${st.minBlockLength} to ${st.maxBlockLength} bytes '
          '(average ${st.avgBlockLength})');
      print('the roots are in the CAR: ${st.rootsPresent}');
    } finally {
      r.close();
    }

    // Only the version, from the first bytes (without opening the whole file).
    //   Go:   v, _ := car.ReadVersion(f)
    final head = File(s.car).openSync();
    try {
      print('version from the first 512 bytes: '
          '${car.readVersion(head.readSync(512))}');
    } finally {
      head.closeSync();
    }

    // A CARv2 has a header saying where the data and the index are.
    final v2 = s.path('folder.v2.car');
    car.wrapV1File(s.car, v2); // operation 10
    final r2 = car.openReader(v2);
    try {
      final h = r2.header;
      print('CARv2: data at ${h.dataOffset}..${h.dataOffset + h.dataSize}, '
          'index at ${h.indexOffset} (has an index: ${h.hasIndex()})');
    } finally {
      r2.close();
    }
  } finally {
    await s.close();
  }
}
