// CAR 11 · index: what not to do. The right way: 11_index.dart.
//
//   dart run example/car/11_index_mistakes.dart
import 'dart:typed_data';
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/car/v2/index.dart' as index;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/block_format.dart' as block_format;
import 'package:ipfs_ffi/go/cid.dart' as cid;


import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  try {
    final idx = car.generateIndexFromFile(s.car);
    final c = cid.newPrefixV1(0x55, 0x12).sum(Uint8List.fromList([1, 2, 3]));
    await mustFail('look up a CID that is not in the index without handling it',
        why: 'the index has no offset for it: IpfsNotFound',
        instead: 'handle IpfsNotFound (the block is not in this CAR)',
        action: () => index.getFirst(idx, c));

    // The index of another CAR, used to read this one.
    final otherCar = s.path('other.car');
    final rw = blockstore.openReadWrite(otherCar, [c]);
    await rw.put(
        s.ctx, block_format.Block(cid: c, rawData: Uint8List.fromList([1, 2, 3])));
    rw.finalize();
    final wrongIdx = car.generateIndexFromFile(otherCar);
    await silentlyWrong('read a CAR with an index built from another CAR',
        why: 'nothing ties an index to its CAR: the blocks of this CAR look '
            'absent (or offsets point at the wrong bytes)',
        instead: 'keep each .idx with its CAR (same name), or use a CARv2, '
            'which carries its own index', wrong: () async {
      final f = os.open(s.car);
      try {
        return await blockstore.ReadOnly(f, wrongIdx).has(s.ctx, s.root);
      } finally {
        f.close();
      }
    }, right: () async {
      final ro = blockstore.openReadOnly(s.car);
      try {
        return await ro.has(s.ctx, s.root);
      } finally {
        ro.close();
      }
    });

    // Not a misuse, a bug in go-car v2.17.0: AttachIndex opens the file with
    // O_APPEND and then writes with WriteAt, which Go refuses.
    final v2 = s.path('folder.v2.car');
    car.wrapV1File(s.car, v2);
    final r = car.openReader(v2);
    final at = r.header.indexOffset;
    r.close();
    await mustFail('attachIndex (broken upstream in go-car v2.17.0)',
        why: 'go-car opens with O_APPEND and writes with WriteAt; it fails for '
            'any file',
        instead: 'wrapV1File to get a CARv2 with its index, or keep the index '
            'in a .idx file (writeTo/readFrom)',
        action: () => car.attachIndex(v2, idx, at));
  } finally {
    await s.close();
  }
}
