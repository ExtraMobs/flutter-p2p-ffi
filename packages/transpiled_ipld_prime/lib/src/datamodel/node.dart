// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/node.dart
//
// Port of go-ipld-prime's datamodel/node.go. Go's lookup/As* methods
// return `(value, error)`; ported as plain-value-returning methods that
// throw instead (WrongKindException/NotExistsException/etc from errors.dart)
// -- see that file's header for why.
import 'dart:typed_data';

import 'errors.dart';
import 'kind.dart';
import 'link.dart';
import 'node_builder.dart';
import 'path_segment.dart';

/// A value in IPLD: any point in a tree of data is a node -- scalars
/// (int, string, etc) as well as recursive values (map, list). Equivalent
/// to go-ipld-prime's `Node`.
///
/// Node is read-only; implementations must be immutable. The companion
/// [NodeAssembler]/[NodeBuilder] interfaces provide the matching writable
/// methods used to create a (thence immutable) Node.
abstract class Node {
  /// This node's essential kind (map, list, integer, etc). Most other
  /// handling of a node requires switching on this first.
  Kind kind();

  /// Looks up a child by string key. Throws [WrongKindException] if this
  /// node isn't [Kind.map], or [NotExistsException] if [key] isn't
  /// present.
  Node lookupByString(String key);

  /// As [lookupByString], but takes a reified [Node] key -- useful with
  /// typed maps, or simply when a [Node] key is already in hand.
  Node lookupByNode(Node key);

  /// Looks up a child by list index. Throws [WrongKindException] if this
  /// node isn't [Kind.list], or [NotExistsException] if [idx] is out of
  /// range.
  Node lookupByIndex(int idx);

  /// Acts as either [lookupByString] or [lookupByIndex], whichever is
  /// contextually appropriate. May throw [InvalidSegmentForListException]
  /// if used on a list with a segment that isn't a valid index.
  Node lookupBySegment(PathSegment seg);

  /// An iterator yielding every key-value pair in this node, in a stable
  /// order defined by the implementation. `null` if this node isn't
  /// [Kind.map].
  MapIterator? mapIterator();

  /// An iterator yielding every index-value pair in this node, indices
  /// ranging from 0 to `length - 1`. `null` if this node isn't
  /// [Kind.list].
  ListIterator? listIterator();

  /// The length of a list, or the number of entries in a map, or -1 if
  /// this node is neither.
  int length();

  /// Whether this is the special "absent" node -- only possible from
  /// `schema.TypedNode`, when traversing a struct field defined by a
  /// schema but unset in the data.
  bool isAbsent();

  /// Whether this is the special "null" node.
  bool isNull();

  /// Throws [WrongKindException] unless this node is [Kind.bool_].
  bool asBool();

  /// Throws [WrongKindException] unless this node is [Kind.int_].
  int asInt();

  /// Throws [WrongKindException] unless this node is [Kind.float].
  double asFloat();

  /// Throws [WrongKindException] unless this node is [Kind.string].
  String asString();

  /// Throws [WrongKindException] unless this node is [Kind.bytes].
  Uint8List asBytes();

  /// Throws [WrongKindException] unless this node is [Kind.link].
  Link asLink();

  /// A [NodePrototype] describing this node's implementation, which can
  /// build new nodes of the same kind. Calling this should never allocate.
  NodePrototype prototype();
}

/// An optional interface a [Node] representing an integer can implement to
/// expose the full uint64 range. Equivalent to go-ipld-prime's `UintNode`.
///
/// EXPERIMENTAL: matches the upstream Go API's own experimental status.
abstract class UintNode implements Node {
  /// The underlying integer as an unsigned 64-bit value. May throw if this
  /// node represents a negative integer.
  int asUint();
}

/// How a [ByteReadSeeker]'s [ByteReadSeeker.seek] offset is interpreted.
/// Equivalent to the constants Go's `io.Seeker` defines (`io.SeekStart`
/// etc.), which [LargeBytesNode] uses via `io.ReadSeeker`.
enum SeekOrigin {
  /// Relative to the start of the data.
  start,

  /// Relative to the current position.
  current,

  /// Relative to the end of the data.
  end,
}

/// A minimal stand-in for Go's `io.ReadSeeker`, since Dart has no
/// platform-generic seekable-byte-stream interface in `dart:core`/`dart:io`
/// (`RandomAccessFile` is file-specific). Used by [LargeBytesNode].
abstract class ByteReadSeeker {
  /// Reads up to [buffer].length bytes into [buffer], returning the number
  /// actually read (0 at end-of-data).
  int read(Uint8List buffer);

  /// Moves the read position by [offset], interpreted relative to
  /// [origin]. Returns the new absolute position.
  int seek(int offset, SeekOrigin origin);
}

/// An optional interface extending a [Kind.bytes] node to allow its
/// contents to be streamed via a [ByteReadSeeker] instead of a single
/// [Uint8List], avoiding a large up-front allocation. Equivalent to
/// go-ipld-prime's `LargeBytesNode`.
abstract class LargeBytesNode implements Node {
  /// A [ByteReadSeeker] over this node's contents. Each call returns a
  /// separate, independent instance -- reading/seeking on one must not
  /// affect others.
  ByteReadSeeker asLargeBytes();
}

/// Describes a [Node] implementation; every [Node] has one, and it can
/// always produce a [NodeBuilder]. Equivalent to go-ipld-prime's
/// `NodePrototype`.
abstract class NodePrototype {
  /// A new [NodeBuilder] that can build a new [Node] of this
  /// implementation. Often allocates, unlike obtaining the prototype
  /// itself.
  NodeBuilder newBuilder();
}

/// A feature-detection interface: a [NodePrototype] that can build new
/// nodes while sharing internal data with an existing [Node] in a
/// copy-on-write way (typical of Advanced Data Layouts). Equivalent to
/// go-ipld-prime's `NodePrototypeSupportingAmend`.
abstract class NodePrototypeSupportingAmend {
  /// A [NodeBuilder] that amends [base] rather than starting from scratch.
  NodeBuilder amendingBuilder(Node base);
}

/// Traverses a map [Node], yielding key-value pairs. Equivalent to
/// go-ipld-prime's `MapIterator`.
abstract class MapIterator {
  /// The next key-value pair. Throws [IteratorOverreadException] (or
  /// another exception, for advanced/incrementally-loaded data) if called
  /// after [done] became `true`.
  (Node key, Node value) next();

  /// Whether iteration is complete.
  bool done();
}

/// Traverses a list [Node], yielding index-value pairs. Indices yielded
/// range from 0 to `length - 1`, sequentially. Equivalent to
/// go-ipld-prime's `ListIterator`.
abstract class ListIterator {
  /// The next index-value pair. Throws [IteratorOverreadException] (or
  /// another exception, for advanced/incrementally-loaded data) if called
  /// after [done] became `true`.
  (int index, Node value) next();

  /// Whether iteration is complete.
  bool done();
}
