// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/commit.go.
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

/// Decodes a git commit from [bytes] at [offset] into [na].
int decodeCommit(NodeAssembler na, Uint8List bytes, int offset) {
  final (size, bodyStart) = readNullTerminatedNumber(bytes, offset);
  final bodyEnd = bodyStart + size;
  if (bodyEnd > bytes.length) {
    throw const FormatException('unexpected EOF reading commit body');
  }

  final bodyText = utf8.decode(bytes.sublist(bodyStart, bodyEnd));
  final lines = bodyText.split('\n');

  Link? treeLink;
  final parentLinks = <Link>[];
  PersonInfo? author;
  PersonInfo? committer;
  String? encoding;
  String? gpgSig;
  final otherLines = <String>[];
  var message = '';

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.isEmpty) {
      // Empty line marks start of commit message
      message = lines.sublist(i + 1).join('\n');
      break;
    }

    if (line.startsWith('tree ')) {
      final shaHex = line.substring(5).trim();
      final sha = _hexDecode(shaHex);
      treeLink = CidLink(shaToCid(sha));
    } else if (line.startsWith('parent ')) {
      final shaHex = line.substring(7).trim();
      final sha = _hexDecode(shaHex);
      parentLinks.add(CidLink(shaToCid(sha)));
    } else if (line.startsWith('author ')) {
      author = parsePersonInfo(Uint8List.fromList(utf8.encode(line)));
    } else if (line.startsWith('committer ')) {
      committer = parsePersonInfo(Uint8List.fromList(utf8.encode(line)));
    } else if (line.startsWith('encoding ')) {
      encoding = line.substring(9).trim();
    } else if (line.startsWith('gpgsig ')) {
      // Signature starts on this line or continuation lines
      final sigBuf = StringBuffer();
      i++;
      while (i < lines.length) {
        final sigLine = lines[i];
        if (sigLine.startsWith(' -----END PGP SIGNATURE-----')) {
          break;
        }
        sigBuf.writeln(sigLine);
        i++;
      }
      gpgSig = sigBuf.toString();
    } else {
      otherLines.add(line);
    }
    i++;
  }

  if (treeLink == null) {
    throw const FormatException('commit missing tree link');
  }

  final mapData = <String, Node>{
    'tree': PlainLink(treeLink),
    'parents': PlainList([for (final p in parentLinks) PlainLink(p)]),
    if (author != null) 'author': author.toNode(),
    if (committer != null) 'committer': committer.toNode(),
    if (encoding != null) 'encoding': PlainString(encoding),
    if (gpgSig != null) 'signature': PlainString(gpgSig),
    if (otherLines.isNotEmpty)
      'other': PlainList([for (final o in otherLines) PlainString(o)]),
    'message': PlainString(message),
  };

  na.assignNode(PlainMap(mapData));
  return bodyEnd;
}

/// Encodes an IPLD commit node to [w].
void encodeCommit(Node n, Sink<List<int>> w) {
  final buf = StringBuffer();

  final treeLink = n.lookupByString('tree').asLink();
  final treeSha = linkToSha(treeLink);
  if (treeSha == null) {
    throw FormatException('invalid commit tree link: $treeLink');
  }
  buf.write('tree ${_hexEncode(treeSha)}\n');

  try {
    final parentsNode = n.lookupByString('parents');
    if (!parentsNode.isAbsent()) {
      final len = parentsNode.length();
      for (var i = 0; i < len; i++) {
        final pLink = parentsNode.lookupByIndex(i).asLink();
        final pSha = linkToSha(pLink);
        if (pSha != null) {
          buf.write('parent ${_hexEncode(pSha)}\n');
        }
      }
    }
  } catch (_) {}

  try {
    final authorNode = n.lookupByString('author');
    if (!authorNode.isAbsent()) {
      final author = PersonInfo.fromNode(authorNode);
      buf.write('author ${author.gitString()}\n');
    }
  } catch (_) {}

  try {
    final committerNode = n.lookupByString('committer');
    if (!committerNode.isAbsent()) {
      final committer = PersonInfo.fromNode(committerNode);
      buf.write('committer ${committer.gitString()}\n');
    }
  } catch (_) {}

  try {
    final encNode = n.lookupByString('encoding');
    if (!encNode.isAbsent()) {
      buf.write('encoding ${encNode.asString()}\n');
    }
  } catch (_) {}

  try {
    final sigNode = n.lookupByString('signature');
    if (!sigNode.isAbsent()) {
      buf.write('gpgsig -----BEGIN PGP SIGNATURE-----\n');
      buf.write(sigNode.asString());
      buf.write(' -----END PGP SIGNATURE-----\n');
    }
  } catch (_) {}

  try {
    final otherNode = n.lookupByString('other');
    if (!otherNode.isAbsent()) {
      final len = otherNode.length();
      for (var i = 0; i < len; i++) {
        buf.write('${otherNode.lookupByIndex(i).asString()}\n');
      }
    }
  } catch (_) {}

  String message = '';
  try {
    final msgNode = n.lookupByString('message');
    if (!msgNode.isAbsent()) {
      message = msgNode.asString();
    }
  } catch (_) {}

  buf.write('\n$message');

  final bodyBytes = utf8.encode(buf.toString());
  final header = utf8.encode('commit ${bodyBytes.length}\x00');
  w.add(header);
  w.add(bodyBytes);
}
