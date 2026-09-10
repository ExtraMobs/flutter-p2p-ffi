// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Confirms the generated table (tool/generate_prefix_map.dart's output)
// matches real values copied directly from go-libp2p-kbucket's own
// generated bucket_prefixmap.go (go-ipfs-reference/go-libp2p-kbucket/
// bucket_prefixmap.go), byte-for-byte -- not just "looks plausible".
import 'package:test/test.dart';
import 'package:transpiled_libp2p_kbucket/src/key_prefix_map.dart';

void main() {
  test('has exactly 65536 entries (one per 16-bit prefix)', () {
    expect(keyPrefixMap, hasLength(65536));
  });

  test('matches the real Go table\'s first row', () {
    expect(
      keyPrefixMap.sublist(0, 16),
      equals(const [
        77591, 94053, 60620, 45849, 22417, 13238, 102507, 179931,
        43971, 15812, 24466, 64694, 28421, 80794, 13447, 118511,
      ]),
    );
  });

  test('matches the real Go table\'s last row', () {
    expect(
      keyPrefixMap.sublist(keyPrefixMap.length - 16),
      equals(const [
        35963, 49566, 21279, 91399, 94216, 64873, 68891, 55512,
        45590, 3382, 26979, 72069, 97782, 126859, 187860, 246200,
      ]),
    );
  });
}
