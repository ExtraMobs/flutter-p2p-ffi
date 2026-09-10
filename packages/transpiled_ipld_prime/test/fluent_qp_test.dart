// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/fluent.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart' as ipld;

void main() {
  test('builds nested map and list', () {
    final (node, error) = buildMap(ipld.prototype.any, 2, (map) {
      mapEntry(map, 'x', stringValue('y'));
      mapEntry(
        map,
        'list',
        list(2, (list) {
          listEntry(list, intValue(1));
          listEntry(list, boolValue(true));
        }),
      );
    });
    expect(error, isNull);
    expect(node!.lookupByString('x').asString(), 'y');
    expect(node.lookupByString('list').lookupByIndex(1).asBool(), isTrue);
  });

  test('returns assembly errors', () {
    final (node, error) = buildMap(ipld.prototype.any, 1, (map) {
      mapEntry(map, 'x', stringValue('a'));
      mapEntry(map, 'x', stringValue('b'));
    });
    expect(node, isNull);
    expect(error, isA<Exception>());
  });

  test('assign helpers cover all values', () {
    final (built, error) = buildList(ipld.prototype.any, 7, (list) {
      listEntry(list, nullValue());
      listEntry(list, boolValue(false));
      listEntry(list, intValue(2));
      listEntry(list, floatValue(2.5));
      listEntry(list, stringValue('s'));
      listEntry(list, bytes([1, 2]));
      listEntry(list, node(const ipld.PlainString('n')));
    });
    expect(error, isNull);
    expect(built!.length(), 7);
    expect(built.lookupByIndex(3).asFloat(), 2.5);
  });
}
