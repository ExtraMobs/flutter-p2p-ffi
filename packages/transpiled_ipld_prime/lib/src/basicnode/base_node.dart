// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/base_node.dart
//
// Port of go-ipld-prime's node/mixins package: shared "wrong kind" boilerplate
// so each concrete Node/NodeAssembler only implements what's valid for its
// own kind. Go achieves this via composable mixin structs (one per Kind,
// embedded into each concrete type) purely so the "always wrong" methods
// compile down to zero-allocation inlined calls; that motivation doesn't
// apply to Dart, so this collapses to two abstract base classes with
// default (throwing) implementations that concrete types override
// selectively -- same exceptions, same fields, just via inheritance
// instead of struct composition.
import 'dart:typed_data';

import '../datamodel/errors.dart';
import '../datamodel/kind.dart';
import '../datamodel/link.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/path_segment.dart';

/// A [Node] base that throws [WrongKindException] (with this node's own
/// [typeName] and [Node.kind]) for every method not valid for a scalar or
/// otherwise kind-restricted node. Concrete types override [Node.kind],
/// [typeName], and whichever methods actually apply.
abstract class BaseNode implements Node {
  /// Creates the base.
  const BaseNode();

  /// This node's named type, used in [WrongKindException] messages (e.g.
  /// `'bool'`, `'map'`).
  String get typeName;

  WrongKindException _wrongKind(String method, KindSet appropriate) =>
      WrongKindException(
        typeName: typeName,
        methodName: method,
        appropriateKind: appropriate,
        actualKind: kind(),
      );

  @override
  Node lookupByString(String key) =>
      throw _wrongKind('LookupByString', KindSet.justMap);

  @override
  Node lookupByNode(Node key) =>
      throw _wrongKind('LookupByNode', KindSet.justMap);

  @override
  Node lookupByIndex(int idx) =>
      throw _wrongKind('LookupByIndex', KindSet.justList);

  @override
  Node lookupBySegment(PathSegment seg) =>
      throw _wrongKind('LookupBySegment', KindSet.recursive);

  @override
  MapIterator? mapIterator() => null;

  @override
  ListIterator? listIterator() => null;

  @override
  int length() => -1;

  @override
  bool isAbsent() => false;

  @override
  bool isNull() => false;

  @override
  bool asBool() => throw _wrongKind('AsBool', KindSet.justBool);

  @override
  int asInt() => throw _wrongKind('AsInt', KindSet.justInt);

  @override
  double asFloat() => throw _wrongKind('AsFloat', KindSet.justFloat);

  @override
  String asString() => throw _wrongKind('AsString', KindSet.justString);

  @override
  Uint8List asBytes() => throw _wrongKind('AsBytes', KindSet.justBytes);

  @override
  Link asLink() => throw _wrongKind('AsLink', KindSet.justLink);
}

/// A [NodeAssembler] base that throws [WrongKindException] (with this
/// assembler's own [typeName] and [selfKind] -- the kind it assembles,
/// reported as `actualKind` on every error regardless of which method was
/// called, matching Go's mixin behavior) for every method not valid for
/// this assembler's kind.
abstract class BaseAssembler implements NodeAssembler {
  /// Creates the base.
  const BaseAssembler();

  /// This assembler's named type, used in [WrongKindException] messages.
  String get typeName;

  /// The kind this assembler builds.
  Kind get selfKind;

  WrongKindException _wrongKind(String method, KindSet appropriate) =>
      WrongKindException(
        typeName: typeName,
        methodName: method,
        appropriateKind: appropriate,
        actualKind: selfKind,
      );

  @override
  MapAssembler beginMap(int sizeHint) =>
      throw _wrongKind('BeginMap', KindSet.justMap);

  @override
  ListAssembler beginList(int sizeHint) =>
      throw _wrongKind('BeginList', KindSet.justList);

  @override
  void assignNull() => throw _wrongKind('AssignNull', KindSet.justNull);

  @override
  void assignBool(bool v) => throw _wrongKind('AssignBool', KindSet.justBool);

  @override
  void assignInt(int v) => throw _wrongKind('AssignInt', KindSet.justInt);

  @override
  void assignFloat(double v) =>
      throw _wrongKind('AssignFloat', KindSet.justFloat);

  @override
  void assignString(String v) =>
      throw _wrongKind('AssignString', KindSet.justString);

  @override
  void assignBytes(Uint8List v) =>
      throw _wrongKind('AssignBytes', KindSet.justBytes);

  @override
  void assignLink(Link v) => throw _wrongKind('AssignLink', KindSet.justLink);
}
