// CAR 04 · read a block: what not to do. The right way: 04_read_block.dart.
//
//   dart run example/car/04_read_block_mistakes.dart
import 'dart:io';
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/cid.dart' as cid;
import 'dart:typed_data';

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  final ro = blockstore.openReadOnly(s.car);
  try {
    // Asking for a block the CAR does not have.
    final missing =
        cid.newPrefixV1(0x55, 0x12).sum(Uint8List.fromList([1, 2, 3]));
    await mustFail(
        'get a CID that is not in the CAR without handling the error',
        why: 'the blockstore does not make the block up: IpfsNotFound',
        instead: 'call has() first, or handle IpfsNotFound',
        action: () => ro.get(s.ctx, missing));

    // The same content under another CID (CIDv0 vs CIDv1): go-car's index
    // compares multihashes, so it finds the block even with a different CID.
    final hello = File('${s.folder}/hello.txt').readAsBytesSync();
    final v0 = cid.newPrefixV0(0x12).sum(hello); // the CAR holds the raw CIDv1
    await silentlyWrong(
        'use the default has() to know whether the CAR holds exactly this CID',
        why: 'by default the index matches multihashes: a CIDv0 of the same '
            'content "exists" in a CAR that only holds the CIDv1',
        instead: 'open with car.useWholeCids(true) when the exact CID matters',
        wrong: () => ro.has(s.ctx, v0),
        right: () async {
          final exact =
              blockstore.openReadOnly(s.car, [car.useWholeCids(true)]);
          try {
            return await exact.has(s.ctx, v0);
          } finally {
            exact.close();
          }
        });
  } finally {
    ro.close();
    await s.close();
  }
}
