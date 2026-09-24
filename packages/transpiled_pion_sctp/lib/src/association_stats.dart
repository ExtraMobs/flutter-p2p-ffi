// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `association_stats.go` (github.com/pion/sctp):
/// [AssociationStats], the small set of debug counters an `Association`
/// keeps and logs on close.
///
/// `associationStats` is unexported in Go; [AssociationStats] stays public
/// within `lib/src` (see util.dart's file-level doc comment) but is not
/// exported from `transpiled_pion_sctp.dart`.
///
/// Go guards every counter with `sync/atomic` (association_stats.go:7,21...)
/// solely because multiple goroutines (the read loop, the write loop, and
/// any caller of a public `Association` method) can increment/read them
/// concurrently. Dart's single-threaded event loop makes plain `int` fields
/// equivalent in every observable outcome, per `RULE_NO_ARTIFICIAL_CONCURRENCY`.
library;

/// Port of `associationStats` (association_stats.go:10-19).
final class AssociationStats {
  int _nPacketsReceived = 0;
  int _nPacketsSent = 0;
  int _nDatas = 0;
  int _nSacksReceived = 0;
  int _nSacksSent = 0;
  int _nT3Timeouts = 0;
  int _nAckTimeouts = 0;
  int _nFastRetrans = 0;

  /// Port of `associationStats.incPacketsReceived` (association_stats.go:21-23).
  void incPacketsReceived() => _nPacketsReceived++;

  /// Port of `associationStats.getNumPacketsReceived` (association_stats.go:25-27).
  int getNumPacketsReceived() => _nPacketsReceived;

  /// Port of `associationStats.incPacketsSent` (association_stats.go:29-31).
  void incPacketsSent() => _nPacketsSent++;

  /// Port of `associationStats.getNumPacketsSent` (association_stats.go:33-35).
  int getNumPacketsSent() => _nPacketsSent;

  /// Port of `associationStats.incDATAs` (association_stats.go:37-39).
  void incDatas() => _nDatas++;

  /// Port of `associationStats.getNumDATAs` (association_stats.go:41-43).
  int getNumDatas() => _nDatas;

  /// Port of `associationStats.incSACKsReceived` (association_stats.go:45-47).
  void incSacksReceived() => _nSacksReceived++;

  /// Port of `associationStats.getNumSACKsReceived` (association_stats.go:49-51).
  int getNumSacksReceived() => _nSacksReceived;

  /// Port of `associationStats.incSACKsSent` (association_stats.go:53-55).
  void incSacksSent() => _nSacksSent++;

  /// Port of `associationStats.getNumSACKsSent` (association_stats.go:57-59).
  int getNumSacksSent() => _nSacksSent;

  /// Port of `associationStats.incT3Timeouts` (association_stats.go:61-63).
  void incT3Timeouts() => _nT3Timeouts++;

  /// Port of `associationStats.getNumT3Timeouts` (association_stats.go:65-67).
  int getNumT3Timeouts() => _nT3Timeouts;

  /// Port of `associationStats.incAckTimeouts` (association_stats.go:69-71).
  void incAckTimeouts() => _nAckTimeouts++;

  /// Port of `associationStats.getNumAckTimeouts` (association_stats.go:73-75).
  int getNumAckTimeouts() => _nAckTimeouts;

  /// Port of `associationStats.incFastRetrans` (association_stats.go:77-79).
  void incFastRetrans() => _nFastRetrans++;

  /// Port of `associationStats.getNumFastRetrans` (association_stats.go:81-83).
  int getNumFastRetrans() => _nFastRetrans;

  /// Port of `associationStats.reset` (association_stats.go:85-94).
  void reset() {
    _nPacketsReceived = 0;
    _nPacketsSent = 0;
    _nDatas = 0;
    _nSacksReceived = 0;
    _nSacksSent = 0;
    _nT3Timeouts = 0;
    _nAckTimeouts = 0;
    _nFastRetrans = 0;
  }
}
