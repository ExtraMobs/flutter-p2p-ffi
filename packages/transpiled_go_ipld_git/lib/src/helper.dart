// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/helper.go.
import 'dart:typed_data';

import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'unmarshal.dart';

/// Parses a git object from an in-memory buffer.
Node parseObjectFromBuffer(Uint8List b) => parseObject(b);

/// Attempts to parse a serialized IPFS block with `git-raw` codec into an IPLD node.
Node decodeBlock(Block block) {
  final cid = block.cid();
  if (cid.codec != 'git-raw') {
    throw FormatException(
      'invalid cid codec for git block, expected git-raw, got ${cid.codec}',
    );
  }
  return parseObjectFromBuffer(block.rawData());
}
