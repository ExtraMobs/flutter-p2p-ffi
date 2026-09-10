// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/discovery/options.dart';

void main() {
  test('applies TTL and limit options in order', () {
    final options = DiscoveryOptions();
    options.apply([
      ttl(const Duration(minutes: 5)),
      limit(3),
      ttl(const Duration(minutes: 1)),
    ]);

    expect(options.ttl, const Duration(minutes: 1));
    expect(options.limit, 3);
  });
}
