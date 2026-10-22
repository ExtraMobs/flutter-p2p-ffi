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

import 'sample.dart';
import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/car/v2/index.dart' as v2_index;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // Build it from a CARv1 (reads the whole file once).
    //   Go:   idx, _ := car.GenerateIndexFromFile(path)
    final idx = car.generateIndexFromFile(s.car);
    print(
        'codec: ${idx.codec() == multicodec.carMultihashIndexSorted ? 'car-multihash-index-sorted' : idx.codec()}');
    // Where a block is.
    //   Go:   off, _ := index.GetFirst(idx, c)
    print('the root block is at byte ${v2_index.getFirst(idx, s.root)}');

    // Save it next to the CAR and load it back.
    //   Go:   f, _ := os.Create(path + ".idx"); index.WriteTo(idx, f)
    //         idx2, _ := index.ReadFrom(f2)
    final file = '${s.car}.idx';
    final out = os.create(file);
    final n = v2_index.writeTo(idx, out);
    out.close();
    final input = os.open(file);
    final loaded = v2_index.readFrom(input);
    input.close();
    print('saved $n bytes to $file; loaded back: '
        'root at byte ${v2_index.getFirst(loaded, s.root)}');

    // Go through every entry with a callback (Go calls it; the Dart function
    // receives each multihash and offset, in batches).
    //   Go:   idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    var entries = 0;
    await idx.asIterableIndex()!.forEach((multihash, offset) => entries++);
    print('forEach: $entries entries');

    // A CARv2 carries its index: the read-only blockstore uses it directly.
    final v2 = s.path('folder.v2.car');
    car.wrapV1File(s.car, v2);
    final ro = blockstore.openReadOnly(v2);
    try {
      print('CARv2 with index: has the root: ${await ro.has(s.ctx, s.root)}');
    } finally {
      ro.close();
    }
  } finally {
    await s.close();
  }
}
