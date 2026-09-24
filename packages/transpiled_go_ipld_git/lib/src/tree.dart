// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/tree.go.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'util.dart';

/// Decodes a git tree entry starting at [offset] in [bytes].
/// Returns `(name, node, nextOffset)`.
(String, Node, int) decodeTreeEntry(Uint8List bytes, int offset) {
  var spacePos = offset;
  while (spacePos < bytes.length && bytes[spacePos] != 0x20) {
    spacePos++;
  }
  if (spacePos >= bytes.length) {
    throw const FormatException('unexpected EOF reading tree entry mode');
  }
  final modeStr = String.fromCharCodes(bytes.sublist(offset, spacePos));

  var nullPos = spacePos + 1;
  while (nullPos < bytes.length && bytes[nullPos] != 0) {
    nullPos++;
  }
  if (nullPos >= bytes.length) {
    throw const FormatException('unexpected EOF reading tree entry name');
  }
  final name = utf8.decode(bytes.sublist(spacePos + 1, nullPos));

  final shaStart = nullPos + 1;
  final shaEnd = shaStart + gitShaLen;
  if (shaEnd > bytes.length) {
    throw const FormatException('unexpected EOF reading tree entry sha');
  }
  final sha = bytes.sublist(shaStart, shaEnd);
  final cid = shaToCid(sha);

  final entryNode = PlainMap({
    'mode': PlainString(modeStr),
    'hash': PlainLink(CidLink(cid)),
  });

  return (name, entryNode, shaEnd);
}

/// Decodes a git tree from [bytes] starting at [offset] into [na].
int decodeTree(NodeAssembler na, Uint8List bytes, int offset) {
  final (size, bodyStart) = readNullTerminatedNumber(bytes, offset);
  final bodyEnd = bodyStart + size;
  if (bodyEnd > bytes.length) {
    throw const FormatException('unexpected EOF reading tree body');
  }

  final mapAssembler = na.beginMap(-1);
  var cur = bodyStart;
  while (cur < bodyEnd) {
    final (name, entryNode, next) = decodeTreeEntry(bytes, cur);
    final valAssembler = mapAssembler.assembleEntry(name);
    valAssembler.assignNode(entryNode);
    cur = next;
  }
  mapAssembler.finish();
  return bodyEnd;
}

/// Encodes an individual tree entry.
void encodeTreeEntry(String name, Node n, Sink<List<int>> w) {
  final modeNode = n.lookupByString('mode');
  final modeStr = modeNode.asString();
  final hashNode = n.lookupByString('hash');
  final link = hashNode.asLink();
  final shaBytes = linkToSha(link);
  if (shaBytes == null) {
    throw FormatException('invalid or non-CID link in tree entry: $link');
  }

  w.add(utf8.encode('$modeStr $name\x00'));
  w.add(shaBytes);
}

/// Encodes a git tree node to [w].
void encodeTree(Node n, Sink<List<int>> w) {
  final buf = <int>[];
  final sink = _BufferSink(buf);

  final it = n.mapIterator()!;
  while (!it.done()) {
    final (kNode, valNode) = it.next();
    final name = kNode.asString();
    encodeTreeEntry(name, valNode, sink);
  }

  final header = utf8.encode('tree ${buf.length}\x00');
  w.add(header);
  w.add(buf);
}

class _BufferSink implements Sink<List<int>> {
  _BufferSink(this._buffer);
  final List<int> _buffer;

  @override
  void add(List<int> data) => _buffer.addAll(data);

  @override
  void close() {}
}
