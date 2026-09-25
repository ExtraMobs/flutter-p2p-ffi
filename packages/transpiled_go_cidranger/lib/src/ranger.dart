part of '../transpiled_go_cidranger.dart';

// Port of github.com/libp2p/go-cidranger/cidranger.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md): the package's public entry points.
//
// Go stdlib's `net.IP` / `net.IPNet` are stood in for by
// `package:boilerplate/net/golang.dart`'s `Ip` / `IpNet` (see
// transpiled_go_cidranger.dart's header for why).

/// Thrown on an invalid network (CIDR block) input. Equivalent to
/// go-cidranger's `ErrInvalidNetworkInput`.
class InvalidNetworkInputException implements Exception {
  /// Creates the exception.
  const InvalidNetworkInputException();
  @override
  String toString() => 'Invalid network input';
}

/// Thrown on an invalid IP address input. Equivalent to go-cidranger's
/// `ErrInvalidNetworkNumberInput`.
class InvalidNetworkNumberInputException implements Exception {
  /// Creates the exception.
  const InvalidNetworkNumberInputException();
  @override
  String toString() => 'Invalid network number input';
}

/// The `0.0.0.0/0` IPv4 CIDR that contains every IPv4 network. Equivalent
/// to go-cidranger's `AllIPv4`.
final IpNet allIpv4 = IpNet.tryParseCidr('0.0.0.0/0')!;

/// The `::/0` IPv6 CIDR that contains every IPv6 network. Equivalent to
/// go-cidranger's `AllIPv6`.
final IpNet allIpv6 = IpNet.tryParseCidr('0::0/0')!;

/// An entry insertable into a [Ranger]. Equivalent to go-cidranger's
/// `RangerEntry` interface.
abstract class RangerEntry {
  /// A basic entry that only stores [ipNet] itself. Equivalent to
  /// go-cidranger's `NewBasicRangerEntry`.
  factory RangerEntry.basic(IpNet ipNet) = _BasicRangerEntry;

  /// This entry's network.
  IpNet network();
}

class _BasicRangerEntry implements RangerEntry {
  const _BasicRangerEntry(this._ipNet);
  final IpNet _ipNet;

  @override
  IpNet network() => _ipNet;

  @override
  bool operator ==(Object other) =>
      other is _BasicRangerEntry && _ipNet == other._ipNet;
  @override
  int get hashCode => _ipNet.hashCode;
  @override
  String toString() => _ipNet.toString();
}

/// CIDR-block containment lookups. Equivalent to go-cidranger's `Ranger`
/// interface.
abstract class Ranger {
  /// A [Ranger] backed by a path-compressed trie, supporting both IPv4 and
  /// IPv6 (dispatched to a per-version subtree). Equivalent to
  /// go-cidranger's `NewPCTrieRanger`.
  factory Ranger.pcTrie() = _VersionedRanger.pcTrie;

  /// Inserts [entry] into the ranger.
  void insert(RangerEntry entry);

  /// Removes the entry for [network], returning it, or `null` if it
  /// wasn't present.
  RangerEntry? remove(IpNet network);

  /// Whether [ip] is contained in any of the inserted networks.
  bool contains(Ip ip);

  /// The entries whose networks contain [ip], in ascending prefix order.
  List<RangerEntry> containingNetworks(Ip ip);

  /// The entries whose networks are completely subsumed by [network].
  List<RangerEntry> coveredNetworks(IpNet network);

  /// The number of networks in this ranger.
  int get length;
}
