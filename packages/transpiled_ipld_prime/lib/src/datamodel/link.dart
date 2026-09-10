// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/link.dart
//
// Port of go-ipld-prime's datamodel/link.go: a special kind of scalar
// value that can be "loaded" to access more nodes. The most common
// implementation (from `linking/cid`) represents CIDs -- not ported yet,
// see doc/transpilation/PROGRESS.md.
/// A value that can be "loaded" to access more nodes -- the IPLD Data
/// Model's `link` kind. Equivalent to go-ipld-prime's `Link`.
abstract class Link {
  /// A [LinkPrototype] that can make more links similar to this one (but
  /// with different hashes).
  LinkPrototype prototype();

  /// A human-readable debug representation of this link. Not guaranteed
  /// parsable back into a [Link], but must be unique (no eliding hash
  /// parts).
  @override
  String toString();

  /// The densest possible encoding of this link, as raw bytes. Not
  /// guaranteed parsable back into a [Link] via
  /// `prototype().buildLink(binary)` -- this may include additional
  /// framing (e.g. a Cid's version/codec/multihash-type bytes) beyond what
  /// the hash alone carries.
  List<int> binary();
}

/// Encapsulates the implementation details and parameters needed to build
/// a [Link], except for the hash result itself. Equivalent to
/// go-ipld-prime's `LinkPrototype`.
abstract class LinkPrototype {
  /// Builds a new [Link] from [hashsum] (typically a hash digest). The
  /// caller may reuse [hashsum] afterward -- implementations must not
  /// retain a reference to it.
  Link buildLink(List<int> hashsum);
}
