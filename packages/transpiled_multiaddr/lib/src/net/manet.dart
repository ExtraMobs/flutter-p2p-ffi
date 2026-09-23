// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:boilerplate/net/golang.dart';
import '../multiaddr.dart';
import '../protocol.dart';

/// IP4Loopback is the ip4 loopback multiaddr (/ip4/127.0.0.1).
final Multiaddr ip4Loopback = Multiaddr.parse('/ip4/127.0.0.1');

/// IP6Loopback is the ip6 loopback multiaddr (/ip6/::1).
final Multiaddr ip6Loopback = Multiaddr.parse('/ip6/::1');

/// IP4MappedIP6Loopback is the IPv4 Mapped IPv6 loopback address (/ip6/::ffff:127.0.0.1).
final Multiaddr ip4MappedIp6Loopback = Multiaddr.parse('/ip6/::ffff:127.0.0.1');

/// IP4Unspecified is the unspecified IPv4 multiaddr (/ip4/0.0.0.0).
final Multiaddr ip4Unspecified = Multiaddr.parse('/ip4/0.0.0.0');

/// IP6Unspecified is the unspecified IPv6 multiaddr (/ip6/::).
final Multiaddr ip6Unspecified = Multiaddr.parse('/ip6/::');

/// Well-known private IPv4 CIDR blocks (RFC 1918, RFC 6598, RFC 3927, RFC 1122).
final List<IpNet> private4 = _parseCidrs([
  '127.0.0.0/8',
  '10.0.0.0/8',
  '100.64.0.0/10',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '169.254.0.0/16',
]);

/// Well-known private IPv6 CIDR blocks (RFC 4193, RFC 4291).
final List<IpNet> private6 = _parseCidrs(['::1/128', 'fc00::/7', 'fe80::/10']);

/// Well-known unroutable IPv4 CIDR blocks (RFC 5735, RFC 5737, etc.).
final List<IpNet> unroutable4 = _parseCidrs([
  '0.0.0.0/8',
  '192.0.0.0/26',
  '192.0.2.0/24',
  '192.88.99.0/24',
  '198.18.0.0/15',
  '198.51.100.0/24',
  '203.0.113.0/24',
  '224.0.0.0/4',
  '240.0.0.0/4',
  '255.255.255.255/32',
]);

/// Well-known unroutable IPv6 CIDR blocks.
final List<IpNet> unroutable6 = _parseCidrs(['ff00::/8', '2001:db8::/32']);

final List<IpNet> _globalUnicast6 = _parseCidrs(['2000::/3']);

final List<IpNet> _nat64 = _parseCidrs(['64:ff9b:1::/48', '64:ff9b::/96']);

const _unResolvableDomains = ['.in-addr.arpa', '.ip6.arpa', '.invalid'];

const _privateUseDomains = ['.home.arpa', '.local', '.test'];

const _localHostDomain = '.localhost';

List<IpNet> _parseCidrs(List<String> cidrs) {
  final nets = <IpNet>[];
  for (final c in cidrs) {
    final parsed = IpNet.tryParseCidr(c);
    if (parsed != null) {
      nets.add(parsed);
    }
  }
  return nets;
}

bool _inAddrRange(Ip ip, List<IpNet> ipnets) {
  for (final net in ipnets) {
    if (net.contains(ip)) return true;
  }
  return false;
}

bool _isSubdomain(String child, String parent) {
  return child.endsWith(parent) || child == parent.substring(1);
}

/// Converts a Multiaddr to an Ip address from its first ip4 or ip6 component.
Ip? toIp(Multiaddr addr) {
  for (final c in addr.components) {
    if (c.protocol.code == Protocols.ip6zone) continue;
    if (c.protocol.code == Protocols.ip4 || c.protocol.code == Protocols.ip6) {
      return Ip.tryParse(c.value);
    }
  }
  return null;
}

/// Converts an Ip address to a Multiaddr.
Multiaddr fromIp(Ip ip) {
  final v4 = ip.to4();
  if (v4 != null) {
    return Multiaddr.parse('/ip4/${v4.toString()}');
  }
  return Multiaddr.parse('/ip6/${ip.toString()}');
}

/// Returns whether a Multiaddr starts with "Thin Waist" Protocols (/{ip4, ip6}[/{tcp, udp, ip4, ip6}]).
bool isThinWaist(Multiaddr m) {
  final protos = m.protocols;
  if (protos.isEmpty) return false;
  final first = protos[0];
  if (first.code != Protocols.ip4 && first.code != Protocols.ip6) {
    return false;
  }
  if (protos.length == 1) return true;
  final second = protos[1];
  return second.code == Protocols.tcp ||
      second.code == Protocols.udp ||
      second.code == Protocols.ip4 ||
      second.code == Protocols.ip6;
}

