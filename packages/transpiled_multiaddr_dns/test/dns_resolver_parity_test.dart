// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/dns_resolver_parity_test.dart
//
// Parity tests for the Resolver orchestration ported from
// go-multiaddr-dns's resolve_test.go
// (go-ipfs-reference/go-multiaddr-dns/resolve_test.go), using MockResolver
// exactly as that file does -- no real network or platform I/O involved.
import 'package:transpiled_multiaddr_dns/transpiled_multiaddr_dns.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:test/test.dart';

const ip4a = '192.0.2.1';
const ip4b = '192.0.2.2';
const ip6a = '2001:db8::a3';
const ip6b = '2001:db8::a4';

Multiaddr ma(String s) => Multiaddr.parse(s);

final ip4ma = ma('/ip4/$ip4a');
final ip4mb = ma('/ip4/$ip4b');
final ip6ma = ma('/ip6/$ip6a');
final ip6mb = ma('/ip6/$ip6b');

final txtmc = ip4ma.encapsulate(ma('/tcp/123/http'));
final txtmd = ip4ma.encapsulate(ma('/tcp/123'));
final txtme = ip4ma.encapsulate(ma('/tcp/789/http'));

final txta = 'dnsaddr=${ip4ma.toAddrString()}';
final txtb = 'dnsaddr=${ip6ma.toAddrString()}';
final txtc = 'dnsaddr=${txtmc.toAddrString()}';
final txtd = 'dnsaddr=${txtmd.toAddrString()}';
final txte = 'dnsaddr=${txtme.toAddrString()}';

Resolver makeResolver() {
  final mock = MockResolver(
    ip: {
      'example.com': [ip4a, ip4b, ip6a, ip6b],
    },
    txt: {
      '_dnsaddr.example.com': [txta, txtb],
      '_dnsaddr.matching.com': [txtc, txtd, txte, 'not a dnsaddr', 'dnsaddr=/foobar'],
    },
  );
  return Resolver(defaultResolver: mock);
}

/// Repeatedly resolves every DNS component in [input], mirroring
/// resolve_test.go's own `resolveAllDNS` test helper.
Future<List<Multiaddr>> resolveAllDns(Resolver resolver, Multiaddr input) async {
  if (!dnsMatches(input)) return [input];
  var toResolve = [input];
  final out = <Multiaddr>[];
  while (toResolve.isNotEmpty) {
    final next = <Multiaddr>[];
    for (final a in toResolve) {
      for (final addr in await resolver.resolve(a)) {
        if (dnsMatches(addr)) {
          next.add(addr);
        } else {
          out.add(addr);
        }
      }
    }
    toResolve = next;
  }
  return out;
}

