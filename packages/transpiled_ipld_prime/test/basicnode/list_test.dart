// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's node/tests/listSpecs.go: SpecTestListString,
// applied directly against this package's PlainList (see scalars_test.dart's
// header for why the generic spec-test engine isn't ported).
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

Node _buildListOfThreeStrings() {
  final nb = prototype.list.newBuilder();
  final la = nb.beginList(3);
  la.assembleValue().assignString('one');
  la.assembleValue().assignString('two');
  la.assembleValue().assignString('three');
  la.finish();
  return nb.build();
}

void main() {
  group('SpecTestListString: list<string>, 3 entries', () {
    test('reads back out', () {
      final n = _buildListOfThreeStrings();
      expect(n.length(), equals(3));
      expect(n.lookupByIndex(0).asString(), equals('one'));
      expect(n.lookupByIndex(1).asString(), equals('two'));
      expect(n.lookupByIndex(2).asString(), equals('three'));
    });

    test('reads via iteration', () {
      final n = _buildListOfThreeStrings();
      final itr = n.listIterator()!;

      expect(itr.done(), isFalse);
      var (idx, v) = itr.next();
      expect(idx, equals(0));
      expect(v.asString(), equals('one'));

      expect(itr.done(), isFalse);
      (idx, v) = itr.next();
      expect(idx, equals(1));
      expect(v.asString(), equals('two'));

      expect(itr.done(), isFalse);
      (idx, v) = itr.next();
      expect(idx, equals(2));
      expect(v.asString(), equals('three'));

      expect(itr.done(), isTrue);
      expect(itr.next, throwsA(isA<IteratorOverreadException>()));
    });
  });
}