/// Returns whether a Multiaddr starts with a loopback IP address (127.0.0.0/8, ::1).
bool isIpLoopback(Multiaddr m) {
  final ip = toIp(m);
  if (ip == null || ip.isNil) return false;
  final v4 = ip.to4();
  if (v4 != null) {
    return v4.asBytes()[0] == 127;
  }
  final b = ip.asBytes();
  if (b.length == 16) {
    var isLoopback = true;
    for (var i = 0; i < 15; i++) {
      if (b[i] != 0) {
        isLoopback = false;
        break;
      }
    }
    if (isLoopback && b[15] == 1) return true;
  }
  return false;
}

/// Returns whether a Multiaddr starts with an IPv6 link-local address (fe80::/10).
bool isIp6LinkLocal(Multiaddr m) {
  final ip = toIp(m);
  if (ip == null || ip.isNil) return false;
  if (ip.to4() != null) return false;
  final b = ip.asBytes();
  return b.length == 16 && b[0] == 0xfe && (b[1] & 0xc0) == 0x80;
}

/// Returns whether a Multiaddr starts with an unspecified IP address (0.0.0.0 or ::).
bool isIpUnspecified(Multiaddr m) {
  final ip = toIp(m);
  if (ip == null || ip.isNil) return false;
  final v4 = ip.to4();
  if (v4 != null) {
    return v4.asBytes().every((byte) => byte == 0);
  }
  return ip.asBytes().every((byte) => byte == 0);
}

/// Returns true if the IP part of the multiaddr is a publicly routable address.
/// Faithfully matches manet.IsPublicAddr from github.com/multiformats/go-multiaddr/net.
bool isPublicAddr(Multiaddr a) {
  if (a.hasProtocol(Protocols.circuit)) return false;

  var isPublic = false;
  for (final c in a.components) {
    final code = c.protocol.code;
    if (code == Protocols.ip6zone) {
      return true;
    } else if (code == Protocols.ip4) {
      final ip = Ip.tryParse(c.value);
      if (ip == null || ip.isNil) return false;
      isPublic = !_inAddrRange(ip, private4) && !_inAddrRange(ip, unroutable4);
      return isPublic;
    } else if (code == Protocols.ip6) {
      final ip = Ip.tryParse(c.value);
      if (ip == null || ip.isNil) return false;
      final isPublicUnicast =
          _inAddrRange(ip, _globalUnicast6) && !_inAddrRange(ip, unroutable6);
      if (isPublicUnicast) {
        return true;
      }
      isPublic = _inAddrRange(ip, _nat64);
      return isPublic;
    } else if (code == Protocols.dns ||
        code == Protocols.dns4 ||
        code == Protocols.dns6 ||
        code == Protocols.dnsaddr) {
      final dnsAddr = c.value;
      if (_isSubdomain(dnsAddr, _localHostDomain)) {
        return false;
      }
      for (final ud in _unResolvableDomains) {
        if (_isSubdomain(dnsAddr, ud)) {
          return false;
        }
      }
      for (final pd in _privateUseDomains) {
        if (_isSubdomain(dnsAddr, pd)) {
          return false;
        }
      }
      return true;
    }
  }
  return isPublic;
}

/// Returns true if the IP part of the multiaddr is in a private network.
/// Faithfully matches manet.IsPrivateAddr from github.com/multiformats/go-multiaddr/net.
bool isPrivateAddr(Multiaddr a) {
  for (final c in a.components) {
    final code = c.protocol.code;
    if (code == Protocols.ip6zone) {
      return true;
    } else if (code == Protocols.ip4) {
      final ip = Ip.tryParse(c.value);
      if (ip == null || ip.isNil) return false;
      return _inAddrRange(ip, private4);
    } else if (code == Protocols.ip6) {
      final ip = Ip.tryParse(c.value);
      if (ip == null || ip.isNil) return false;
      return _inAddrRange(ip, private6);
    } else if (code == Protocols.dns ||
        code == Protocols.dns4 ||
        code == Protocols.dns6 ||
        code == Protocols.dnsaddr) {
      final dnsAddr = c.value;
      if (_isSubdomain(dnsAddr, _localHostDomain)) {
        return true;
      }
    }
  }
  return false;
}
