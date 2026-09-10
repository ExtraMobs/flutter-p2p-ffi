// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/table_refresh.dart
//
// Port of go-libp2p-kbucket's table_refresh.go, as extension methods on
// RoutingTable (mirroring Go's same-package-multiple-files convention,
// since Dart has no direct equivalent of appending methods to a struct
// from a second file other than an extension).
import 'dart:math';
import 'dart:typed_data';

import 'table.dart';
import 'util.dart';

/// The maximum Cpl supported for refresh -- limited because the prefix
/// table can only generate that many bit prefixes. Equivalent to
/// go-libp2p-kbucket's `maxCplForRefresh`.
const int maxCplForRefresh = peerIdPreimageMaxCpl;

/// Refresh-related operations on [RoutingTable]. Equivalent to
/// go-libp2p-kbucket's `table_refresh.go` methods.
extension RoutingTableRefresh on RoutingTable {
  /// The Cpls this table is tracking for refresh, indexed by Cpl (a
  /// defensive copy). Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.GetTrackedCplsForRefresh`.
  List<DateTime> getTrackedCplsForRefresh() {
    final maxCommonPrefix = min(this.maxCommonPrefix(), maxCplForRefresh);
    final refreshedAt = cplRefreshedAt;
    final zero = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return [
      for (var i = 0; i <= maxCommonPrefix; i++) refreshedAt[i] ?? zero,
    ];
  }

  /// Generates a random peer ID for the given common-prefix-length.
  /// Equivalent to go-libp2p-kbucket's `RoutingTable.GenRandPeerID`.
  DhtId genRandPeerId(int targetCpl) =>
      genRandPeerIdWithCpl(convertPeerId(local), targetCpl).value;

  /// Generates a random key matching a provided common-prefix-length
  /// against the local identity. The returned key matches the first
  /// [targetCpl] bits of the local key, its next bit is the inverse of
  /// the local key's bit at that position, and the remaining bits are
  /// random. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.GenRandomKey`.
  DhtId genRandomKey(int targetCpl) {
    final localKey = convertPeerId(local);
    if (targetCpl + 1 >= localKey.length * 8) {
      throw ArgumentError('cannot generate peer ID for Cpl greater than key length');
    }
    final partialOffset = targetCpl ~/ 8;

    final output = Uint8List(localKey.length);
    output.setRange(0, partialOffset, localKey);
    final random = Random.secure();
    for (var i = partialOffset; i < output.length; i++) {
      output[i] = random.nextInt(256);
    }

    final remainingBits = 8 - targetCpl % 8;
    final orig = localKey[partialOffset];

    // Go's `^uint8(0) << remainingBits` / `^origMask` are bitwise-NOT on a
    // *fixed-width* byte (wraps at 8 bits); Dart's `~` is infinite-precision
    // two's complement, so every mask must be re-truncated to 8 bits with
    // `& 0xFF` after each `~`, or the two masks silently overlap.
    final origMask = (0xFF << remainingBits) & 0xFF;
    final randMask = (~origMask & 0xFF) >> 1;
    final flippedBitOffset = remainingBits - 1;
    final flippedBitMask = (1 << flippedBitOffset) & 0xFF;

    output[partialOffset] =
        (orig & origMask) |
        ((orig & flippedBitMask) ^ flippedBitMask) |
        (output[partialOffset] & randMask);

    return output;
  }

  /// Resets the refresh time for [id]'s common-prefix-length. Equivalent
  /// to go-libp2p-kbucket's `RoutingTable.ResetCplRefreshedAtForID`.
  void resetCplRefreshedAtForId(DhtId id, DateTime newTime) {
    final cpl = commonPrefixLen(id, convertPeerId(local));
    if (cpl > maxCplForRefresh) return;
    cplRefreshedAt[cpl] = newTime;
  }
}
