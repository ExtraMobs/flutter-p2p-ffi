// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/xor_keyspace.dart
//
// Port of go-libp2p-kbucket/keyspace's xor.go: a KeySpace that normalizes
// identifiers via SHA-256 and measures distance by XOR-ing keys together
// (the metric Kademlia routing tables use).
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;

import 'keyspace.dart';

/// A [KeySpace] that normalizes identifiers using SHA-256 and measures
/// distance by XOR-ing keys together. Equivalent to go-libp2p-kbucket's
/// `keyspace.XORKeySpace` (`xorKeySpace`).
class XorKeySpace implements KeySpace {
  const XorKeySpace._();

  /// The singleton XOR key space instance.
  static const XorKeySpace instance = XorKeySpace._();

  @override
  KeyspaceKey key(Uint8List id) {
    final hash = Uint8List.fromList(pkg_crypto.sha256.convert(id).bytes);
    return KeyspaceKey(space: this, original: id, bytes: hash);
  }

  @override
  int compare(KeyspaceKey a, KeyspaceKey b) => _compareBytes(a.bytes, b.bytes);

  @override
  bool keyEqual(KeyspaceKey a, KeyspaceKey b) => compare(a, b) == 0;

  @override
  BigInt distance(KeyspaceKey a, KeyspaceKey b) {
    final xored = xorBytes(a.bytes, b.bytes);
    var result = BigInt.zero;
    for (final byte in xored) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}

/// The number of leading zero bits in [id]. Equivalent to
/// go-libp2p-kbucket's `keyspace.ZeroPrefixLen`.
int zeroPrefixLen(Uint8List id) {
  for (var i = 0; i < id.length; i++) {
    final byte = id[i];
    if (byte != 0) {
      return i * 8 + _leadingZeros8(byte);
    }
  }
  return id.length * 8;
}

/// XORs [a] and [b] byte-by-byte (must be the same length). Equivalent to
/// go-libp2p-kbucket's `keyspace.Xor`.
Uint8List xorBytes(Uint8List a, Uint8List b) {
  final out = Uint8List(a.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = a[i] ^ b[i];
  }
  return out;
}

int _leadingZeros8(int byte) {
  var count = 0;
  for (var bit = 7; bit >= 0; bit--) {
    if ((byte & (1 << bit)) != 0) break;
    count++;
  }
  return count;
}

int _compareBytes(Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}
