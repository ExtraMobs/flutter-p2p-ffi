// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/tag.go.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'personinfo.dart';
import 'util.dart';

Uint8List _hexDecode(String hex) {
  final clean = hex.trim();
  final len = clean.length;
  final result = Uint8List(len ~/ 2);
  for (var i = 0; i < len; i += 2) {
    result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
  }
  return result;
}

String _hexEncode(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Decodes a git tag from [bytes] at [offset] into [na].
int decodeTag(NodeAssembler na, Uint8List bytes, int offset) {
  final (size, bodyStart) = readNullTerminatedNumber(bytes, offset);
  final bodyEnd = bodyStart + size;
  if (bodyEnd > bytes.length) {
    throw const FormatException('unexpected EOF reading tag body');
  }

  final bodyText = utf8.decode(bytes.sublist(bodyStart, bodyEnd));
  final lines = bodyText.split('\n');

  Link? objectLink;
  var type = '';
  var tag = '';
  PersonInfo? tagger;
  var message = '';

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.isEmpty) {
      message = lines.sublist(i + 1).join('\n');
      break;
    }

    if (line.startsWith('object ')) {
      final shaHex = line.substring(7).trim();
      final sha = _hexDecode(shaHex);
      objectLink = CidLink(shaToCid(sha));
    } else if (line.startsWith('type ')) {
      type = line.substring(5).trim();
    } else if (line.startsWith('tag ')) {
      tag = line.substring(4).trim();
    } else if (line.startsWith('tagger ')) {
      tagger = parsePersonInfo(Uint8List.fromList(utf8.encode(line)));
    }
    i++;
  }

  if (objectLink == null) {
    throw const FormatException('tag missing object link');
  }

  final mapData = <String, Node>{
    'object': PlainLink(objectLink),
    'type': PlainString(type),
    'tag': PlainString(tag),
    if (tagger != null) 'tagger': tagger.toNode(),
    'message': PlainString(message),
  };

  na.assignNode(PlainMap(mapData));
  return bodyEnd;
}

/// Encodes an IPLD tag node to [w].
void encodeTag(Node n, Sink<List<int>> w) {
  final buf = StringBuffer();

  final objLink = n.lookupByString('object').asLink();
  final objSha = linkToSha(objLink);
  if (objSha == null) {
    throw FormatException('invalid tag object link: $objLink');
  }
  buf.write('object ${_hexEncode(objSha)}\n');

  final typeStr = n.lookupByString('type').asString();
  buf.write('type $typeStr\n');

  final tagStr = n.lookupByString('tag').asString();
  buf.write('tag $tagStr\n');

  try {
    final taggerNode = n.lookupByString('tagger');
    if (!taggerNode.isAbsent()) {
      final tagger = PersonInfo.fromNode(taggerNode);
      buf.write('tagger ${tagger.gitString()}\n');
    }
  } catch (_) {}

  String message = '';
  try {
    final msgNode = n.lookupByString('message');
    if (!msgNode.isAbsent()) {
      message = msgNode.asString();
    }
  } catch (_) {}

  if (message.isNotEmpty) {
    buf.write('\n$message');
  }

  final bodyBytes = utf8.encode(buf.toString());
  final header = utf8.encode('tag ${bodyBytes.length}\x00');
  w.add(header);
  w.add(bodyBytes);
}
