// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

void main() {
  test('protocol IDs preserve order and values through conversions', () {
    const ids = ['/ipfs/id/1.0.0', '/ping/1.0.0'];
    expect(convertFromStrings(ids), ids);
    expect(convertToStrings(convertFromStrings(ids)), ids);
  });
}
