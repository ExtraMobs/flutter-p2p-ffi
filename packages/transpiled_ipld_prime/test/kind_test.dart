// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's datamodel/kind_test.go: TestErrWrongKind_String.
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  test('TestErrWrongKind_String', () {
    expect(const KindSet([]).toString(), equals('<empty KindSet>'));
    expect(
      const WrongKindException(
        methodName: '',
        appropriateKind: KindSet([]),
        actualKind: Kind.invalid,
      ).toString(),
      equals(
        'func called on wrong kind: "" called on a INVALID node, but only '
        'makes sense on <empty KindSet>',
      ),
    );
  });
}
