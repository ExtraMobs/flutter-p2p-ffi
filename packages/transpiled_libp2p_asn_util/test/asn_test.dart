// Parity port of github.com/libp2p/go-libp2p-asn-util/asn_test.go
// (revision fixed in doc/transpilation/UPSTREAM_LOCK.md), plus known
// lookups cross-checked by running the cloned Go module directly (see
// PROGRESS.md notes for this port).
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_libp2p_asn_util/transpiled_libp2p_asn_util.dart';

void main() {
  group('asnForIpv6', () {
    // Cross-checked against `go run` over the cloned v0.4.1 module.
    const knownLookups = {
      '2001:4860:4860::8888': 15169, // Google
      '2606:4700:4700::1111': 13335, // Cloudflare
      '2400:cb00:2049:1::a29f:1804': 13335, // Cloudflare
      '2a03:2880:f003:c07:face:b00c::2': 32934, // Facebook/Meta
      '2001:db8::1': 0, // documentation range, no ASN
    };

    knownLookups.forEach((ip, expectedAsn) {
      test('$ip -> $expectedAsn', () {
        expect(asnForIpv6(Ip.tryParse(ip)!), expectedAsn);
      });
    });

    test('unknown network returns 0', () {
      expect(asnForIpv6(Ip.tryParse('::1')!), 0);
    });

    test('an IPv4 address is looked up via its v4-mapped form', () {
      // No real route ever matches ::ffff:a.b.c.d, but the call must not
      // throw and must return 0, matching Go's net.IP.To16() widening.
      expect(asnForIpv6(Ip.tryParse('8.8.8.8')!), 0);
    });

    test('a malformed ip (neither 4 nor 16 bytes) returns 0, not a throw', () {
      // Go: `ip.To16()` is nil, and `AsnForIPv6` returns the zero ASN
      // with no error -- unreachable through dart:io's InternetAddress
      // (always 4 or 16 bytes), reachable through Ip.
      expect(asnForIpv6(Ip.fromBytes([1, 2, 3, 4, 5])), 0);
    });
  });

  group('asnForIpv6Network', () {
    test('looking up the raw 64-bit network prefix matches asnForIpv6', () {
      // 2001:4860:4860::8888's first 64 bits, as a big-endian hex string.
      final network = Golang.Uint64.fromBigInt(
        BigInt.parse('2001486048600000', radix: 16),
      );
      expect(asnForIpv6Network(network), 15169);
    });

    test('returns 0 for a network with no mapping', () {
      final network = Golang.Uint64.fromBigInt(
        BigInt.parse('20010db800000000', radix: 16),
      );
      expect(asnForIpv6Network(network), 0);
    });
  });

  group('BackwardCompat / store (deprecated backward-compat)', () {
    test('asnForIpv6() returns the decimal ASN as a string', () {
      // ignore: deprecated_member_use_from_same_package
      expect(store.asnForIpv6(Ip.tryParse('2001:4860:4860::8888')!), '15169');
    });

    test('asnForIpv6() returns empty string when unknown', () {
      // ignore: deprecated_member_use_from_same_package
      expect(store.asnForIpv6(Ip.tryParse('2001:db8::1')!), '');
    });

    test('asnForIpv6() throws for a malformed ip', () {
      // Go: `ip.To16()` is nil, and `backwardCompat.AsnForIPv6` returns
      // `("", errors.New("ONLY IPv6 addresses supported"))` -- ported as
      // a thrown exception per this project's ban on Go-style error
      // tuples in public APIs. The exception type itself is
      // Dart-private (matching Go's own unexported `*errorString`), so
      // this asserts on the observable message, same as a Go caller
      // would only ever see `err.Error()`.
      // ignore: deprecated_member_use_from_same_package
      expect(
        () => store.asnForIpv6(Ip.fromBytes([1, 2, 3, 4, 5])),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            'ONLY IPv6 addresses supported',
          ),
        ),
      );
    });

    test('init() is a documented no-op', () {
      // ignore: deprecated_member_use_from_same_package
      expect(() => store.init(), returnsNormally);
    });
  });
}
