// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's datamodel/copy_test.go: TestCopy.
//
// As with equal_test.dart, the real Go test's fixtures (node/basicnode +
// fluent/qp) aren't ported yet -- this uses the SimpleNode/
// SimpleNodeBuilder test doubles from fixtures/simple_node.dart. The test
// cases (what's copied, and the expected success/error) are copied
// directly from the Go source; the "typed builder" cases (e.g. "Int /
// Int") collapse to the same behavior as "X / Any" here, since SimpleNode
// has no schema-typed variant -- still a real exercise of copyNode's
// per-Kind dispatch either way.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'fixtures/simple_node.dart';

class _FakeLink implements Link {
  const _FakeLink(this.id);
  final int id;

  @override
  LinkPrototype prototype() => throw UnimplementedError();
  @override
  List<int> binary() => [id];
  @override
  String toString() => 'fakelink:$id';
  @override
  bool operator ==(Object other) => other is _FakeLink && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

void main() {
  const globalLink = _FakeLink(1);
  const globalLink2 = _FakeLink(2);

  test('TestCopy', () {
    final cases = <(String, Node?, String?)>[
      ('Null', nullNode, null),
      ('Int', SimpleNode.ofInt(100), null),
      ('Bool', SimpleNode.ofBool(true), null),
      ('Float', SimpleNode.ofFloat(1.1), null),
      ('String', SimpleNode.ofString('mary had'), null),
      (
        'Bytes',
        SimpleNode.ofBytes(Uint8List.fromList('mary had'.codeUnits)),
        null,
      ),
      ('Link', SimpleNode.ofLink(globalLink), null),
      (
        'List',
        SimpleNode.ofList([SimpleNode.ofInt(7), SimpleNode.ofInt(8)]),
        null,
      ),
      (
        'List of mixed kinds',
        SimpleNode.ofList([
          SimpleNode.ofString('yep'),
          SimpleNode.ofInt(8),
          SimpleNode.ofString('nope'),
        ]),
        null,
      ),
      (
        'Map',
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(7),
          'bar': SimpleNode.ofInt(8),
        }),
        null,
      ),
      (
        'Map with a link value',
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(7),
          'bar': SimpleNode.ofInt(8),
          'bang': SimpleNode.ofLink(globalLink2),
        }),
        null,
      ),
      ('nil', null, 'cannot copy a nil node'),
      ('absent', absentNode, 'copying an absent node makes no sense'),
    ];

    for (final (name, n, expectedError) in cases) {
      final builder = SimpleNodeBuilder();
      if (expectedError != null) {
        expect(
          () => copyNode(n, builder),
          throwsA(isA<ArgumentError>()),
          reason: name,
        );
        continue;
      }
      copyNode(n, builder);
      final out = builder.build();
      expect(deepEqual(n, out), isTrue, reason: '$name: deep equal failed');
    }
  });
}
