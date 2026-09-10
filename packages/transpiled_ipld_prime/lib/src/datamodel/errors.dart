// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/errors.dart
//
// Port of go-ipld-prime's datamodel/errors.go. Go returns these as the
// `error` half of a `(value, error)` pair; ported as thrown exceptions
// instead, matching this project's established Dart convention (e.g.
// transpiled_libp2p's PeerId methods) rather than mechanically threading
// error returns through every Node method.
import 'kind.dart';
import 'path_segment.dart';

/// Thrown by a [Node] method that doesn't make sense for that node's
/// [Kind] (e.g. calling `asString` on a map). Equivalent to
/// go-ipld-prime's `ErrWrongKind`.
class WrongKindException implements Exception {
  /// Creates the exception.
  const WrongKindException({
    this.typeName = '',
    required this.methodName,
    required this.appropriateKind,
    required this.actualKind,
  });

  /// The node's named type, if it was typed; empty otherwise.
  final String typeName;

  /// The name of the operation attempted, e.g. `'asString'`.
  final String methodName;

  /// Which kinds the erroring method would make sense for.
  final KindSet appropriateKind;

  /// The kind of the node the method was called on.
  final Kind actualKind;

  @override
  String toString() => typeName.isEmpty
      ? 'func called on wrong kind: "$methodName" called on a $actualKind '
            'node, but only makes sense on $appropriateKind'
      : 'func called on wrong kind: "$methodName" called on a $typeName '
            'node (kind: $actualKind), but only makes sense on $appropriateKind';
}

/// Thrown by a [Node] lookup method to indicate a missing value.
/// Equivalent to go-ipld-prime's `ErrNotExists`.
class NotExistsException implements Exception {
  /// Creates the exception.
  const NotExistsException(this.segment);

  /// The segment that couldn't be found.
  final PathSegment segment;

  @override
  String toString() => 'key not found: "$segment"';
}

/// Thrown when a key is inserted into a map that already contains it.
/// Equivalent to go-ipld-prime's `ErrRepeatedMapKey`.
class RepeatedMapKeyException implements Exception {
  /// Creates the exception.
  const RepeatedMapKeyException(this.key);

  /// The repeated key.
  final Object key;

  @override
  String toString() => 'cannot repeat map key "$key"';
}

/// Thrown by [Node.lookupBySegment] when the given [PathSegment] can't be
/// applied to a list because it's unparsable as a number. Equivalent to
/// go-ipld-prime's `ErrInvalidSegmentForList`.
class InvalidSegmentForListException implements Exception {
  /// Creates the exception.
  const InvalidSegmentForListException({
    this.typeName = '',
    required this.troubleSegment,
    this.reason,
  });

  /// The node's named type, or empty string if untyped.
  final String typeName;

  /// The segment that couldn't be used.
  final PathSegment troubleSegment;

  /// Why the segment couldn't be used, if known.
  final Object? reason;

  @override
  String toString() {
    var v = 'invalid segment for lookup on a list';
    if (typeName.isNotEmpty) v += ' of type $typeName';
    return '$v: "$troubleSegment": $reason';
  }
}

/// Thrown by calling `next` on a map or list iterator that's already done.
/// Equivalent to go-ipld-prime's `ErrIteratorOverread`.
class IteratorOverreadException implements Exception {
  /// Creates the exception.
  const IteratorOverreadException();

  @override
  String toString() => 'iterator overread';
}
