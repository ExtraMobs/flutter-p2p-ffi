// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_protobuf/protowire.dart';

void main() {
  test('Go uint64 boundaries and noncanonical encodings', () {
    for (final text in [
      '0',
      '1',
      '127',
      '128',
      '16384',
      '9223372036854775807',
      '9223372036854775808',
      '18446744073709551615',
    ]) {
      final v = Golang.Uint64.fromBigInt(BigInt.parse(text));
      final bytes = appendVarint([], v);
      expect(consumeVarint(Uint8List.fromList(bytes)), (v, bytes.length));
      expect(sizeVarint(v), bytes.length);
    }
    expect(appendVarint([], Golang.Uint64(-1)), [...List.filled(9, 255), 1]);
    expect(consumeVarint(Uint8List.fromList([128, 0])), (Golang.Uint64(), 2));
    expect(consumeVarint(Uint8List.fromList(List.filled(9, 128))), (
      Golang.Uint64(),
      -1,
    ));
    expect(consumeVarint(Uint8List.fromList([...List.filled(9, 128), 2])), (
      Golang.Uint64(),
      -3,
    ));
  });
  test('Go ConsumeTag permits MessageSet but rejects int32 overflow', () {
    for (final number in [1, 0x1fffffff, 0x20000000, 0x7fffffff]) {
      final bytes = appendTag([], number, 2);
      expect(consumeTag(Uint8List.fromList(bytes)), (number, 2, bytes.length));
      expect(sizeTag(number), bytes.length);
    }
    expect(consumeTag(Uint8List.fromList([0])), (0, 0, -2));
    expect(
      consumeTag(
        Uint8List.fromList(appendVarint([], Golang.Uint64(0x400000000))),
      ),
      (0, 0, -2),
    );
  });
  test('byte fields preserve consumed length and error codes', () {
    final bytes = Uint8List.fromList(appendBytes([], [7, 8])..add(99));
    final (value, n) = consumeBytes(bytes);
    expect(value, [7, 8]);
    expect(n, 3);
    expect(sizeBytes(2), n);
    expect(consumeBytes(Uint8List.fromList([3, 1])).$2, -1);
    expect(
      consumeBytes(Uint8List.fromList(appendVarint([], Golang.Uint64(-1)))).$2,
      -1,
    );
    expect(parseError(0), isNull);
    expect(parseError(-3)!.message, 'variable length integer overflow');
  });
}
