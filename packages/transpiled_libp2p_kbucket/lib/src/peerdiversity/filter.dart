// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Port of go-libp2p-kbucket/peerdiversity/filter.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md), Go package `peerdiversity` --
// consumers in this repo import it with prefix `peerdiversity`, per
// AGENTS.md's Regra 25 (internal `package:.../src/...` imports follow the
// Go package, not the Dart one), e.g.:
//
//   import 'peerdiversity/filter.dart' as peerdiversity;
//
// This mirrors upstream's own module boundary: Go code that wants
// `peerdiversity.Filter` imports `go-libp2p-kbucket/peerdiversity`
// directly, separately from `go-libp2p-kbucket` itself, so this file is
// deliberately not re-exported from this package's main barrel either.
//
// `filter.go` calls `cidranger.Ranger` (this project's
// `packages/transpiled_go_cidranger`) and `asnutil.AsnForIPv6` (this
// project's `packages/transpiled_libp2p_asn_util`), both of which take
// Go stdlib's `net.IP`/`net.IPNet`, stood in for throughout this codebase
// by `package:boilerplate/net/golang.dart`'s `Ip`/`IpNet` (already used
// by `transpiled_multiaddr`'s `manet` port and by `transpiled_libp2p`'s
// `conngater.dart`) -- this file, `transpiled_go_cidranger` and
// `transpiled_libp2p_asn_util` all share that one representation, with no
// bridging needed at this seam.
import 'dart:developer' as dev;

import 'package:boilerplate/net/golang.dart';
import 'package:transpiled_go_cidranger/transpiled_go_cidranger.dart'
    as go_cidranger;
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_asn_util/transpiled_libp2p_asn_util.dart'
    as libp2p_asn_util;
import 'package:transpiled_multiaddr/net.dart' as multiaddr;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

const String _logName = 'diversityFilter';

/// A unique key representing ONE of the IP groups a peer belongs to. A
/// peer has one [PeerIpGroupKey] per address, so it can belong to
/// MULTIPLE groups if it has multiple addresses.
///
/// For now, given a peer address, the grouping mechanism is:
///  1. For IPv6 addresses, group by the ASN of the IP address.
///  2. For IPv4 addresses, all addresses that belong to the same legacy
///     (Class A) /8 allocation OR share the same /16 prefix are in the
///     same group.
///
/// Equivalent to go-libp2p-kbucket/peerdiversity's `PeerIPGroupKey` (a
/// bare `string` type upstream; ported as an `extension type` so it stays
/// a distinct type rather than a plain `String`, matching Go's own
/// `type PeerIPGroupKey string` -- a defined type, not an alias, so it
/// doesn't fall under this project's ban on typedef-style shims).
extension type const PeerIpGroupKey(String value) {}

/// Legacy IPv4 Class A networks.
/// See <https://en.wikipedia.org/wiki/List_of_assigned_/8_IPv4_address_blocks>.
const List<String> _legacyClassA = [
  '12.0.0.0/8',
  '17.0.0.0/8',
  '19.0.0.0/8',
  '38.0.0.0/8',
  '48.0.0.0/8',
  '56.0.0.0/8',
  '73.0.0.0/8',
  '53.0.0.0/8',
];

/// `net.CIDRMask(32, 128).String()` in Go: a 16-byte mask with its first
/// 32 bits set, printed as hex. This value never changes (both inputs are
/// literal constants), so it's inlined rather than recomputed on every
/// fallback lookup.
const String _unknownAsnMaskHex = 'ffffffff000000000000000000000000';

final go_cidranger.Ranger _legacyCidrs = _buildLegacyCidrs();

go_cidranger.Ranger _buildLegacyCidrs() {
  final ranger = go_cidranger.Ranger.pcTrie();
  for (final cidr in _legacyClassA) {
    ranger.insert(go_cidranger.RangerEntry.basic(IpNet.tryParseCidr(cidr)!));
  }
  return ranger;
}

