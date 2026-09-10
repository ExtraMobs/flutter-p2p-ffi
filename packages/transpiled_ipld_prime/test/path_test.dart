// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's datamodel/path_test.go: TestParsePath.
//
// TestPathSegmentZeroValue is not ported: it specifically exercises Go's
// zero-value struct pitfall (`PathSegment{}` behaves like
// `ParsePathSegment("0")`, an int segment, NOT an empty string --
// documented as a footgun in the Go source). Dart classes have no
// implicit zero-value construction (only `null` does, for nullable
// types), so PathSegment can only ever be built via its named
// constructors -- the pitfall this test guards against doesn't exist in
// this port.
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  test('TestParsePath', () {
    void check(String input, List<String> expectedSegments) {
      final got = Path.parse(input).segments.map((s) => s.toString()).toList();
      expect(got, equals(expectedSegments));
    }

    check('0', const ['0']);
    check('0/foo/2', const ['0', 'foo', '2']);
    check('/0/2', const ['0', '2']); // eliding leading slashes
    check('0/2/', const ['0', '2']); // eliding trailing
    check('0//2', const ['0', '2']); // eliding empty segments
    check(r'0/\//2', const ['0', r'\', '2']); // no escaping mechanism
  });
}
