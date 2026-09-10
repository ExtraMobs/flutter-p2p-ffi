// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('Go spec sign extension and truncation across widths', () {
    final v = Golang.Uint16(0x10f0);
    final signed = Golang.Int8.fromBigInt(v.toBigInt());
    expect(signed.toBigInt(), BigInt.from(-16));
    expect(
      Golang.Uint32.fromBigInt(signed.toBigInt()).toBigInt(),
      BigInt.parse('4294967280'),
    );
    final unsigned = Golang.Uint8.fromBigInt(v.toBigInt());
    expect(
      Golang.Uint32.fromBigInt(unsigned.toBigInt()).toBigInt(),
      BigInt.from(240),
    );
    final Golang.Byte byte = Golang.Uint8(255);
    final Golang.Uint8 sameType = Golang.Byte(255);
    expect(byte, sameType);
    expect(byte.runtimeType, sameType.runtimeType);
  });
}
