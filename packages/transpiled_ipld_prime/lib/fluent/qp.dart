// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Concise helpers for assembling IPLD nodes.
///
/// Port of go-ipld-prime's `fluent/qp` package. Assembly errors are caught by
/// [buildMap] and [buildList] and returned as the second record field;
/// assembler helpers preserve the Go package's panic-on-error behavior by
/// allowing exceptions to propagate.
library;

import 'dart:typed_data';

import '../src/datamodel/link.dart';
import '../src/datamodel/node.dart';
import '../src/datamodel/node_builder.dart';

/// A deferred operation on a node assembler.
typedef Assemble = void Function(NodeAssembler assembler);

/// Builds a map node, returning `(node, error)` like Go's `(Node, error)`.
(Node?, Object?) buildMap(
  NodePrototype prototype,
  int sizeHint,
  void Function(MapAssembler) fn,
) {
  try {
    final builder = prototype.newBuilder();
    map(sizeHint, fn)(builder);
    return (builder.build(), null);
  } catch (error) {
    return (null, error);
  }
}

class _MapAssemble {
  const _MapAssemble(this.sizeHint, this.fn);
  final int sizeHint;
  final void Function(MapAssembler) fn;

  void call(NodeAssembler assembler) {
    final mapAssembler = assembler.beginMap(sizeHint);
    fn(mapAssembler);
    mapAssembler.finish();
  }
}

/// Starts assembling a map with [sizeHint].
Assemble map(int sizeHint, void Function(MapAssembler) fn) =>
    _MapAssemble(sizeHint, fn).call;

/// Adds a string-keyed map entry.
void mapEntry(MapAssembler assembler, String key, Assemble fn) {
  fn(assembler.assembleEntry(key));
}

/// Builds a list node, returning `(node, error)` like Go's `(Node, error)`.
(Node?, Object?) buildList(
  NodePrototype prototype,
  int sizeHint,
  void Function(ListAssembler) fn,
) {
  try {
    final builder = prototype.newBuilder();
    list(sizeHint, fn)(builder);
    return (builder.build(), null);
  } catch (error) {
    return (null, error);
  }
}

class _ListAssemble {
  const _ListAssemble(this.sizeHint, this.fn);
  final int sizeHint;
  final void Function(ListAssembler) fn;

  void call(NodeAssembler assembler) {
    final listAssembler = assembler.beginList(sizeHint);
    fn(listAssembler);
    listAssembler.finish();
  }
}

/// Starts assembling a list with [sizeHint].
Assemble list(int sizeHint, void Function(ListAssembler) fn) =>
    _ListAssemble(sizeHint, fn).call;

/// Adds a list entry.
void listEntry(ListAssembler assembler, Assemble fn) {
  fn(assembler.assembleValue());
}

class _NullAssemble {
  const _NullAssemble();
  void call(NodeAssembler assembler) => assembler.assignNull();
}

/// Assigns null.
Assemble nullValue() => const _NullAssemble().call;

class _BoolAssemble {
  const _BoolAssemble(this.value);
  final bool value;
  void call(NodeAssembler assembler) => assembler.assignBool(value);
}

/// Assigns a bool.
Assemble boolValue(bool value) => _BoolAssemble(value).call;

class _IntAssemble {
  const _IntAssemble(this.value);
  final int value;
  void call(NodeAssembler assembler) => assembler.assignInt(value);
}

/// Assigns an integer.
Assemble intValue(int value) => _IntAssemble(value).call;

class _FloatAssemble {
  const _FloatAssemble(this.value);
  final double value;
  void call(NodeAssembler assembler) => assembler.assignFloat(value);
}

/// Assigns a float.
Assemble floatValue(double value) => _FloatAssemble(value).call;

class _StringAssemble {
  const _StringAssemble(this.value);
  final String value;
  void call(NodeAssembler assembler) => assembler.assignString(value);
}

/// Assigns a string.
Assemble stringValue(String value) => _StringAssemble(value).call;

class _BytesAssemble {
  const _BytesAssemble(this.value);
  final List<int> value;
  void call(NodeAssembler assembler) =>
      assembler.assignBytes(Uint8List.fromList(value));
}

/// Assigns bytes.
Assemble bytes(List<int> value) => _BytesAssemble(value).call;

class _LinkAssemble {
  const _LinkAssemble(this.value);
  final Link value;
  void call(NodeAssembler assembler) => assembler.assignLink(value);
}

/// Assigns a link.
Assemble link(Link value) => _LinkAssemble(value).call;

class _NodeAssemble {
  const _NodeAssemble(this.value);
  final Node value;
  void call(NodeAssembler assembler) => assembler.assignNode(value);
}

/// Assigns an existing node.
Assemble node(Node value) => _NodeAssemble(value).call;
