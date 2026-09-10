// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/null_node.dart
//
// Port of go-ipld-prime's datamodel/unit.go: the two Node values we can
// give true singleton implementations of, "null" and "absent".
import 'dart:typed_data';

import 'errors.dart';
import 'kind.dart';
import 'link.dart';
import 'node.dart';
import 'node_builder.dart';
import 'path_segment.dart';

class _NullNode implements Node {
  const _NullNode();

  @override
  Kind kind() => Kind.null_;
  @override
  Node lookupByString(String key) => throw const WrongKindException(
    typeName: 'null',
    methodName: 'lookupByString',
    appropriateKind: KindSet.justMap,
    actualKind: Kind.null_,
  );
  @override
  Node lookupByNode(Node key) => throw const WrongKindException(
    typeName: 'null',
    methodName: 'lookupByNode',
    appropriateKind: KindSet.justMap,
    actualKind: Kind.null_,
  );
  @override
  Node lookupByIndex(int idx) => throw const WrongKindException(
    typeName: 'null',
    methodName: 'lookupByIndex',
    appropriateKind: KindSet.justList,
    actualKind: Kind.null_,
  );
  @override
  Node lookupBySegment(PathSegment seg) => throw const WrongKindException(
    typeName: 'null',
    methodName: 'lookupBySegment',
    appropriateKind: KindSet.recursive,
    actualKind: Kind.null_,
  );
  @override
  MapIterator? mapIterator() => null;
  @override
  ListIterator? listIterator() => null;
  @override
  int length() => -1;
  @override
  bool isAbsent() => false;
  @override
  bool isNull() => true;
  @override
  bool asBool() => throw const WrongKindException(
    typeName: 'null',
    methodName: 'asBool',
    appropriateKind: KindSet.justBool,
    actualKind: Kind.null_,
  );
  @override
  int asInt() => throw const WrongKindException(
    typeName: 'null',
    methodName: 'asInt',
    appropriateKind: KindSet.justInt,
    actualKind: Kind.null_,
  );
  @override
  double asFloat() => throw const WrongKindException(
    typeName: 'null',
    methodName: 'asFloat',
    appropriateKind: KindSet.justFloat,
    actualKind: Kind.null_,
  );
  @override
  String asString() => throw const WrongKindException(
    typeName: 'null',
    methodName: 'asString',
    appropriateKind: KindSet.justString,
    actualKind: Kind.null_,
  );
  @override
  Uint8List asBytes() => throw const WrongKindException(
    typeName: 'null',
    methodName: 'asBytes',
    appropriateKind: KindSet.justBytes,
    actualKind: Kind.null_,
  );
  @override
  Link asLink() => throw const WrongKindException(
    typeName: 'null',
    methodName: 'asLink',
    appropriateKind: KindSet.justLink,
    actualKind: Kind.null_,
  );
  @override
  NodePrototype prototype() => const _NullPrototype();
}

class _NullPrototype implements NodePrototype {
  const _NullPrototype();
  @override
  NodeBuilder newBuilder() => throw UnsupportedError('cannot build null nodes');
}

/// The singleton "null" node. Has `kind() == Kind.null_`, `isNull() ==
/// true`, throws [WrongKindException] for most other inquiries, and its
/// [NodePrototype.newBuilder] always throws (there's no sense building a
/// new "null"). Equivalent to go-ipld-prime's `Null`.
const Node nullNode = _NullNode();

class _AbsentNode implements Node {
  const _AbsentNode();

  @override
  Kind kind() => Kind.null_;
  @override
  Node lookupByString(String key) => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'lookupByString',
    appropriateKind: KindSet.justMap,
    actualKind: Kind.null_,
  );
  @override
  Node lookupByNode(Node key) => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'lookupByNode',
    appropriateKind: KindSet.justMap,
    actualKind: Kind.null_,
  );
  @override
  Node lookupByIndex(int idx) => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'lookupByIndex',
    appropriateKind: KindSet.justList,
    actualKind: Kind.null_,
  );
  @override
  Node lookupBySegment(PathSegment seg) => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'lookupBySegment',
    appropriateKind: KindSet.recursive,
    actualKind: Kind.null_,
  );
  @override
  MapIterator? mapIterator() => null;
  @override
  ListIterator? listIterator() => null;
  @override
  int length() => -1;
  @override
  bool isAbsent() => true;
  @override
  bool isNull() => false;
  @override
  bool asBool() => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'asBool',
    appropriateKind: KindSet.justBool,
    actualKind: Kind.null_,
  );
  @override
  int asInt() => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'asInt',
    appropriateKind: KindSet.justInt,
    actualKind: Kind.null_,
  );
  @override
  double asFloat() => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'asFloat',
    appropriateKind: KindSet.justFloat,
    actualKind: Kind.null_,
  );
  @override
  String asString() => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'asString',
    appropriateKind: KindSet.justString,
    actualKind: Kind.null_,
  );
  @override
  Uint8List asBytes() => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'asBytes',
    appropriateKind: KindSet.justBytes,
    actualKind: Kind.null_,
  );
  @override
  Link asLink() => throw const WrongKindException(
    typeName: 'absent',
    methodName: 'asLink',
    appropriateKind: KindSet.justLink,
    actualKind: Kind.null_,
  );
  @override
  NodePrototype prototype() => const _AbsentPrototype();
}

class _AbsentPrototype implements NodePrototype {
  const _AbsentPrototype();
  @override
  NodeBuilder newBuilder() =>
      throw UnsupportedError('cannot build absent nodes');
}

/// The singleton "absent" node: returned when traversing a schema-defined
/// struct field that's unset in the data. Has `kind() == Kind.null_`,
/// `isNull() == false`, `isAbsent() == true`. Not really a Data Model
/// concept -- only seen via `schema.TypedNode` (not ported yet) or
/// diagnostic printing, but kept here since it would end up imported
/// almost universally otherwise, matching Go's own placement rationale.
/// Equivalent to go-ipld-prime's `Absent`.
const Node absentNode = _AbsentNode();