PeerIpGroupKey _maskedV4GroupKey(Ip v4, int m0, int m1, int m2, int m3) {
  final b = v4.asBytes();
  final masked = Ip.fromBytes([b[0] & m0, b[1] & m1, b[2] & m2, b[3] & m3]);
  return PeerIpGroupKey(masked.toString());
}

/// The [PeerIpGroupKey] to which the given [ip] belongs. Equivalent to
/// go-libp2p-kbucket/peerdiversity's `IPGroupKey`.
PeerIpGroupKey ipGroupKey(Ip ip) {
  final v4 = ip.to4();
  if (v4 == null) {
    // IPv6 address -> group by ASN.
    final asn = libp2p_asn_util.asnForIpv6(ip);
    if (asn == 0) {
      dev.log('ASN not known: $ip', name: _logName);
      return const PeerIpGroupKey('unknown ASN: $_unknownAsnMaskHex');
    }
    return PeerIpGroupKey(asn.toString());
  }

  // If it belongs to a legacy Class A /8, return the /8 prefix as the key.
  if (_legacyCidrs.containingNetworks(v4).isNotEmpty) {
    return _maskedV4GroupKey(v4, 255, 0, 0, 0);
  }
  // Otherwise, the /16 prefix.
  return _maskedV4GroupKey(v4, 255, 255, 0, 0);
}

/// The grouping info for a peer. Equivalent to
/// go-libp2p-kbucket/peerdiversity's `PeerGroupInfo`.
class PeerGroupInfo {
  /// Creates the grouping info.
  const PeerGroupInfo({
    required this.id,
    required this.cpl,
    required this.ipGroupKey,
  });

  /// The peer's ID.
  final PeerId id;

  /// The peer's common-prefix-length with the local peer.
  final int cpl;

  /// The IP group this info instance represents (a peer has one per
  /// address).
  final PeerIpGroupKey ipGroupKey;

  @override
  bool operator ==(Object other) =>
      other is PeerGroupInfo &&
      id == other.id &&
      cpl == other.cpl &&
      ipGroupKey == other.ipGroupKey;
  @override
  int get hashCode => Object.hash(id, cpl, ipGroupKey);
}

/// The hooks a caller must implement to instantiate a [Filter]. Called by
/// the [Filter] to test/track admission and to resolve a peer's
/// addresses. Equivalent to go-libp2p-kbucket/peerdiversity's
/// `PeerIPGroupFilter` interface.
abstract class PeerIpGroupFilter {
  /// Tests if a peer with the given grouping info should be
  /// allowed/rejected. Called ONLY AFTER the peer has passed all of
  /// [Filter]'s internal checks. If the peer is whitelisted on the
  /// [Filter], it's allowed without calling this.
  bool allow(PeerGroupInfo group);

  /// Called when a peer with the given grouping info is added to the
  /// [Filter]'s state, after it has passed all internal checks and
  /// [allow] for all of its groups.
  void increment(PeerGroupInfo group);

  /// Called when a peer with the given grouping info is removed from the
  /// [Filter], because the caller no longer wants it (and the IP groups
  /// it belongs to) counted towards the filter state.
  void decrement(PeerGroupInfo group);

  /// The addresses of [id] that the [Filter] should use to determine the
  /// IP groups it belongs to.
  List<Multiaddr> peerAddresses(PeerId id);
}

/// The diversity stats for a Cpl. Equivalent to
/// go-libp2p-kbucket/peerdiversity's `CplDiversityStats`.
class CplDiversityStats {
  /// Creates the stats entry.
  const CplDiversityStats(this.cpl, this.peers);

  /// The common-prefix-length these stats are for.
  final int cpl;

  /// Every tracked peer at this Cpl, with the IP groups each belongs to.
  final Map<PeerId, List<PeerIpGroupKey>> peers;
}

