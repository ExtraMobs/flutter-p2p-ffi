// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/util.dart
//
// Port of go-libp2p-kbucket's util.go.
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import 'key_prefix_map.dart';
import 'xor_keyspace.dart';

/// Thrown when a routing table query returns no results. NOT expected in
/// normal operation. Equivalent to go-libp2p-kbucket's `ErrLookupFailure`.
class LookupFailureException implements Exception {
  /// Creates the exception.
  const LookupFailureException();
  @override
  String toString() => 'failed to find any peer in table';
}

/// The maximum common-prefix length supported for peer-ID preimage
/// generation, since these are computed via a static lookup table.
/// Equivalent to go-libp2p-kbucket's `PeerIDPreimageMaxCpl`.
const int peerIdPreimageMaxCpl = 15;

/// A DHT identifier: the SHA-256 hash of either a [PeerId] or a string key,
/// unifying the two into the same XOR-metric keyspace. Equivalent to
/// go-libp2p-kbucket's `ID` (`type ID []byte`).
typedef DhtId = Uint8List;

/// XORs [a] and [b]. Equivalent to go-libp2p-kbucket's `Xor`.
DhtId xor(DhtId a, DhtId b) => xorBytes(a, b);

/// The number of bits [a] and [b] share as a common prefix. Equivalent to
/// go-libp2p-kbucket's `CommonPrefixLen`.
int commonPrefixLen(DhtId a, DhtId b) => zeroPrefixLen(xor(a, b));

/// Hashes [id] into the DHT's XOR keyspace. Equivalent to
/// go-libp2p-kbucket's `ConvertPeerID`.
DhtId convertPeerId(PeerId id) =>
    Uint8List.fromList(pkg_crypto.sha256.convert(id.value).bytes);

/// Hashes a local string [key] into the DHT's XOR keyspace. Equivalent to
/// go-libp2p-kbucket's `ConvertKey`.
DhtId convertKey(String key) =>
    Uint8List.fromList(pkg_crypto.sha256.convert(key.codeUnits).bytes);

/// Whether peer [a] is closer to [key] than peer [b] is. Equivalent to
/// go-libp2p-kbucket's `Closer`.
bool closer(PeerId a, PeerId b, String key) {
  final aId = convertPeerId(a);
  final bId = convertPeerId(b);
  final target = convertKey(key);
  final aDist = xor(aId, target);
  final bDist = xor(bId, target);
  return _compareBytes(aDist, bDist) < 0;
}

/// Reads a cryptographically-random 16-bit prefix. Equivalent to
/// go-libp2p-kbucket's `randUint16`.
int randUint16() {
  final bytes = Uint8List(2);
  final random = Random.secure();
  bytes[0] = random.nextInt(256);
  bytes[1] = random.nextInt(256);
  return (bytes[0] << 8) | bytes[1];
}

/// Generates a random peer ID sharing a common prefix of length [cpl] with
/// [targetId] (the local ID's DHT-keyspace form). Equivalent to
/// go-libp2p-kbucket's `GenRandPeerIDWithCPL`.
PeerId genRandPeerIdWithCpl(DhtId targetId, int cpl) {
  if (cpl > peerIdPreimageMaxCpl) {
    throw ArgumentError(
      'cannot generate peer ID for Cpl greater than $peerIdPreimageMaxCpl',
    );
  }
  final localPrefix = (targetId[0] << 8) | targetId[1];

  // For host with ID `L`, an ID `K` belongs to a bucket with ID `B` ONLY IF
  // CommonPrefixLen(L,K) is EXACTLY B. Hence, to achieve a targetPrefix
  // `T`, we must toggle the (T+1)th bit in L & then copy (T+1) bits from L
  // to our randomly generated prefix.
  final toggledLocalPrefix = localPrefix ^ (0x8000 >> cpl);
  final randPrefix = randUint16();

  // Combine the toggled local prefix and the random bits at the correct
  // offset such that ONLY the first `targetCpl` bits match the local ID.
  final mask = (0xFFFF << (16 - (cpl + 1))) & 0xFFFF;
  final targetPrefix = (toggledLocalPrefix & mask) | (randPrefix & ~mask & 0xFFFF);

  // Convert to a known peer ID.
  final key = keyPrefixMap[targetPrefix];
  final id = Uint8List(34)
    ..[0] = 0x12
    ..[1] = 0x20;
  id.buffer.asByteData().setUint32(2, key, Endian.big);
  return PeerId(value: id);
}

int _compareBytes(Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}
