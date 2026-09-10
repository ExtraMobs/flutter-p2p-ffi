// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_protobuf/protowire.dart';

void main() {
  test('Go wire strings preserve invalid UTF8, prefix and consumed count', () {
    final s = Golang.String.fromBytes(Uint8List.fromList([255, 0, 195]));
    final output = <int>[99];
    expect(identical(appendString(output, s), output), isTrue);
    expect(output, [99, 3, 255, 0, 195]);
    final input = Uint8List.fromList([3, 255, 0, 195, 88]);
    final (decoded, n) = consumeString(input);
    expect(decoded, s);
    expect(n, 4);
    input[1] = 0;
    expect(decoded[0], 255);
    expect(consumeString(Uint8List.fromList([0])), (Golang.String(), 1));
    expect(consumeString(Uint8List.fromList([2, 255])), (Golang.String(), -1));
    expect(consumeString(Uint8List.fromList([...List.filled(9, 128), 2])), (
      Golang.String(),
      -3,
    ));
  });
}
