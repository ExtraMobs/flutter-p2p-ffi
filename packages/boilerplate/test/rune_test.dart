// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('rune aliases int32 rather than restricting values to Unicode', () {
    final Golang.Rune rune = Golang.Int32(-1);
    final Golang.Int32 integer = Golang.Rune(-1);
    expect(rune, integer);
    expect(rune.runtimeType, integer.runtimeType);
    expect(rune + integer, Golang.Int32(-2));
    expect(Golang.String.fromRune(rune).toBytes(), [239, 191, 189]);
    final wide = BigInt.parse('4294967361');
    expect(Golang.Rune.fromBigInt(wide), Golang.Int32(65));
    expect(Golang.String.fromRune(Golang.Rune.fromBigInt(wide)).toDart(), 'A');
    expect(Golang.String.fromCodePoint(wide).toBytes(), [239, 191, 189]);
  });
}
