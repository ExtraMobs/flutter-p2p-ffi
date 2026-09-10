// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/linking_cid.dart';

void main() {
  test('Cid link preserves string, binary bytes, and prototype', () {
    final cid = Cid.decode(
      'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
    );
    final link = CidLink(cid);
    expect(link.toString(), cid.toString());
    expect(link.binary(), cid.toBytes());
    final rebuilt = link.prototype().buildLink(cid.multihash.digest);
    expect(rebuilt.toString(), cid.toString());
  });
}
