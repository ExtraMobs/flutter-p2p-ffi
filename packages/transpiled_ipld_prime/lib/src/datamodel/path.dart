// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/path.dart
//
// Port of go-ipld-prime's datamodel/path.go: a series of steps (map keys or
// list indexes) across a tree of Node, always relative, with no "up" or
// "stay here" segments (unlike filesystem paths).
import 'path_segment.dart';

/// A path across a tree or DAG of [Node], as a list of [PathSegment].
/// Equivalent to go-ipld-prime's `Path`.
class Path {
  /// Creates a path from a defensive copy of [segments]. Equivalent to
  /// go-ipld-prime's `NewPath`.
  Path(List<PathSegment> segments) : _segments = List.of(segments);

  /// Creates a path from [segments] without copying -- only safe if the
  /// caller will not mutate [segments] afterward. Equivalent to
  /// go-ipld-prime's `NewPathNocopy`.
  Path.nocopy(List<PathSegment> segments) : _segments = segments;

  /// Parses [s] into a path, splitting on `/` (collapsing repeats, and
  /// discarding leading/trailing separators). Not general-purpose or
  /// spec-compliant -- it can't represent paths with empty segments or
  /// segments containing `/`. Equivalent to go-ipld-prime's `ParsePath`.
  factory Path.parse(String s) {
    final parts = s.split('/').where((p) => p.isNotEmpty);
    return Path.nocopy([for (final p in parts) PathSegment.ofString(p)]);
  }

  const Path._(this._segments);

  final List<PathSegment> _segments;

  /// The path with no segments. Equivalent to go-ipld-prime's `EmptyPath`.
  static const empty = Path._([]);

  /// This path's segments as `/`-joined text, with no leading or trailing
  /// slash. Not general-purpose or spec-compliant -- see [Path.parse].
  /// Equivalent to go-ipld-prime's `Path.String`.
  @override
  String toString() => _segments.map((s) => s.toString()).join('/');

  /// This path's segments. Must not be mutated. Equivalent to
  /// go-ipld-prime's `Path.Segments`.
  List<PathSegment> get segments => _segments;

  /// The number of segments in this path (0 means "the current node").
  /// Equivalent to go-ipld-prime's `Path.Len`.
  int get length => _segments.length;

  /// A new path made of this path's segments followed by [other]'s.
  /// Equivalent to go-ipld-prime's `Path.Join`.
  Path join(Path other) => Path.nocopy([..._segments, ...other._segments]);

  /// A new path with [segment] appended. Equivalent to go-ipld-prime's
  /// `Path.AppendSegment`.
  Path appendSegment(PathSegment segment) =>
      Path.nocopy([..._segments, segment]);

  /// A new path with a string segment appended. Equivalent to
  /// go-ipld-prime's `Path.AppendSegmentString`.
  Path appendSegmentString(String s) => appendSegment(PathSegment.ofString(s));

  /// A new path with an int segment appended. Equivalent to
  /// go-ipld-prime's `Path.AppendSegmentInt`.
  Path appendSegmentInt(int i) => appendSegment(PathSegment.ofInt(i));

  /// This path with its last segment removed (or the empty path, if
  /// already empty). Equivalent to go-ipld-prime's `Path.Parent` (an alias
  /// of `Path.Pop` there).
  Path get parent => pop();

  /// This path truncated to its first [n] segments.
  /// Equivalent to go-ipld-prime's `Path.Truncate`.
  Path truncate(int n) => Path.nocopy(_segments.sublist(0, n));

  /// This path's trailing segment, or [PathSegment.empty] if this path has
  /// none. Equivalent to go-ipld-prime's `Path.Last`.
  PathSegment get last =>
      _segments.isEmpty ? PathSegment.empty : _segments.last;

  /// This path with its last segment removed (or the empty path, if
  /// already empty). Equivalent to go-ipld-prime's `Path.Pop`.
  Path pop() {
    if (_segments.isEmpty) return empty;
    return Path.nocopy(_segments.sublist(0, _segments.length - 1));
  }

  /// The first segment of this path, together with the remaining path
  /// after it. If this path is empty, returns [PathSegment.empty] and the
  /// empty path. Equivalent to go-ipld-prime's `Path.Shift`.
  (PathSegment, Path) shift() {
    if (_segments.isEmpty) return (PathSegment.empty, empty);
    return (_segments.first, Path.nocopy(_segments.sublist(1)));
  }
}
