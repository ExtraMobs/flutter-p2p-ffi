// CAR 03 · list the blocks. Common mistakes: 03_list_blocks_mistakes.dart.
//
// What: go through the blocks of a CAR one at a time (CID and data), or
// through its CIDs only.
// When: processing a large CAR without loading all of it, copying blocks
// elsewhere, or finding out what it holds.
// Kubo: none (the import stores everything in the node). Layer: go-car.
//
//   dart run example/car/03_list_blocks.dart
import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/p2p_ffi.dart' show GolangEofException;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    print('== Low level (go-car)');
    // BlockReader: reads in order, from an open file (os.Open) or from bytes,
    // checking the hash of every block. The end is Go's io.EOF (GolangEofException); any
    // other error is a real error.
    //   Go:   br, _ := car.NewBlockReader(f)
    //         for { b, err := br.Next(); if errors.Is(err, io.EOF) { break } }
    final f = os.open(s.car);
    try {
      final br = car.BlockReader(f);
      print('version ${br.version}, roots ${br.roots}');
      var n = 0;
      while (true) {
        try {
          final b = br.next();
          print('  block ${n++}: ${b.cid} (${b.rawData!.length} bytes)');
        } on GolangEofException {
          break;
        }
      }
    } finally {
      f.close();
    }

    // Only the metadata, without bringing the data to Dart (where each block
    // is).
    //   Go:   meta, _ := br.SkipNext()
    final f2 = os.open(s.car);
    try {
      final meta = car.BlockReader(f2).skipNext();
      print('first block: ${meta.cid}, ${meta.size} bytes at byte '
          '${meta.offset}');
    } finally {
      f2.close();
    }

    // Only the CIDs, from the index of the read-only blockstore (a Stream).
    //   Go:   ro, _ := blockstore.OpenReadOnly(path); ch, _ := ro.AllKeysChan(ctx)
    final ro = blockstore.openReadOnly(s.car);
    try {
      final all = await ro.allKeysChan(s.ctx).toList();
      print('CIDs from the index: ${all.length}');
    } finally {
      ro.close();
    }
  } finally {
    await s.close();
  }
}
