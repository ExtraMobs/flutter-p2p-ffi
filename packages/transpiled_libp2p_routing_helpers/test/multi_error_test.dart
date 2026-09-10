// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';

void main() {
  group('combineErrors', () {
    test('returns null for an empty list', () {
      expect(combineErrors([]), isNull);
    });

    test('returns the sole error unwrapped for a single-element list', () {
      final e = Exception('one');
      expect(combineErrors([e]), same(e));
    });

    test('combines multiple errors into a MultiException', () {
      final combined = combineErrors([Exception('a'), Exception('b')]);
      expect(combined, isA<MultiException>());
      expect((combined as MultiException).errors, hasLength(2));
    });
  });

  group('appendError', () {
    test('returns the other value when one side is null', () {
      final e = Exception('x');
      expect(appendError(null, e), same(e));
      expect(appendError(e, null), same(e));
    });

    test('returns null when both sides are null', () {
      expect(appendError(null, null), isNull);
    });

    test('combines two non-null errors', () {
      final result = appendError(Exception('a'), Exception('b'));
      expect(result, isA<MultiException>());
    });

    test('accumulates into an existing MultiException rather than nesting', () {
      final first = appendError(Exception('a'), Exception('b'));
      final second = appendError(first, Exception('c'));
      expect(second, isA<MultiException>());
      expect((second as MultiException).errors, hasLength(3));
    });
  });
}
