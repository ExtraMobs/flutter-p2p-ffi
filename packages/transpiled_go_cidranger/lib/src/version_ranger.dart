part of '../transpiled_go_cidranger.dart';

// Port of github.com/libp2p/go-cidranger/version.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md): dispatches to a per-IP-version
// [Ranger], since a single [_PrefixTrie] can't mix IPv4 and IPv6 entries.

/// Dispatches to one of two per-IP-version [Ranger]s. Equivalent to
/// go-cidranger's private `versionedRanger` (Dart-private for the same
/// reason as [_PrefixTrie]: reachable only via [Ranger.pcTrie]).
class _VersionedRanger implements Ranger {
  _VersionedRanger._(this._ipV4Ranger, this._ipV6Ranger);

  /// A dual IPv4/IPv6 [Ranger] backed by a [_PrefixTrie] per version.
  /// Equivalent to go-cidranger's `NewPCTrieRanger` (via
  /// `newVersionedRanger(newRanger)`).
  factory _VersionedRanger.pcTrie() => _VersionedRanger._(
    _PrefixTrie.tree(IpVersion.ipv4),
    _PrefixTrie.tree(IpVersion.ipv6),
  );

  final Ranger _ipV4Ranger;
  final Ranger _ipV6Ranger;

  @override
  void insert(RangerEntry entry) =>
      _rangerFor(entry.network().ip).insert(entry);

  @override
  RangerEntry? remove(IpNet network) => _rangerFor(network.ip).remove(network);

  @override
  bool contains(Ip ip) => _rangerFor(ip).contains(ip);

  @override
  List<RangerEntry> containingNetworks(Ip ip) =>
      _rangerFor(ip).containingNetworks(ip);

  @override
  List<RangerEntry> coveredNetworks(IpNet network) =>
      _rangerFor(network.ip).coveredNetworks(network);

  @override
  int get length => _ipV4Ranger.length + _ipV6Ranger.length;

  /// Equivalent to go-cidranger's private `versionedRanger.getRangerForIP`.
  Ranger _rangerFor(Ip ip) {
    if (ip.to4() != null) return _ipV4Ranger;
    if (ip.to16() != null) return _ipV6Ranger;
    throw const InvalidNetworkNumberInputException();
  }
}
