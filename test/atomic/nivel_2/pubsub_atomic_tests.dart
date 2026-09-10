// test/atomic/nivel_2/pubsub_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo libp2p_pubsub (transpiled_libp2p_pubsub).

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p_pubsub/transpiled_libp2p_pubsub.dart';

void main() {
  group('Bitmap [Atomic Audit]', () {
    test('byteLength - getter retorna tamanho em bytes do buffer backing do bitmap', () {
      final b = Bitmap(Uint8List(5));
      expect(b.byteLength, equals(5));
    });

    test('bytes - getter retorna lista Uint8List de bytes subjacente', () {
      final raw = Uint8List.fromList([1, 2, 3]);
      final b = Bitmap(raw);
      expect(b.bytes, equals(raw));
    });

    test('merge() - combina dois bitmaps com bitwise OR expandindo para o maior tamanho', () {
      final left = Bitmap.withOnesCount(3);
      final right = Bitmap(Uint8List(2))..set(10);
      final merged = Bitmap.merge(left, right);

      expect(merged.byteLength, equals(2));
      expect(merged.get(0), isTrue);
      expect(merged.get(1), isTrue);
      expect(merged.get(2), isTrue);
      expect(merged.get(10), isTrue);
      expect(merged.onesCount, equals(4));
    });

    test('isZero - getter indica se todos os bits do bitmap estao desativados', () {
      expect(Bitmap(Uint8List(4)).isZero, isTrue);
      expect(Bitmap(Uint8List.fromList([0, 0, 1])).isZero, isFalse);
    });

    test('onesCount - getter calcula a contagem total de bits ativos no bitmap', () {
      final b = Bitmap.withOnesCount(11);
      expect(b.onesCount, equals(11));

      final custom = Bitmap(Uint8List.fromList([0x05, 0x03]));
      expect(custom.onesCount, equals(4));
    });

    test('set() - ativa o bit no indice informado e expande o storage sob demanda', () {
      final b = Bitmap(Uint8List(1));
      b.set(2);
      expect(b.get(2), isTrue);

      b.set(18);
      expect(b.byteLength, greaterThan(1));
      expect(b.get(18), isTrue);
      expect(b.get(2), isTrue);
    });

    test('get() - consulta valor do bit no indice retornando falso se alem do comprimento', () {
      final b = Bitmap(Uint8List.fromList([0x02]));
      expect(b.get(1), isTrue);
      expect(b.get(0), isFalse);
      expect(b.get(100), isFalse);
    });

    test('clear() - redefine bit especificado para zero mantendo outros bits inalterados', () {
      final b = Bitmap.withOnesCount(5);
      b.clear(2);
      expect(b.get(2), isFalse);
      expect(b.get(0), isTrue);
      expect(b.get(1), isTrue);

      final prevLen = b.byteLength;
      b.clear(200);
      expect(b.byteLength, equals(prevLen));
    });

    test('and() - executa operacao bitwise AND inplace com outro bitmap', () {
      final a = Bitmap(Uint8List.fromList([0xF0, 0x0F]));
      final b = Bitmap(Uint8List.fromList([0xFF]));
      a.and(b);
      expect(a.bytes, equals(Uint8List.fromList([0xF0, 0x0F])));
    });

    test('or() - executa operacao bitwise OR inplace com outro bitmap', () {
      final a = Bitmap(Uint8List.fromList([0x0F]));
      final b = Bitmap(Uint8List.fromList([0xF0]));
      a.or(b);
      expect(a.bytes, equals(Uint8List.fromList([0xFF])));
    });

    test('xor() - executa operacao bitwise XOR inplace com outro bitmap', () {
      final a = Bitmap(Uint8List.fromList([0xFF]));
      final b = Bitmap(Uint8List.fromList([0x0F]));
      a.xor(b);
      expect(a.bytes, equals(Uint8List.fromList([0xF0])));
    });

    test('flip() - inverte todos os bits em todos os bytes do bitmap', () {
      final b = Bitmap(Uint8List.fromList([0x0F, 0xAA]));
      b.flip();
      expect(b.bytes, equals(Uint8List.fromList([0xF0, 0x55])));
    });
  });

  group('FirstSeenCache [Atomic Audit]', () {
    test('add() - insere id novo retornando true e falso para repeticoes', () {
      final cache = FirstSeenCache(const Duration(minutes: 5));
      addTearDown(cache.done);

      expect(cache.add('item1'), isTrue);
      expect(cache.add('item1'), isFalse);
      expect(cache.add('item2'), isTrue);
    });

    test('has() - consulta presenca do id sem estender seu prazo de expiracao', () {
      final cache = FirstSeenCache(const Duration(minutes: 5));
      addTearDown(cache.done);

      expect(cache.has('item1'), isFalse);
      cache.add('item1');
      expect(cache.has('item1'), isTrue);
    });

    test('done() - encerra timer de varredura periodica liberando recursos', () {
      final cache = FirstSeenCache(const Duration(minutes: 5));
      expect(() => cache.done(), returnsNormally);
    });
  });

  group('LastSeenCache [Atomic Audit]', () {
    test('add() - adiciona id novo retornando true e falso para id existente renovando TTL', () {
      final cache = LastSeenCache(const Duration(minutes: 5));
      addTearDown(cache.done);

      expect(cache.add('id1'), isTrue);
      expect(cache.add('id1'), isFalse);
      expect(cache.add('id2'), isTrue);
    });

    test('has() - consulta presenca do id renovando sua expiracao caso presente', () {
      final cache = LastSeenCache(const Duration(minutes: 5));
      addTearDown(cache.done);

      expect(cache.has('id1'), isFalse);
      cache.add('id1');
      expect(cache.has('id1'), isTrue);
    });

    test('done() - cancela o timer de sweep em background', () {
      final cache = LastSeenCache(const Duration(minutes: 5));
      expect(() => cache.done(), returnsNormally);
    });
  });

  group('TimeCache [Atomic Audit]', () {
    test('add() - adiciona id via interface TimeCache instanciada por factory', () {
      final tc = TimeCache(const Duration(minutes: 5));
      addTearDown(tc.done);

      expect(tc.add('msg1'), isTrue);
      expect(tc.add('msg1'), isFalse);
    });

    test('has() - verifica se id esta no TimeCache', () {
      final tc = TimeCache.withStrategy(
        TimeCacheStrategy.lastSeen,
        const Duration(minutes: 5),
      );
      addTearDown(tc.done);

      expect(tc.has('msg2'), isFalse);
      tc.add('msg2');
      expect(tc.has('msg2'), isTrue);
    });

    test('done() - finaliza TimeCache liberando o timer associado', () {
      final tc = TimeCache(const Duration(minutes: 5));
      expect(() => tc.done(), returnsNormally);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('startBackgroundSweep() - inicia timer periodico que executa sweep no mapa', () {
      final map = <String, DateTime>{};
      final timer = startBackgroundSweep(map, const Duration(milliseconds: 100));
      expect(timer.isActive, isTrue);
      timer.cancel();
      expect(timer.isActive, isFalse);
    });

    test('sweep() - remove entradas com expiracao anterior ao instante indicado', () {
      final now = DateTime(2026, 9, 8, 22);
      final map = {
        'expired1': now.subtract(const Duration(seconds: 1)),
        'expired2': now.subtract(const Duration(minutes: 1)),
        'valid': now.add(const Duration(seconds: 1)),
        'exact': now,
      };

      sweep(map, now);

      expect(map.containsKey('expired1'), isFalse);
      expect(map.containsKey('expired2'), isFalse);
      expect(map.containsKey('valid'), isTrue);
      expect(map.containsKey('exact'), isTrue);
    });
  });
}
