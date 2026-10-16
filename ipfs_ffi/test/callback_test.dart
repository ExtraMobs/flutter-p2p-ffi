// Callback sob demanda (0.17.0, WIRE.md "Callback"): o Go chama um callback
// de verdade, e os argumentos de cada invocação vêm ao Dart em lotes
// (batchSize); a função Dart roda um item por vez, e false ou uma exceção
// param o Go. A função 27 do host (CallbackBench) produz n itens sem nada do
// kubo no meio. Exige `dart run tool/build.dart`.
import 'dart:typed_data';

import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/multiformats.dart' as mf;
import 'package:ipfs_ffi/src/runtime.dart' show $W, $callCb, $callSync;
import 'package:test/test.dart';

/// Função 27: [n] itens de [size] bytes; devolve quantos o Go produziu.
Future<int> bench(int n, int size, dynamic Function(int i, Uint8List b) f,
    {int batch = 0}) async {
  final r = await $callCb(
      27,
      $W()
        ..u32(batch)
        ..i64(n)
        ..i64(size),
      (r) => f(r.i64(), r.bytes() ?? Uint8List(0)));
  return r.i64();
}

void main() {
  setUpAll(IpfsService.start);
  tearDownAll(IpfsService.stop);

  test('todos os itens, em ordem, com os argumentos', () async {
    for (final batch in [1, 7, 64, 1000]) {
      final seen = <int>[];
      final made = await bench(100, 3, (i, b) {
        seen.add(i);
        expect(b, hasLength(3));
      }, batch: batch);
      expect(made, 100);
      expect(seen, List.generate(100, (i) => i), reason: 'lote $batch');
    }
  });

  test('false para: lote 1 é exato; lote N, no máximo N-1 à frente', () async {
    for (final batch in [1, 8, 64]) {
      final seen = <int>[];
      final made = await bench(1000, 0, (i, _) {
        seen.add(i);
        return i < 10; // o 11º (índice 10) devolve false
      }, batch: batch);
      expect(seen, List.generate(11, (i) => i), reason: 'lote $batch');
      // o Go produziu o lote do índice 10 inteiro, e nada depois dele
      expect(made, ((10 ~/ batch) + 1) * batch, reason: 'lote $batch');
    }
  });

  test('a exceção do callback é a que a chamada lança', () async {
    final boom = StateError('do Dart');
    var calls = 0;
    await expectLater(
        bench(1000, 0, (i, _) {
          calls++;
          if (i == 5) throw boom;
        }, batch: 4),
        throwsA(same(boom)));
    expect(calls, 6); // nada depois da exceção
  });

  test('callback assíncrono: o próximo espera o anterior', () async {
    var running = 0, max = 0;
    final made = await bench(20, 0, (i, _) async {
      running++;
      max = running > max ? running : max;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      running--;
    }, batch: 8);
    expect(made, 20);
    expect(max, 1);
  });

  test('chamadas à ponte de dentro do callback', () async {
    var noops = 0;
    await bench(50, 0, (i, _) {
      $callSync(0); // Noop: síncrona, enquanto o Go espera o veredito
      noops++;
    }, batch: 1);
    expect(noops, 50);
  });

  test('index: forEach e getAll', () async {
    final idx = car.new$(mf.carMultihashIndexSorted);
    idx.load([
      for (var i = 0; i < 5; i++)
        car.Record$(
            cid: mf.newPrefixV1(0x55, 0x12).sum(Uint8List.fromList([i])),
            offset: 100 + i)
    ]);
    final it = idx.asIterableIndex()!;
    final offsets = <int>[];
    await it.forEach((mh, offset) {
      expect(mh, hasLength(34)); // sha2-256: 2 de prefixo + 32
      offsets.add(offset);
    });
    expect(offsets..sort(), [100, 101, 102, 103, 104]);

    final c = mf.newPrefixV1(0x55, 0x12).sum(Uint8List.fromList([3]));
    final got = <int>[];
    await idx.getAll(c, (offset) {
      got.add(offset);
      return true;
    });
    expect(got, [103]);
  });
}
