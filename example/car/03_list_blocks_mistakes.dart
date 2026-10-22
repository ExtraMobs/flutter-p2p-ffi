// CAR 03 · list the blocks: what not to do. The right way:
// 03_list_blocks.dart.
//
//   dart run example/car/03_list_blocks_mistakes.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsEof, IpfsException;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    // a CAR cut in the middle (an interrupted download)
    final bytes = File(s.car).readAsBytesSync();
    final truncated = Uint8List.sublistView(bytes, 0, bytes.length - 5000);

    // The wrong loop: any exception means "done".
    String wrongLoop() {
      final br = car.BlockReader(truncated);
      var n = 0;
      while (true) {
        try {
          br.next();
          n++;
        } on IpfsException {
          return '$n blocks, no error'; // swallows the cut
        }
      }
    }

    // The right loop: only IpfsEof is the end; IpfsUnexpectedEof goes up.
    String rightLoop() {
      final br = car.BlockReader(truncated);
      var n = 0;
      try {
        while (true) {
          try {
            br.next();
            n++;
          } on IpfsEof {
            return '$n blocks';
          }
        }
      } on IpfsException catch (e) {
        return 'error after $n blocks: ${e.runtimeType}';
      }
    }

    await silentlyWrong('treat any IpfsException as the end of the reading',
        why: 'a truncated CAR gives IpfsUnexpectedEof, and the loop counts '
            'fewer blocks as if the file were complete',
        instead:
            'stop only on IpfsEof (Go\'s io.EOF); anything else is an error',
        wrong: wrongLoop,
        right: rightLoop);
  } finally {
    await s.close();
  }
}
