// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('uint8 and int8 use one byte and wrap', () {
    final u = Golang.Uint8.fromBigInt(BigInt.from(255));
    final i = Golang.Int8.fromBigInt(BigInt.from(127));
    expect(u.toLittleEndianBytes(), [255]);
    expect(u + Golang.Uint8(1), Golang.Uint8());
    expect(i + Golang.Int8(1), Golang.Int8(-128));
    expect(Golang.Int8(-5) ~/ Golang.Int8(2), Golang.Int8(-2));
    expect(Golang.Int8(-5) % Golang.Int8(2), Golang.Int8(-1));
    expect(Golang.Int8(-1) >> 8, Golang.Int8(-1));
  });
  test('uint16 and int16 use two bytes and wrap', () {
    final u = Golang.Uint16.fromBigInt((BigInt.one << 16) - BigInt.one);
    final min = Golang.Int16.fromBigInt(-(BigInt.one << 15));
    expect(u.toLittleEndianBytes(), [255, 255]);
    expect(u + Golang.Uint16(1), Golang.Uint16());
    expect(min - Golang.Int16(1), Golang.Int16(32767));
    expect(min >> 16, Golang.Int16(-1));
    expect(Golang.Int16(32767) >> 16, Golang.Int16());
    expect(() => u << -1, throwsArgumentError);
  });
}
