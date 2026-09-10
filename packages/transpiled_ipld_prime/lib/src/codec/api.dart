// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's codec/api.go.
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';

/// Encodes an IPLD [Node] into a byte sink.
///
/// Equivalent to go-ipld-prime's `codec.Encoder`. Dart's synchronous
/// [Sink] and [Iterable] are used in place of Go's `io.Writer`/`io.Reader`.
typedef Encoder = void Function(Node node, Sink<List<int>> writer);

/// Decodes bytes into an IPLD [NodeAssembler].
///
/// Equivalent to go-ipld-prime's `codec.Decoder`.
typedef Decoder = void Function(NodeAssembler assembler, Iterable<int> reader);

/// Thrown when a decoder's resource budget is exhausted.
///
/// Equivalent to go-ipld-prime's `codec.ErrBudgetExhausted`.
final class BudgetExhaustedException implements Exception {
  /// Creates the exception.
  const BudgetExhaustedException();

  @override
  String toString() =>
      'decoder resource budget exhausted (message too long or too complex)';
}

/// Controls map-key ordering during encoding.
///
/// The declaration order and values match go-ipld-prime's
/// `codec.MapSortMode` constants.
enum MapSortMode {
  /// Preserve the node's iteration order.
  none,

  /// Sort keys lexically.
  lexical,

  /// Sort keys using RFC 7049's canonical CBOR ordering.
  rfc7049,
}