void main() {
  group('dnsMatches', () {
    test('matches dns-bearing multiaddrs', () {
      expect(dnsMatches(ma('/tcp/1234/dns6/example.com')), isTrue);
      expect(dnsMatches(ma('/dns/example.com')), isTrue);
      expect(dnsMatches(ma('/dns4/example.com')), isTrue);
      expect(dnsMatches(ma('/dns6/example.com')), isTrue);
      expect(dnsMatches(ma('/dnsaddr/example.com')), isTrue);
      expect(dnsMatches(ip4ma), isFalse);
    });
  });

  group('Resolver.resolve -- simple IP resolution', () {
    test('dns4 keeps only v4 addresses', () async {
      final addrs = await makeResolver().resolve(ma('/dns4/example.com'));
      expect(addrs, equals([ip4ma, ip4mb]));
    });

    test('dns6 keeps only v6 addresses', () async {
      final addrs = await makeResolver().resolve(ma('/dns6/example.com'));
      expect(addrs, equals([ip6ma, ip6mb]));
    });

    test('dns keeps every address', () async {
      final addrs = await makeResolver().resolve(ma('/dns/example.com'));
      expect(addrs, equals([ip4ma, ip4mb, ip6ma, ip6mb]));
    });
  });

  test('resolve() only resolves the first DNS component', () async {
    final addrs = await makeResolver().resolve(
      ma('/dns4/example.com/quic/dns6/example.com'),
    );
    expect(addrs, equals([
      ip4ma.encapsulate(ma('/quic/dns6/example.com')),
      ip4mb.encapsulate(ma('/quic/dns6/example.com')),
    ]));
  });

  test('resolving repeatedly walks every DNS component (middle)', () async {
    final resolver = makeResolver();
    final addrs = await resolveAllDns(
      resolver,
      ma('/dns4/example.com/quic/dns6/example.com'),
    );
    final expected = <Multiaddr>[];
    for (final x in [ip4ma, ip4mb]) {
      for (final y in [ip6ma, ip6mb]) {
        expected.add(x.encapsulate(ma('/quic')).encapsulate(y));
      }
    }
    expect(addrs, equals(expected));
  });

  test('resolving repeatedly walks every DNS component (sandwiched)', () async {
    final resolver = makeResolver();
    final addrs = await resolveAllDns(
      resolver,
      ma('/quic/dns4/example.com/dns6/example.com/http'),
    );
    final expected = <Multiaddr>[];
    for (final x in [ip4ma, ip4mb]) {
      for (final y in [ip6ma, ip6mb]) {
        expected.add(ma('/quic').encapsulate(x).encapsulate(y).encapsulate(ma('/http')));
      }
    }
    expect(addrs, equals(expected));
  });

  test('dnsaddr resolves TXT records', () async {
    final addrs = await makeResolver().resolve(ma('/dnsaddr/example.com'));
    expect(addrs, equals([ip4ma, ip6ma]));
  });

  test('a non-DNS multiaddr resolves to itself', () async {
    final addrs = await makeResolver().resolve(ip4ma);
    expect(addrs, equals([ip4ma]));
  });

  test('a suffix with no matching dnsaddr record yields no results', () async {
    final addrs = await makeResolver().resolve(
      ma('/dnsaddr/example.com/quic/quic/quic/quic'),
    );
    expect(addrs, isEmpty);
  });

  test('a domain with no records yields no results', () async {
    final addrs = await makeResolver().resolve(ma('/dnsaddr/none.com'));
    expect(addrs, isEmpty);
  });

  test('resolving null yields no results', () async {
    expect(await makeResolver().resolve(null), isEmpty);
  });

  group('dnsaddr suffix matching', () {
    test('matches the tcp/123/http suffix specifically', () async {
      final addrs = await makeResolver().resolve(
        ma('/dnsaddr/matching.com/tcp/123/http'),
      );
      expect(addrs, equals([txtmc]));
    });

    test('matches the tcp/123 suffix specifically', () async {
      final addrs = await makeResolver().resolve(
        ma('/dnsaddr/matching.com/tcp/123'),
      );
      expect(addrs, equals([txtmd]));
    });
  });

  test('resolving a huge record set is capped at 100 addresses', () async {
    final ips = [for (var i = 0; i < 255; i++) '1.2.3.$i'];
    final resolver = Resolver(
      defaultResolver: MockResolver(ip: {'example.com': ips}, txt: const {}),
    );
    final addrs = await resolver.resolve(ma('/dns4/example.com'));
    expect(addrs, hasLength(100));
  });

  group('custom per-domain resolvers', () {
    test('match left-to-right, most specific wins', () async {
      final def = MockResolver(ip: {'example.com': ['1.2.3.4']});
      final custom1 = MockResolver(
        ip: {
          'custom.test': ['2.3.4.5'],
          'another.custom.test': ['3.4.5.6'],
          'more.custom.test': ['6.8.9.10'],
        },
      );
      final custom2 = MockResolver(
        ip: {
          'more.custom.test': ['4.5.6.8'],
          'some.more.custom.test': ['5.6.8.9'],
        },
      );

      final resolver = Resolver(defaultResolver: def);
      resolver.withDomainResolver('custom.test', custom1);
      resolver.withDomainResolver('more.custom.test', custom2);

      expect(await resolver.lookupIpAddr('example.com'), equals(['1.2.3.4']));
      expect(await resolver.lookupIpAddr('custom.test'), equals(['2.3.4.5']));
      expect(
        await resolver.lookupIpAddr('another.custom.test'),
        equals(['3.4.5.6']),
      );
      // more.custom.test has its own resolver (custom2), overriding
      // custom1's entry for the same name.
      expect(
        await resolver.lookupIpAddr('more.custom.test'),
        equals(['4.5.6.8']),
      );
      expect(
        await resolver.lookupIpAddr('some.more.custom.test'),
        equals(['5.6.8.9']),
      );
    });
  });

  group('isFqdn / fqdn', () {
    final fqdnCases = <(String input, bool expected)>[
      ('', false),
      ('.', true),
      ('example.com', false),
      ('example.com.', true),
      ('example\\.com.', true),
      ('example.com\\.', false),
      ('example.com\\\\.', true),
      ('example.com\\\\\\.', false),
    ];
    for (final (input, expected) in fqdnCases) {
      test('isFqdn(${input.isEmpty ? "(empty)" : input}) == $expected', () {
        expect(isFqdn(input), equals(expected));
      });
    }

    final fqdnFormCases = <(String input, String expected)>[
      ('', '.'),
      ('.', '.'),
      ('example.com', 'example.com.'),
      ('example.com.', 'example.com.'),
      ('example.com\\.', 'example.com\\..'),
      ('example.com\\\\.', 'example.com\\\\.'),
    ];
    for (final (input, expected) in fqdnFormCases) {
      test('fqdn(${input.isEmpty ? "(empty)" : input}) == $expected', () {
        expect(fqdn(input), equals(expected));
      });
    }
  });
}
