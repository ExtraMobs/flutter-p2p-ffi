// CAR 02 · verify integrity. Common mistakes: 02_verify_mistakes.dart.
//
// What: check that every block of a CAR matches its CID (the hash of its
// bytes), without trusting whoever sent the file.
// When: for a CAR from the network, from a disk or from someone else.
// Kubo: `ipfs dag import` checks while importing (and rejects the whole CAR).
// Layer: go-car (`Inspect(true)`, and the `BlockReader`, which checks too).
//
//   dart run example/car/02_verify.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/go/car/v2.dart' as car;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/p2p_ffi.dart' show GolangException;

import 'sample.dart';

Future<void> main() async {
  final s = await Sample.open();
  // a CAR with one byte flipped near the end (in the data of a chunk)
  final bytes = File(s.car).readAsBytesSync();
  final corrupted = s.path('corrupted.car');
  File(corrupted).writeAsBytesSync(
      Uint8List.fromList(bytes)..[bytes.length - 100] ^= 0xff);
  final other = await s.newNode('other');
  try {
    print('== Low level (go-car)');
    // Inspect(true): reads everything and checks the hash of every block.
    //   Go:   st, err := r.Inspect(true)
    for (final (name, file) in [('intact', s.car), ('corrupted', corrupted)]) {
      final r = car.openReader(file);
      try {
        print('$name: ${r.inspect(true).blockCount} blocks checked');
      } on GolangException catch (e) {
        print('$name: rejected: ${brief(e)}');
      } finally {
        r.close();
      }
    }

    print('\n== Kubo (high level)');
    // The import checks every block and stores nothing of a corrupted CAR.
    //   CLI:  ipfs dag import corrupted.car
    try {
      await dag.dagImportFiles(other, s.ctx, [corrupted]);
    } on GolangException catch (e) {
      print('dagImport rejected it: ${brief(e)}');
    }
    final ok = await dag.dagImportFiles(other, s.ctx, [s.car]);
    print('dagImport of the intact one: ${ok.blockCount} blocks');
  } finally {
    await other.close();
    await s.close();
  }
}
