// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/util.go.
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

/// Length of a git object hash in bytes (SHA-1 = 20 bytes).
const int gitShaLen = 20;

/// Converts a 20-byte SHA-1 digest into a CIDv1 with multicodec git-raw (0x78).
Cid shaToCid(Uint8List sha) {
  if (sha.length != gitShaLen) {
    throw FormatException(
      'invalid git sha of ${sha.length} bytes, expected $gitShaLen',
    );
  }
  final h = encodeName(sha, 'sha1');
  final mh = decode(h);
  return Cid(version: 1, multihash: mh, codec: 'git-raw');
}

/// Extracts the 20-byte SHA-1 digest from a CID.
Uint8List cidToSha(Cid c) {
  final digest = c.multihash.digest;
  if (digest.length < 20) {
    throw const FormatException('multihash digest is too short for git sha');
  }
  return digest.sublist(digest.length - 20);
}

/// Extracts the SHA-1 digest from an IPLD Link, or null if not a CidLink.
Uint8List? linkToSha(Link? l) {
  if (l is CidLink) {
    return cidToSha(l.cid);
  }
  return null;
}

/// Reads a number terminated by 0x00 from [bytes] starting at [offset].
/// Returns `(number, nextOffset)`.
(int, int) readNullTerminatedNumber(Uint8List bytes, int offset) {
  var end = offset;
  while (end < bytes.length && bytes[end] != 0) {
    end++;
  }
  if (end >= bytes.length) {
    throw const FormatException('unexpected EOF reading null-terminated number');
  }
  final str = String.fromCharCodes(bytes.sublist(offset, end));
  final n = int.parse(str.trim());
  return (n, end + 1);
}
