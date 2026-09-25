// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:typed_data';

import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('integer conversion emits UTF8 or replacement for invalid scalars', () {
    expect(Golang.String.fromCodePoint(0x1f30d).toBytes(), [
      240,
      159,
      140,
      141,
    ]);
    for (final code in [
      -1,
      0xd800,
      0xdfff,
      0x110000,
      Golang.Uint64.fromBigInt((BigInt.one << 64) - BigInt.one).toInt(),
    ]) {
      expect(Golang.String.fromCodePoint(code).toBytes(), [239, 191, 189]);
    }
    expect(Golang.String.fromCodePoint(0).toBytes(), [0]);
  });

  test('concatenation owns its output and preserves both operands', () {
    final left = Golang.String.fromBytes(Uint8List.fromList([255, 0]));
    final right = Golang.String.fromBytes(Uint8List.fromList([128, 1]));
    final joined = left + right;
    joined.toBytes().fillRange(0, 4, 7);
    expect(joined.toBytes(), [255, 0, 128, 1]);
    expect(left.toBytes(), [255, 0]);
    expect(right.toBytes(), [128, 1]);
    expect(Golang.String() + left, left);
    expect(left + Golang.String(), left);
  });

  test('Go strings preserve invalid UTF8 and have value semantics', () {
    final bytes = Uint8List.fromList([255, 0, 195, 169]);
    final value = Golang.String.fromBytes(bytes);
    bytes[0] = 0;
    expect(value.length, 4);
    expect(value[0], 255);
    expect(value.toBytes(), [255, 0, 195, 169]);
    value.toBytes()[0] = 0;
    expect(value[0], 255);
    expect(value.slice(2).toDart(), 'é');
    expect(value.slice(2, 3).toBytes(), [195]);
    expect(value.slice(4), Golang.String());
    expect(
      value + Golang.String.fromDart('a'),
      Golang.String.fromBytes(Uint8List.fromList([255, 0, 195, 169, 97])),
    );
    expect(value.toDart, throwsFormatException);
    expect(() => value[-1], throwsRangeError);
    expect(() => value[4], throwsRangeError);
    expect(() => value.slice(3, 2), throwsRangeError);
    expect(() => value.slice(0, 5), throwsRangeError);
    expect(Golang.String.fromDart('é').length, 2);
    expect(
      Golang.String.fromDart('\uE000') < Golang.String.fromDart('\u{10000}'),
      isTrue,
    );
  });
}
