// CAR 11 · build, save and query an index. Common mistakes:
// 11_index_mistakes.dart.
//
// What: the index maps each block (by multihash) to its offset in the CAR,
// so a block can be read without scanning the file.
// When: serving blocks from large CARs; keeping a `.idx` next to a CARv1, or
// using the index a CARv2 already carries.
// Kubo: none. Layer: go-car.
//
// Known upstream bug: go-car v2.17.0's AttachIndex always fails (it opens the
// file with O_APPEND and writes with WriteAt, which Go refuses). To get a CAR
// with its index inside, use wrapV1File (operation 10).
//
//   dart run example/car/11_index.dart
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/multiformats.dart' as mf;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // Build it from a CARv1 (reads the whole file once).
    //   Go:   idx, _ := car.GenerateIndexFromFile(path)
    final idx = car.generateIndexFromFile(s.car);
    print(
        'codec: ${idx.codec() == mf.carMultihashIndexSorted ? 'car-multihash-index-sorted' : idx.codec()}');
    // Where a block is.
    //   Go:   off, _ := index.GetFirst(idx, c)
    print('the root block is at byte ${car.getFirst(idx, s.root)}');

    // Save it next to the CAR and load it back.
    //   Go:   f, _ := os.Create(path + ".idx"); index.WriteTo(idx, f)
    //         idx2, _ := index.ReadFrom(f2)
    final file = '${s.car}.idx';
    final out = go.create(file);
    final n = car.writeTo(idx, out);
    out.close();
    final input = go.open(file);
    final loaded = car.readFrom(input);
    input.close();
    print('saved $n bytes to $file; loaded back: '
        'root at byte ${car.getFirst(loaded, s.root)}');

    // Go through every entry with a callback (Go calls it; the Dart function
    // receives each multihash and offset, in batches).
    //   Go:   idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    var entries = 0;
    await idx.asIterableIndex()!.forEach((multihash, offset) => entries++);
    print('forEach: $entries entries');

    // A CARv2 carries its index: the read-only blockstore uses it directly.
    final v2 = s.path('folder.v2.car');
    car.wrapV1File(s.car, v2);
    final ro = car.openReadOnly(v2);
    try {
      print('CARv2 with index: has the root: ${await ro.has(s.ctx, s.root)}');
    } finally {
      ro.close();
    }
  } finally {
    await s.close();
  }
}
