// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/path_segment.dart
//
// Port of go-ipld-prime's datamodel/pathSegment.go: a map key or list
// index, "stringly typed" -- it may be interpreted as either depending on
// context. Go stores a string-or-int union via a struct with both fields
// and a sentinel (negative int means "the string is the real value");
// ported the same way, since Dart has no lighter-weight union either.
/// A single step in a Path: either a map key or a list index. Equivalent
/// to go-ipld-prime's `PathSegment`.
class PathSegment {
  /// Boxes [s] into a path segment. Equivalent to go-ipld-prime's
  /// `PathSegmentOfString` (and, since there is no escaping mechanism
  /// specified, also `ParsePathSegment`).
  const PathSegment.ofString(this._s) : _i = -1;

  /// Boxes [i] into a path segment. Equivalent to go-ipld-prime's
  /// `PathSegmentOfInt`.
  const PathSegment.ofInt(int i) : _s = '', _i = i;

  final String _s;
  final int _i;

  /// The path segment with no value. NOT the same as `PathSegment.ofInt(0)`
  /// -- this is `PathSegment.ofString('')`. Equivalent to go-ipld-prime's
  /// `EmptyPathSegment`.
  static const empty = PathSegment.ofString('');

  bool get _containsString => _i < 0;

  /// This segment as a string. Equivalent to go-ipld-prime's
  /// `PathSegment.String`.
  @override
  String toString() => _containsString ? _s : _i.toString();

  /// This segment as an integer. Throws [FormatException] if it's a string
  /// that can't be parsed as one. Equivalent to go-ipld-prime's
  /// `PathSegment.Index`.
  int index() {
    if (!_containsString) return _i;
    final parsed = int.tryParse(_s);
    if (parsed == null) {
      throw FormatException('invalid integer path segment', _s);
    }
    return parsed;
  }

  /// Whether this segment equals [other], comparing by string value
  /// regardless of which one is stored as a string vs. an int internally
  /// (so `PathSegment.ofInt(2).equals(PathSegment.ofString('2'))` is
  /// `true`). Equivalent to go-ipld-prime's `PathSegment.Equals`.
  bool equals(PathSegment other) {
    if (!_containsString && !other._containsString) return _i == other._i;
    return toString() == other.toString();
  }
}
