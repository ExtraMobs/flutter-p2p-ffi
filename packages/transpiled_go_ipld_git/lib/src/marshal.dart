// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/marshal.go.
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'blob.dart';
import 'commit.dart';
import 'tag.dart';
import 'tree.dart';

/// Encodes an IPLD git node to [w].
void encode(Node n, Sink<List<int>> w) {
  switch (n.kind()) {
    case Kind.bytes:
      encodeBlob(n, w);
    case Kind.list:
      encodeTree(n, w);
    case Kind.map:
      final it = n.mapIterator();
      if (it == null || it.done()) {
        encodeTree(n, w);
        return;
      }
      final (firstKey, firstVal) = it.next();
      final keyStr = firstKey.asString();

      // Check if it's a Tag
      if (keyStr == 'object' ||
          keyStr == 'type' ||
          keyStr == 'tag' ||
          keyStr == 'tagger' ||
          keyStr == 'text') {
        encodeTag(n, w);
        return;
      }

      // Check if it's a Commit
      if (keyStr == 'tree' ||
          keyStr == 'parents' ||
          keyStr == 'author' ||
          keyStr == 'committer' ||
          keyStr == 'encoding' ||
          keyStr == 'signature' ||
          keyStr == 'other' ||
          keyStr == 'message') {
        encodeCommit(n, w);
        return;
      }

      // Otherwise, it's a tree mapping filenames to tree entries
      encodeTree(n, w);
    default:
      throw FormatException('unrecognized git object kind: ${n.kind()}');
  }
}
