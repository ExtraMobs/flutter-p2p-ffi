// test/transport/dns/udp_dns_client_network_test.dart
//
// Behavioral tests for UdpDnsClient that need a real (if not necessarily
// reachable) network: resolver fallback on timeout, and NXDOMAIN handling.
// Tagged 'network' and skipped by default (see dart_test.yaml); run with
// `dart test --preset network`.
@Tags(['network'])
library;

import 'package:transpiled_ipfs/src/transport/dns/dns_message.dart';
import 'package:transpiled_ipfs/src/transport/dns/udp_dns_client.dart';
import 'package:test/test.dart';

void main() {
  group('UdpDnsClient', () {
    test('falls back to the next resolver when the first one times out', () async {
      // 192.0.2.1 is TEST-NET-1 (RFC 5737): reserved for documentation,
      // guaranteed never to answer -- a deterministic way to force the
      // first resolver to time out and exercise the fallback path.
      final client = UdpDnsClient(
        resolvers: const ['192.0.2.1', '1.1.1.1'],
        timeout: const Duration(seconds: 2),
        attemptsPerResolver: 1,
      );
      final records = await client.lookup('dns.google', DnsRecordType.a);
      expect(records, isNotEmpty);
      expect(records.every((r) => r.type == DnsRecordType.a), isTrue);
    });

    test('a nonexistent domain resolves to an empty list, not an error', () async {
      final client = UdpDnsClient();
      final records = await client.lookup(
        'this-domain-should-not-exist-12345.invalid',
        DnsRecordType.a,
      );
      expect(records, isEmpty);
    });

    test('TXT lookup matches the real bootstrap.libp2p.io records', () async {
      final client = UdpDnsClient();
      final records = await client.lookup('_dnsaddr.bootstrap.libp2p.io', DnsRecordType.txt);
      expect(records, isNotEmpty);
      for (final r in records) {
        expect(r.data, startsWith('dnsaddr=/dnsaddr/'));
      }
    });
  });
}
