// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: deprecated_member_use
import 'package:test/test.dart';
import 'package:transpiled_boxo/bitswap/wantlist.dart';
import 'package:transpiled_boxo/src/bitswap/client/wantlist/want_type.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

void main() {
  test('deprecated forward aliases client wantlist', () {
    final cid = Cid.decode('QmQL8LqkEgYXaDHdNYCG2mmpow7Sp8Z8Kt3QS688vyBeC7');
    final wl = wantlist();
    expect(wl, isA<Wantlist>());
    expect(wl.add(cid, 1, WantType.block), isTrue);
    expect(refEntry(cid, 2).cid, equals(cid));
  });
}
