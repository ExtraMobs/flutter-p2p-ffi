// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's datamodel/equal_test.go: TestDeepEqual.
//
// The real Go test builds its fixtures via node/basicnode + fluent/qp +
// linking/cid, none ported yet -- this uses the minimal SimpleNode/
// SimpleLink test doubles from fixtures/simple_node.dart instead (see
// that file's header). The test *cases* (what's compared, and the
// expected true/false) are copied directly from the Go source.
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
  final globalNode = SimpleNode.ofString('global');
  const globalLink = _FakeLink(1);
  const globalLink2 = _FakeLink(2);

  test('TestDeepEqual', () {
    final cases = <(String, Node?, Node?, bool)>[
      ('MismatchingKinds', SimpleNode.ofBool(true), SimpleNode.ofInt(3), false),
      ('SameNodeSamePointer', globalNode, globalNode, true),
      (
        'SameNodeDiffPointer',
        SimpleNode.ofString('same'),
        SimpleNode.ofString('same'),
        true,
      ),
      ('NilVsNil', null, null, true),
      ('NilVsNull', null, nullNode, false),
      ('SameKindNull', nullNode, nullNode, true),
      ('DiffKindNull', nullNode, absentNode, false),
      ('SameKindBool', SimpleNode.ofBool(true), SimpleNode.ofBool(true), true),
      (
        'DiffKindBool',
        SimpleNode.ofBool(true),
        SimpleNode.ofBool(false),
        false,
      ),
      ('SameKindInt', SimpleNode.ofInt(12), SimpleNode.ofInt(12), true),
      ('DiffKindInt', SimpleNode.ofInt(12), SimpleNode.ofInt(15), false),
      (
        'SameKindFloat',
        SimpleNode.ofFloat(1.25),
        SimpleNode.ofFloat(1.25),
        true,
      ),
      (
        'DiffKindFloat',
        SimpleNode.ofFloat(1.25),
        SimpleNode.ofFloat(1.75),
        false,
      ),
      (
        'SameKindString',
        SimpleNode.ofString('foobar'),
        SimpleNode.ofString('foobar'),
        true,
      ),
      (
        'DiffKindString',
        SimpleNode.ofString('foobar'),
        SimpleNode.ofString('baz'),
        false,
      ),
      (
        'SameKindBytes',
        SimpleNode.ofBytes(Uint8List.fromList([5, 2, 3])),
        SimpleNode.ofBytes(Uint8List.fromList([5, 2, 3])),
        true,
      ),
      (
        'DiffKindBytes',
        SimpleNode.ofBytes(Uint8List.fromList([5, 2, 3])),
        SimpleNode.ofBytes(Uint8List.fromList([5, 8, 3])),
        false,
      ),
      (
        'SameKindLink',
        SimpleNode.ofLink(globalLink),
        SimpleNode.ofLink(globalLink),
        true,
      ),
      (
        'DiffKindLink',
        SimpleNode.ofLink(globalLink),
        SimpleNode.ofLink(globalLink2),
        false,
      ),
      (
        'SameKindList',
        SimpleNode.ofList([SimpleNode.ofInt(7), SimpleNode.ofInt(8)]),
        SimpleNode.ofList([SimpleNode.ofInt(7), SimpleNode.ofInt(8)]),
        true,
      ),
      (
        'DiffKindList_length',
        SimpleNode.ofList([SimpleNode.ofInt(7), SimpleNode.ofInt(8)]),
        SimpleNode.ofList([SimpleNode.ofInt(7)]),
        false,
      ),
      (
        'DiffKindList_elems',
        SimpleNode.ofList([SimpleNode.ofInt(7), SimpleNode.ofInt(8)]),
        SimpleNode.ofList([SimpleNode.ofInt(3), SimpleNode.ofInt(2)]),
        false,
      ),
      (
        'SameKindMap',
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(7),
          'bar': SimpleNode.ofInt(8),
        }),
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(7),
          'bar': SimpleNode.ofInt(8),
        }),
        true,
      ),
      (
        'DiffKindMap_length',
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(7),
          'bar': SimpleNode.ofInt(8),
        }),
        SimpleNode.ofMap({'foo': SimpleNode.ofInt(7)}),
        false,
      ),
      (
        'DiffKindMap_elems',
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(7),
          'bar': SimpleNode.ofInt(8),
        }),
        SimpleNode.ofMap({
          'foo': SimpleNode.ofInt(3),
          'baz': SimpleNode.ofInt(8),
        }),
        false,
      ),
    ];

    for (final (name, left, right, want) in cases) {
      expect(deepEqual(left, right), equals(want), reason: name);
    }
  });
}
