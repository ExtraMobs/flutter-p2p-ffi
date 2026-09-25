// Port of github.com/libp2p/go-cidranger/brute.go's `bruteRanger` (revision
// fixed in doc/transpilation/UPSTREAM_LOCK.md).
//
// Go's `bruteRanger` and its constructor `newBruteRanger` are both
// unexported, used only by go-cidranger's own same-package test suite as
// the ground-truth linear-scan comparator for the path-compressed trie.
// This port's parity tests reuse that exact technique, but Dart has no
// same-package-only visibility to grant a test file instead of the public
// API surface. Per AGENTS.md's "Nível de visibilidade" Cenário D, the
// next-lower-compatible visibility for a Go-unexported symbol this port
// still needs to reach is: a public name declared under `lib/src/`,
// deliberately **not** `part`-ed into or exported from
// `transpiled_go_cidranger.dart` -- visible only via a direct
// `package:transpiled_go_cidranger/src/brute_ranger.dart` import, as this
// package's own tests do, never through the public barrel.
//
// A standalone library (rather than a `part of` file) is required to make
// that omission possible at all: a `part` file shares its enclosing
// library wholesale and can't be selectively left out of it.
library;

import 'package:boilerplate/net/golang.dart';

import '../transpiled_go_cidranger.dart';

/// A brute-force implementation of [Ranger]. Insertion and removal are
/// O(1) (backed by `Map<String, RangerEntry>`), but containment tests are
/// always O(n), with no guaranteed traversal order. Correctness is easy to
/// reason about, which is why go-cidranger's own test suite uses it as the
/// ground-truth comparator for the path-compressed trie -- and why this
/// port's tests do the same (see this file's header for why the class is
/// public here despite Go's `bruteRanger` being unexported).
///
/// Equivalent to go-cidranger's private `bruteRanger`; this constructor is
/// equivalent to its private `newBruteRanger`.
class BruteRanger implements Ranger {
  /// Creates an empty [BruteRanger].
  BruteRanger();

  final Map<String, RangerEntry> _ipV4Entries = {};
  final Map<String, RangerEntry> _ipV6Entries = {};

  @override
  void insert(RangerEntry entry) {
    final network = entry.network();
    final key = network.toString();
    // Faithful to upstream: the "already inserted" check always looks at
    // the IPv4 map regardless of the entry's own version. Harmless in
    // practice (an IPv4 and an IPv6 CIDR string never collide), but kept
    // exactly as go-cidranger wrote it rather than "fixed" underneath it.
    if (!_ipV4Entries.containsKey(key)) {
      _entriesFor(network.ip)[key] = entry;
    }
  }

  @override
  RangerEntry? remove(IpNet network) {
    final entries = _entriesFor(network.ip);
    final key = network.toString();
    final found = entries[key];
    if (found != null) entries.remove(key);
    return found;
  }

  @override
  bool contains(Ip ip) {
    final entries = _entriesFor(ip);
    for (final entry in entries.values) {
      // Go: `network.Contains(ip)` on the entry's `net.IPNet` -- the
      // stdlib method, which `IpNet.contains` reproduces exactly (as
      // opposed to the internal `rnet.Network.Contains` trie.dart uses).
      if (entry.network().contains(ip)) return true;
    }
    return false;
  }

  @override
  List<RangerEntry> containingNetworks(Ip ip) {
    final entries = _entriesFor(ip);
    final results = <RangerEntry>[];
    for (final entry in entries.values) {
      if (entry.network().contains(ip)) results.add(entry);
    }
    return results;
  }

  @override
  List<RangerEntry> coveredNetworks(IpNet network) {
    final entries = _entriesFor(network.ip);
    final testNetwork = Network.fromIpNetwork(network);
    final results = <RangerEntry>[];
    for (final entry in entries.values) {
      final entryNetwork = Network.fromIpNetwork(entry.network());
      if (testNetwork.covers(entryNetwork)) results.add(entry);
    }
    return results;
  }

  @override
  int get length => _ipV4Entries.length + _ipV6Entries.length;

  /// Equivalent to go-cidranger's private `bruteRanger.getEntriesByVersion`.
  Map<String, RangerEntry> _entriesFor(Ip ip) {
    if (ip.to4() != null) return _ipV4Entries;
    if (ip.to16() != null) return _ipV6Entries;
    throw const InvalidNetworkInputException();
  }
}
