// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/node_builder.dart
//
// Port of go-ipld-prime's datamodel/nodeBuilder.go.
import 'dart:typed_data';

import 'link.dart';
import 'node.dart';

/// Describes all the ways a [Node] under construction can be filled in.
/// Equivalent to go-ipld-prime's `NodeAssembler`.
///
/// A [NodeAssembler] fills in data; to create a new [Node], start with a
/// [NodeBuilder] (a superset of these methods, plus [NodeBuilder.build]).
/// For scalars, call the matching `assign*` method; for recursives, call
/// [beginMap]/[beginList] and fill in the returned assembler.
abstract class NodeAssembler {
  /// Starts assembling a map, optionally hinting its final size.
  MapAssembler beginMap(int sizeHint);

  /// Starts assembling a list, optionally hinting its final size.
  ListAssembler beginList(int sizeHint);

  /// Assigns the null value.
  void assignNull();

  /// Assigns a bool value.
  void assignBool(bool v);

  /// Assigns an int value.
  void assignInt(int v);

  /// Assigns a float value.
  void assignFloat(double v);

  /// Assigns a string value.
  void assignString(String v);

  /// Assigns a bytes value.
  void assignBytes(Uint8List v);

  /// Assigns a link value.
  void assignLink(Link v);

  /// Copies an already-constructed [Node] into place at once, dispatching
  /// internally to whichever other `assign*`/`begin*` method fits its
  /// kind. Roughly equivalent to using the `copyNode` function (and is
  /// often implemented using it), but may take faster shortcuts when
  /// possible.
  void assignNode(Node v);

  /// A [NodePrototype] describing what kind of value is being assembled.
  NodePrototype prototype();
}

/// Assembles a map. Methods must be called in a valid order: a key, then
/// a value, looped as long as desired, then [finish]. Equivalent to
/// go-ipld-prime's `MapAssembler`.
abstract class MapAssembler {
  /// Starts assembling the next entry's key. Must be followed by
  /// [assembleValue].
  NodeAssembler assembleKey();

  /// Starts assembling the value for the key just assembled via
  /// [assembleKey]. Must be called immediately after it.
  NodeAssembler assembleValue();

  /// A shortcut combining [assembleKey] and [assembleValue] into one step,
  /// valid when the key is a plain string.
  NodeAssembler assembleEntry(String k);

  /// Finalizes this map.
  void finish();

  /// A [NodePrototype] for keys this map uses. For Data Model maps, this
  /// is always a basic string-like prototype.
  NodePrototype keyPrototype();

  /// A [NodePrototype] for values this map can contain, given key [k].
  /// For plain (non-schema) maps, the same prototype is returned
  /// regardless of [k].
  NodePrototype valuePrototype(String k);
}

/// Assembles a list. Equivalent to go-ipld-prime's `ListAssembler`.
abstract class ListAssembler {
  /// Starts assembling the next value.
  NodeAssembler assembleValue();

  /// Finalizes this list.
  void finish();

  /// A [NodePrototype] for values this list can contain at position
  /// [idx]. For Data Model lists, the same prototype is returned
  /// regardless of [idx].
  NodePrototype valuePrototype(int idx);
}

/// Builds a new [Node]. Equivalent to go-ipld-prime's `NodeBuilder`.
abstract class NodeBuilder implements NodeAssembler {
  /// The newly-built node. A finishing method (an `assign*` call, or
  /// [MapAssembler.finish]/[ListAssembler.finish]) must have been called
  /// first.
  Node build();

  /// Resets this builder so it can be reused, reducing allocations. Only
  /// call this if you intend to reuse the builder.
  void reset();
}
