// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:boilerplate/net/golang.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import '../../../core/host/host.dart';

/// dialPolicy implementation matching go-libp2p/p2p/host/autonat/dialpolicy.go.
class DialPolicy {
  DialPolicy({required this.host, this.allowSelfDials = false});

  final Host host;
  bool allowSelfDials;

  /// skipDial indicates that a multiaddress isn't worth attempted dialing.
  bool skipDial(Multiaddr addr) {
    // skip relay addresses
    if (addr.hasProtocol(Protocols.circuit)) {
      return true;
    }

    if (allowSelfDials) {
      return false;
    }

    // skip private network (unroutable) addresses
    if (!isPublicAddr(addr)) {
      return true;
    }
    final candidateIp = toIp(addr);
    if (candidateIp == null) {
      return true;
    }

    // Skip dialing addresses we believe are the local node's
    for (final localAddr in host.addrs) {
      final localIp = toIp(localAddr);
      if (localIp == null) continue;
      if (localIp.equal(candidateIp)) {
        return true;
      }
    }

    return false;
  }

  /// skipPeer indicates that the collection of multiaddresses representing a peer
  /// isn't worth attempted dialing. If one of the addresses matches an address
  /// we believe is ours, we exclude the peer, even if there are other valid
  /// public addresses in the list.
  bool skipPeer(List<Multiaddr> addrs) {
    final localAddrs = host.addrs;
    final localHosts = <Ip>[];
    for (final lAddr in localAddrs) {
      if (!lAddr.hasProtocol(Protocols.circuit) && isPublicAddr(lAddr)) {
        final lIp = toIp(lAddr);
        if (lIp != null) {
          localHosts.add(lIp);
        }
      }
    }

    // If a public IP of the peer is one of ours: skip the peer.
    var goodPublic = false;
    for (final addr in addrs) {
      if (!addr.hasProtocol(Protocols.circuit) && isPublicAddr(addr)) {
        final aIp = toIp(addr);
        if (aIp == null) continue;

        for (final lIp in localHosts) {
          if (lIp.equal(aIp)) {
            return true;
          }
        }
        goodPublic = true;
      }
    }

    if (allowSelfDials) {
      return false;
    }

    return !goodPublic;
  }
}
