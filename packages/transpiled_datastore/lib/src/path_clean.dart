// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/path_clean.dart
//
// Port of Go stdlib's `path.Clean` (lexical path cleanup, forward-slash
// only, no OS-specific handling) -- go-datastore's Key.Clean relies on it
// directly. Go's version reuses the input buffer when nothing changes
// (a `lazybuf`); this port always allocates a fresh buffer for clarity,
// which is the only difference -- the character-by-character algorithm
// itself is copied line-for-line from Go's implementation.
const int _slash = 0x2F; // '/'
const int _dot = 0x2E; // '.'

/// Returns the shortest path name equivalent to [path] by purely lexical
/// processing. Equivalent to Go's `path.Clean`.
String cleanPath(String path) {
  if (path.isEmpty) return '.';

  final rooted = path.codeUnitAt(0) == _slash;
  final n = path.length;
  final out = <int>[];
  var r = rooted ? 1 : 0;
  var dotdot = rooted ? 1 : 0;
  if (rooted) out.add(_slash);

  while (r < n) {
    final c = path.codeUnitAt(r);
    if (c == _slash) {
      r++;
    } else if (c == _dot && (r + 1 == n || path.codeUnitAt(r + 1) == _slash)) {
      // A "." path element: skip it.
      r++;
    } else if (c == _dot &&
        r + 1 < n &&
        path.codeUnitAt(r + 1) == _dot &&
        (r + 2 == n || path.codeUnitAt(r + 2) == _slash)) {
      // A ".." path element: erase the last one, unless it's already at
      // the start of the (rooted or relative) output.
      r += 2;
      if (out.length > dotdot) {
        out.removeLast();
        while (out.length > dotdot && out.last != _slash) {
          out.removeLast();
        }
      } else if (!rooted) {
        if (out.isNotEmpty) out.add(_slash);
        out.add(_dot);
        out.add(_dot);
        dotdot = out.length;
      }
    } else {
      // A regular path element.
      if ((rooted && out.length != 1) || (!rooted && out.isNotEmpty)) {
        out.add(_slash);
      }
      while (r < n && path.codeUnitAt(r) != _slash) {
        out.add(path.codeUnitAt(r));
        r++;
      }
    }
  }

  if (out.isEmpty) return '.';
  return String.fromCharCodes(out);
}
