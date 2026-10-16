// CAR 05 · create from scratch: what not to do. The right way:
// 05_create_from_scratch.dart.
//
//   dart run example/car/05_create_from_scratch_mistakes.dart
import 'dart:typed_data';

import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/multiformats.dart' as mf;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    final prefix = mf.newPrefixV1(0x55, 0x12);
    final data = Uint8List.fromList([1]);
    final c = prefix.sum(data);

    // A Block whose CID does not match its bytes (a CID computed from other
    // data, or bytes changed after computing it).
    final bad = s.path('bad.car');
    await silentlyWrong(
        'build a Block with a CID that does not match its bytes',
        why: 'Put does not check the hash: the broken CAR is written, and only '
            'whoever checks it later finds out',
        instead: 'compute the CID from the exact bytes (prefix.sum(bytes)) '
            'right before the Put', wrong: () async {
      final rw = car.openReadWrite(bad, [c]);
      await rw.put(s.ctx, ipld.Block(cid: c, rawData: Uint8List.fromList([2])));
      rw.finalize();
      return 'Put accepted it';
    }, right: () {
      final r = car.openReader(bad);
      try {
        return '${r.inspect(true).blockCount} blocks';
      } on Object catch (e) {
        return 'inspect(true): ${brief(e)}';
      } finally {
        r.close();
      }
    });

    // Forgetting Finalize: the file has no valid CARv2 header.
    final unfinished = s.path('unfinished.car');
    final rw = car.openReadWrite(unfinished, [c]);
    await rw.put(s.ctx, ipld.Block(cid: c, rawData: data));
    await mustFail('read a CAR whose ReadWrite was never finalized',
        why: 'the header is only written by Finalize: the data offset is 0',
        instead: 'call finalize() (or discard() to give up) when done',
        action: () => car.openReader(unfinished).close());
    rw.discard();

    // Using the ReadWrite after Finalize.
    final done = car.openReadWrite(s.path('done.car'), [c]);
    await done.put(s.ctx, ipld.Block(cid: c, rawData: data));
    done.finalize();
    await mustFail('put into a ReadWrite after finalize()',
        why: 'Finalize closes the blockstore',
        instead: 'add every block before finalize(); to add more later, open '
            'the file again with openReadWrite (same roots)',
        action: () => done.put(s.ctx, ipld.Block(cid: c, rawData: data)));
  } finally {
    await s.close();
  }
}
