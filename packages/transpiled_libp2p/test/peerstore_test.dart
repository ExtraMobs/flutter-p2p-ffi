// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

void main() {
  test('peerstore TTLs match go-libp2p', () {
    expect(addressTtl, const Duration(hours: 1));
    expect(tempAddrTtl, const Duration(minutes: 2));
    expect(recentlyConnectedAddrTtl, const Duration(minutes: 15));
    expect(ownObservedAddrTtl, const Duration(minutes: 30));
    expect(permanentAddrTtl.inMicroseconds, 9223372036854775);
    expect(connectedAddrTtl.inMicroseconds, 9223372036854774);
    expect(permanentAddrTtl > connectedAddrTtl, isTrue);
  });
}