/// A peer diversity filter that accepts or rejects peers based on the
/// whitelisting rules configured AND the diversity policies defined by
/// the [PeerIpGroupFilter] implementation passed to it.
///
/// Go guards all state with a `sync.Mutex`; this port drops that for the
/// same reason `table.dart` does -- Dart code sharing a single isolate
/// never runs two pieces of synchronous logic concurrently, and every
/// method here is synchronous end to end. Equivalent to
/// go-libp2p-kbucket/peerdiversity's `Filter`.
class Filter {
  /// Creates a [Filter]. Equivalent to go-libp2p-kbucket/peerdiversity's
  /// `NewFilter`, minus the `pgm == nil` error case: [pgm] is
  /// non-nullable here, so that case is a compile-time impossibility
  /// rather than a runtime check.
  Filter({
    required PeerIpGroupFilter pgm,
    required this.logKey,
    required this.cplFnc,
  }) : _pgm = pgm;

  final PeerIpGroupFilter _pgm;

  /// An identifier for the app/subsystem using this filter, echoed into
  /// log messages.
  final String logKey;

  /// Computes a peer's common-prefix-length against the local peer.
  final int Function(PeerId id) cplFnc;

  final Map<PeerId, List<PeerGroupInfo>> _peerGroups = {};
  final Set<PeerId> _wlPeers = {};
  final Map<int, Map<PeerId, List<PeerIpGroupKey>>> _cplPeerGroups = {};

  /// Removes [id] from the filter's state.
  void remove(PeerId id) {
    final cpl = cplFnc(id);

    for (final info in _peerGroups[id] ?? const <PeerGroupInfo>[]) {
      _pgm.decrement(info);
    }
    _peerGroups.remove(id);

    final atCpl = _cplPeerGroups[cpl];
    atCpl?.remove(id);
    if (atCpl != null && atCpl.isEmpty) _cplPeerGroups.remove(cpl);
  }

  /// Attempts to add [id] to the filter state. Returns `true` if
  /// successful, `false` otherwise.
  bool tryAdd(PeerId id) {
    if (_wlPeers.contains(id)) return true;

    final cpl = cplFnc(id);

    // Don't allow peers for which addresses can't be determined.
    final addrs = _pgm.peerAddresses(id);
    if (addrs.isEmpty) {
      dev.log(
        'no addresses found for peer',
        name: _logName,
        error: 'appKey=$logKey peer=$id',
      );
      return false;
    }

    final peerGroups = <PeerGroupInfo>[];
    for (final a in addrs) {
      final ip = multiaddr.toIp(a);
      if (ip == null) {
        dev.log(
          'failed to parse IP from multiaddr',
          name: _logName,
          error: 'appKey=$logKey multiaddr=$a',
        );
        return false;
      }

      // Reject the peer if a grouping can't be determined for one of its
      // addresses.
      final key = ipGroupKey(ip);
      if (key.value.isEmpty) {
        dev.log(
          'group key is empty',
          name: _logName,
          error: 'appKey=$logKey ip=$ip peer=$id',
        );
        return false;
      }
      final group = PeerGroupInfo(id: id, cpl: cpl, ipGroupKey: key);

      if (!_pgm.allow(group)) return false;

      peerGroups.add(group);
    }

    final atCpl = _cplPeerGroups.putIfAbsent(cpl, () => {});
    for (final g in peerGroups) {
      _pgm.increment(g);

      _peerGroups.putIfAbsent(id, () => []).add(g);
      atCpl.putIfAbsent(id, () => []).add(g.ipGroupKey);
    }

    return true;
  }

  /// Peers in [peers] will always be allowed.
  void whitelistPeers(List<PeerId> peers) {
    _wlPeers.addAll(peers);
  }

  /// The peer diversity stats for each Cpl, sorted by the Cpl.
  List<CplDiversityStats> getDiversityStats() {
    final cpls = _cplPeerGroups.keys.toList()..sort();
    return [
      for (final cpl in cpls)
        CplDiversityStats(cpl, Map.of(_cplPeerGroups[cpl]!)),
    ];
  }
}
