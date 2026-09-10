// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/any_node.dart
//
// Port of go-ipld-prime's node/basicnode/any.go: a builder that can accept
// any kind of data, deciding what concrete Node to produce based on
// whichever assign*/begin* method is called first.
//
// Go tracks progress with a `kind` field re-using a magic value (99) to
// mean "holding another Node of unknown prototype" via AssignNode -- a
// trick that only matters because Go's switch in Build() needs to route
// every scalar kind AND that magic case to the same `return nb.scalarNode`
// branch. This port uses a small closed `_AnyState` enum instead
// (empty/map/list/null/scalar): every scalar kind and the "unknown node"
// case behave identically in Build() (return the stored Node), so there's
// no need to track which specific scalar kind was assigned.
import 'dart:typed_data';

import '../datamodel/link.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/null_node.dart';
import 'list_node.dart';
import 'map_node.dart';
import 'scalars.dart';

enum _AnyState { empty, map, list, null_, scalar }

/// Describes [AnyBuilder]. Equivalent to go-ipld-prime's `Prototype__Any`.
class PrototypeAny implements NodePrototype {
  /// Creates the prototype.
  const PrototypeAny();
  @override
  NodeBuilder newBuilder() => AnyBuilder();
}

/// Builds a [Node] of whatever kind turns out to be assigned into it --
/// unlike the other builders in this package, it doesn't know its target
/// kind in advance. Equivalent to go-ipld-prime's `anyBuilder`.
class AnyBuilder implements NodeBuilder {
  _AnyState _state = _AnyState.empty;
  Node? _scalarNode;
  PlainMapAssembler? _mapBuilder;
  PlainListAssembler? _listBuilder;

  void _checkEmpty() {
    if (_state != _AnyState.empty) throw StateError('misuse');
  }

  @override
  MapAssembler beginMap(int sizeHint) {
    _checkEmpty();
    _state = _AnyState.map;
    _mapBuilder = PlainMapAssembler();
    return _mapBuilder!.beginMap(sizeHint);
  }

  @override
  ListAssembler beginList(int sizeHint) {
    _checkEmpty();
    _state = _AnyState.list;
    _listBuilder = PlainListAssembler();
    return _listBuilder!.beginList(sizeHint);
  }

  @override
  void assignNull() {
    _checkEmpty();
    _state = _AnyState.null_;
  }

  @override
  void assignBool(bool v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = PlainBool(v);
  }

  @override
  void assignInt(int v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = PlainInt(v);
  }

  @override
  void assignFloat(double v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = PlainFloat(v);
  }

  @override
  void assignString(String v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = PlainString(v);
  }

  @override
  void assignBytes(Uint8List v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = PlainBytes(v);
  }

  @override
  void assignLink(Link v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = PlainLink(v);
  }

  @override
  void assignNode(Node v) {
    _checkEmpty();
    _state = _AnyState.scalar;
    _scalarNode = v;
  }

  @override
  NodePrototype prototype() => const PrototypeAny();

  @override
  Node build() => switch (_state) {
    _AnyState.empty => throw StateError('misuse'),
    _AnyState.map => _mapBuilder!.build(),
    _AnyState.list => _listBuilder!.build(),
    _AnyState.null_ => nullNode,
    _AnyState.scalar => _scalarNode!,
  };

  @override
  void reset() {
    _state = _AnyState.empty;
    _scalarNode = null;
    _mapBuilder = null;
    _listBuilder = null;
  }
}
