// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Tests for lib/src/partialmessages/bitmap.dart. go-libp2p-pubsub's own
// bitmap.go has no test file upstream, so these exercise the documented
// contract of each method directly (get/set/clear, and/or/xor/flip,
// onesCount/isZero, merge, and the growth-on-set fix documented in
// bitmap.dart's header).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p_pubsub/transpiled_libp2p_pubsub.dart';

void main() {
  test('withOnesCount creates a bitmap with exactly n bits set', () {
    final b = Bitmap.withOnesCount(10);
    expect(b.onesCount, equals(10));
    for (var i = 0; i < 10; i++) {
      expect(b.get(i), isTrue, reason: 'bit $i should be set');
    }
    expect(b.get(10), isFalse);
  });

  test(
    'set grows the backing storage and stays visible to the same object',
    () {
      final b = Bitmap(Uint8List(1));
      expect(b.byteLength, equals(1));

      b.set(20); // Beyond the first byte -- must grow.
      expect(b.byteLength, greaterThan(1));
      expect(b.get(20), isTrue);
      // Growth must not disturb bits already set in the original byte.
      b.set(3);
      expect(b.get(3), isTrue);
      expect(b.get(20), isTrue);
    },
  );

  test(
    'growth is the documented Dart correction to upstream slice-value semantics',
    () {
      final bytes = Uint8List(1);
      final bitmap = Bitmap(bytes)..set(20);

      // The original fixed-length view remains one byte, while the Bitmap owns
      // the grown replacement. This makes the intentional divergence explicit.
      expect(bytes.length, equals(1));
      expect(bitmap.byteLength, equals(3));
      expect(bitmap.get(20), isTrue);
    },
  );

  test('clear unsets a bit; a no-op beyond current length', () {
    final b = Bitmap.withOnesCount(4);
    b.clear(1);
    expect(b.get(1), isFalse);
    expect(b.get(0), isTrue);
    expect(b.get(2), isTrue);

    // Clearing beyond current length must not throw or grow.
    final before = b.byteLength;
    b.clear(100);
    expect(b.byteLength, equals(before));
  });

  test('get beyond current length is false, not an error', () {
    final b = Bitmap(Uint8List(1));
    expect(b.get(1000), isFalse);
  });

  test('and/or/xor operate up to the shorter length', () {
    final a = Bitmap(Uint8List.fromList([0xF0, 0x0F]));
    final b = Bitmap(Uint8List.fromList([0xFF]));

    final andResult = Bitmap(Uint8List.fromList(a.bytes))..and(b);
    expect(andResult.bytes, equals(Uint8List.fromList([0xF0, 0x0F])));

    final orResult = Bitmap(Uint8List.fromList([0x0F]))
      ..or(Bitmap(Uint8List.fromList([0xF0])));
    expect(orResult.bytes, equals(Uint8List.fromList([0xFF])));

    final xorResult = Bitmap(Uint8List.fromList([0xFF]))
      ..xor(Bitmap(Uint8List.fromList([0x0F])));
    expect(xorResult.bytes, equals(Uint8List.fromList([0xF0])));
  });

  test('flip inverts every bit', () {
    final b = Bitmap(Uint8List.fromList([0x0F, 0x00]))..flip();
    expect(b.bytes, equals(Uint8List.fromList([0xF0, 0xFF])));
  });

  test('isZero is true only when every byte is zero', () {
    expect(Bitmap(Uint8List(4)).isZero, isTrue);
    expect(Bitmap(Uint8List.fromList([0, 0, 1, 0])).isZero, isFalse);
  });

  test('merge ORs two bitmaps together, sized to the larger', () {
    final left = Bitmap.withOnesCount(3); // bits 0,1,2
    final right = Bitmap(Uint8List(2))..set(10);

    final merged = Bitmap.merge(left, right);
    expect(merged.byteLength, equals(2));
    expect(merged.get(0), isTrue);
    expect(merged.get(1), isTrue);
    expect(merged.get(2), isTrue);
    expect(merged.get(10), isTrue);
    expect(merged.onesCount, equals(4));
  });
}
