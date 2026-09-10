// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_protobuf/protowire.dart';

void main() {
  test('fixed32/64 use upstream byte order and ignore trailing bytes', () {
    final a = Golang.Uint32(0x89abcdef);
    final b = Golang.Uint64.fromBigInt(
      BigInt.parse('fedcba9876543210', radix: 16),
    );
    expect(appendFixed32([99], a), [99, 239, 205, 171, 137]);
    expect(appendFixed64([99], b), [99, 16, 50, 84, 118, 152, 186, 220, 254]);
    expect(consumeFixed32(Uint8List.fromList([239, 205, 171, 137, 99])), (
      a,
      4,
    ));
    expect(
      consumeFixed64(
        Uint8List.fromList([16, 50, 84, 118, 152, 186, 220, 254, 99]),
      ),
      (b, 8),
    );
    expect(sizeFixed32(), 4);
    expect(sizeFixed64(), 8);
    for (var n = 0; n < 8; n++) {
      expect(consumeFixed64(Uint8List(n)), (Golang.Uint64(), -1));
      if (n < 4) expect(consumeFixed32(Uint8List(n)), (Golang.Uint32(), -1));
    }
  });
}
