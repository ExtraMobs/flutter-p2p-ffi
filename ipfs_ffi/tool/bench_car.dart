// Vazão (MB/s) do go-car pela ponte (0.16.0): `dart run tool/bench_car.dart
// [MiB]` (exige `dart run tool/build.dart`; padrão 64 MiB por rodada). Sem nó:
// cada operação mede os bytes que atravessam a ponte (Dart → Go no put, Go →
// Dart no next/get/readAll) contra o que fica só no Go (inspect) e o disco
// direto do Dart (piso). Blocos de 256 KiB (vazão) e de 4 KiB (custo por
// chamada).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException, IpfsService;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/multiformats.dart' as mf;

Future<void> main(List<String> args) async {
  final mib = args.isEmpty ? 64 : int.parse(args.first);
  final tmp = Directory.systemTemp.createTempSync('bench_car_');
  await IpfsService.start();
  final ctx = go.background();
  final prefix = mf.newPrefixV1(0x55, 0x12); // raw, sha2-256
  final rnd = Random(1);
  try {
    for (final blockSize in [256 * 1024, 4 * 1024]) {
      final count = mib * 1024 * 1024 ~/ blockSize;
      final total = count * blockSize;
      print('\n== $count blocos de ${blockSize ~/ 1024} KiB '
          '(${total ~/ (1024 * 1024)} MiB)');
      final datas = [
        for (var i = 0; i < count; i++)
          Uint8List.fromList(List.generate(blockSize, (_) => rnd.nextInt(256)))
      ];

      Future<T> run<T>(String what, Future<T> Function() f) async {
        final sw = Stopwatch()..start();
        final r = await f();
        sw.stop();
        final s = sw.elapsedMicroseconds / 1e6;
        final mbs = total / (1024 * 1024) / s;
        final us = sw.elapsedMicroseconds / count;
        print('${what.padRight(48)} ${mbs.toStringAsFixed(1).padLeft(8)} MB/s'
            '  ${us.toStringAsFixed(1).padLeft(8)} µs/bloco');
        return r;
      }

      // Dart → Go: os bytes de cada bloco vão ao host
      final cids = await run('Prefix.sum (CID, Dart → Go)',
          () async => [for (final d in datas) prefix.sum(d)]);
      final file = '${tmp.path}/b$blockSize.car';
      final rw = car.openReadWrite(file, [cids.first]);
      await run('ReadWrite.put, um por chamada (Dart → Go)', () async {
        for (var i = 0; i < count; i++) {
          await rw.put(ctx, ipld.Block(cid: cids[i], rawData: datas[i]));
        }
      });
      rw.finalize();
      final file2 = '${tmp.path}/m$blockSize.car';
      final rw2 = car.openReadWrite(file2, [cids.first]);
      await run('ReadWrite.putMany, 64 por chamada (Dart → Go)', () async {
        for (var i = 0; i < count; i += 64) {
          await rw2.putMany(ctx, [
            for (var j = i; j < min(i + 64, count); j++)
              ipld.Block(cid: cids[j], rawData: datas[j])
          ]);
        }
      });
      rw2.finalize();

      // só no Go: lê e confere o hash de cada bloco, nada atravessa
      await run('Reader.inspect(true) (só no Go)', () async {
        final r = car.openReader(file);
        r.inspect(true);
        r.close();
      });

      // Go → Dart: os bytes de cada bloco voltam
      await run('BlockReader.next (Go → Dart)', () async {
        final f = go.open(file);
        final br = car.BlockReader(f);
        var n = 0;
        while (true) {
          try {
            n += br.next().rawData!.length;
          } on IpfsException catch (e) {
            if (e.message != 'EOF') rethrow;
            break;
          }
        }
        f.close();
        if (n != total) throw StateError('leu $n de $total');
      });
      final ro = car.openReadOnly(file);
      await run('ReadOnly.get por CID (Go → Dart)', () async {
        for (final c in cids) {
          await ro.get(ctx, c);
        }
      });
      ro.close();
      await run('io.ReadAll do arquivo, uma chamada (Go → Dart)', () async {
        final f = go.open(file);
        go.readAll(f);
        f.close();
      });
      await run('File.readAsBytesSync (Dart puro, piso)',
          () async => File(file).readAsBytesSync());
    }
  } finally {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
