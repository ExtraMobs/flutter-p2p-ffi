// lib/src/transport/dns/system_resolver.dart
//
// A transpiled_multiaddr_dns BasicResolver backed by real DNS:
// `InternetAddress.lookup` (dart:io, uses the OS resolver -- already
// correct, no gap there) for A/AAAA, and UdpDnsClient (this package,
// since dart:io has no TXT API) for TXT. Feed this to a
// transpiled_multiaddr_dns `Resolver` to actually resolve `/dns4/`,
// `/dns6/`, `/dns/`, and `/dnsaddr/` multiaddr components against the
// real network.
import 'dart:io';

import 'package:transpiled_multiaddr_dns/transpiled_multiaddr_dns.dart'
    show BasicResolver;

import 'dns_message.dart';
import 'udp_dns_client.dart';

/// The concrete, network-backed [BasicResolver] for real DNS resolution.
class SystemResolver implements BasicResolver {
  /// Builds a resolver using [client] for TXT lookups (a fresh
  /// [UdpDnsClient] with its default public resolvers, unless overridden).
  SystemResolver({UdpDnsClient? client}) : _client = client ?? UdpDnsClient();

  final UdpDnsClient _client;

  @override
  Future<List<String>> lookupIpAddr(String name) async {
    final addrs = await InternetAddress.lookup(name);
    return [for (final a in addrs) a.address];
  }

  @override
  Future<List<String>> lookupTxt(String name) async {
    final records = await _client.lookup(name, DnsRecordType.txt);
    return [for (final r in records) r.data];
  }
}
