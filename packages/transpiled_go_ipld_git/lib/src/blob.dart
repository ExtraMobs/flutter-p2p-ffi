// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/blob.go.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'util.dart';

/// Decodes a git blob from [bytes] at [offset] into [na].
int decodeBlob(NodeAssembler na, Uint8List bytes, int offset) {
  final (sizen, nextOffset) = readNullTerminatedNumber(bytes, offset);
  if (sizen < 0) {
    throw FormatException('invalid blob size: $sizen');
  }

  final prefix = utf8.encode('blob $sizen\x00');
  final bodyEnd = nextOffset + sizen;
  if (bodyEnd > bytes.length) {
    throw const FormatException('unexpected EOF reading blob body');
  }

  final fullBlob = Uint8List(prefix.length + sizen);
  fullBlob.setRange(0, prefix.length, prefix);
  fullBlob.setRange(prefix.length, fullBlob.length, bytes, nextOffset);

  na.assignBytes(fullBlob);
  return bodyEnd;
}

/// Encodes an IPLD blob node to [w].
void encodeBlob(Node n, Sink<List<int>> w) {
  final b = n.asBytes();
  w.add(b);
}
