// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/unmarshal.go.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'blob.dart';
import 'commit.dart';
import 'tag.dart';
import 'tree.dart';

/// Decodes git object bytes from [r] into [na].
void decode(NodeAssembler na, Iterable<int> r) {
  final bytes = r is Uint8List ? r : Uint8List.fromList(r.toList());
  if (bytes.isEmpty) {
    throw const FormatException('unexpected EOF reading git object header');
  }

  var spacePos = 0;
  while (spacePos < bytes.length && bytes[spacePos] != 0x20) {
    spacePos++;
  }
  if (spacePos >= bytes.length) {
    throw const FormatException('unexpected EOF reading git object type');
  }

  final typ = utf8.decode(bytes.sublist(0, spacePos));
  final offset = spacePos + 1;

  switch (typ) {
    case 'tree':
      decodeTree(na, bytes, offset);
    case 'commit':
      decodeCommit(na, bytes, offset);
    case 'blob':
      decodeBlob(na, bytes, offset);
    case 'tag':
      decodeTag(na, bytes, offset);
    default:
      throw FormatException('unrecognized git object type: "$typ"');
  }
}

/// Parses an input byte stream and produces an IPLD [Node].
Node parseObject(Iterable<int> r) {
  final builder = AnyBuilder();
  decode(builder, r);
  return builder.build();
}
