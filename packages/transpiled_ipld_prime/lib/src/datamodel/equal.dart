// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/equal.dart
//
// Port of go-ipld-prime's datamodel/equal.go.
import 'dart:typed_data';

import 'kind.dart';
import 'node.dart';

/// Whether [x] and [y] are "deeply equal" as IPLD nodes: same [Kind];
/// scalars compared by value; maps/lists compared by length then
/// elementwise via their iterators (so two maps with the same entries in
/// different orders are NOT equal, and links are compared shallowly,
/// without being followed). `null` is only equal to `null`. Nodes with
/// [Kind.invalid] are never deeply equal, even to themselves. Equivalent
/// to go-ipld-prime's `DeepEqual`.
bool deepEqual(Node? x, Node? y) {
  if (x == null || y == null) return x == y;
  final xk = x.kind();
  final yk = y.kind();
  if (xk != yk) return false;

  switch (xk) {
    case Kind.null_:
      return x.isNull() == y.isNull();
    case Kind.bool_:
      return x.asBool() == y.asBool();
    case Kind.int_:
      return x.asInt() == y.asInt();
    case Kind.float:
      return x.asFloat() == y.asFloat();
    case Kind.string:
      return x.asString() == y.asString();
    case Kind.bytes:
      return _bytesEqual(x.asBytes(), y.asBytes());
    case Kind.link:
      return x.asLink() == y.asLink();
    case Kind.map:
      if (x.length() != y.length()) return false;
      final xitr = x.mapIterator()!;
      final yitr = y.mapIterator()!;
      while (!xitr.done() && !yitr.done()) {
        final (xkey, xval) = xitr.next();
        final (ykey, yval) = yitr.next();
        if (!deepEqual(xkey, ykey)) return false;
        if (!deepEqual(xval, yval)) return false;
      }
      return true;
    case Kind.list:
      if (x.length() != y.length()) return false;
      final xitr = x.listIterator()!;
      final yitr = y.listIterator()!;
      while (!xitr.done() && !yitr.done()) {
        final (_, xval) = xitr.next();
        final (_, yval) = yitr.next();
        if (!deepEqual(xval, yval)) return false;
      }
      return true;
    case Kind.invalid:
      return false;
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
