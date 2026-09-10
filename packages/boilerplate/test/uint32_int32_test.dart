// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('uint32 has fixed-width unsigned semantics', () {
    final max = Golang.Uint32.fromBigInt((BigInt.one << 32) - BigInt.one);
    expect(max + Golang.Uint32(1), Golang.Uint32());
    expect(Golang.Uint32() - Golang.Uint32(1), max);
    expect(max * Golang.Uint32(2), Golang.Uint32(0xfffffffe));
    expect(max >> 32, Golang.Uint32());
    expect(max << 32, Golang.Uint32());
    expect(max.andNot(Golang.Uint32(0xff)), Golang.Uint32(0xffffff00));
    expect(Golang.Uint32(7) ~/ Golang.Uint32(3), Golang.Uint32(2));
    expect(Golang.Uint32(7) % Golang.Uint32(3), Golang.Uint32(1));
    expect(() => max ~/ Golang.Uint32(), throwsA(isA<Error>()));
    expect(max.toLittleEndianBytes(), [255, 255, 255, 255]);
  });

  test('int32 has fixed-width signed semantics', () {
    final min = Golang.Int32.fromBigInt(-(BigInt.one << 31));
    final max = Golang.Int32.fromBigInt((BigInt.one << 31) - BigInt.one);
    expect(max + Golang.Int32(1), min);
    expect(min - Golang.Int32(1), max);
    expect(-min, min);
    expect(Golang.Int32(-5) ~/ Golang.Int32(2), Golang.Int32(-2));
    expect(Golang.Int32(-5) % Golang.Int32(2), Golang.Int32(-1));
    expect(min >> 32, Golang.Int32(-1));
    expect(max >> 32, Golang.Int32());
    expect(() => min << -1, throwsArgumentError);
    expect(min.toUint32(), Golang.Uint32(0x80000000));
  });
}
