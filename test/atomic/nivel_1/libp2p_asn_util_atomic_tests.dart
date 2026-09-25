// Testes atômicos 1 para 1 para o módulo transpiled_libp2p_asn_util
// (porte de github.com/libp2p/go-libp2p-asn-util, revisão fixada em
// doc/transpilation/UPSTREAM_LOCK.md).
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_libp2p_asn_util/src/asn_store.dart';
import 'package:transpiled_libp2p_asn_util/transpiled_libp2p_asn_util.dart';

void main() {
  group('asnForIpv6() [Atomic Audit]', () {
    test('asnForIpv6() -- known IPv6 address resolves to its real ASN', () {
      expect(asnForIpv6(Ip.tryParse('2001:4860:4860::8888')!), 15169);
    });

    test('asnForIpv6() -- unmapped network returns 0', () {
      expect(asnForIpv6(Ip.tryParse('2001:db8::1')!), 0);
    });

    test('asnForIpv6() -- an IPv4 address is widened, never throws', () {
      expect(() => asnForIpv6(Ip.tryParse('8.8.8.8')!), returnsNormally);
    });

    test(
      'asnForIpv6() -- a malformed ip (neither 4 nor 16 bytes) returns 0',
      () {
        expect(asnForIpv6(Ip.fromBytes([1, 2, 3, 4, 5])), 0);
      },
    );
  });

  group('asnForIpv6Network() [Atomic Audit]', () {
    test('asnForIpv6Network() -- binary search hits the exact range', () {
      final network = Golang.Uint64.fromBigInt(
        BigInt.parse('2001486048600000', radix: 16),
      );
      expect(asnForIpv6Network(network), 15169);
    });

    test('asnForIpv6Network() -- returns 0 below the lowest range', () {
      expect(asnForIpv6Network(Golang.Uint64(0)), 0);
    });
  });

  group('BackwardCompat / store [Atomic Audit]', () {
    test('asnForIpv6() -- decimal string for a known ASN', () {
      final addr = Ip.tryParse('2001:4860:4860::8888')!;
      // ignore: deprecated_member_use
      expect(store.asnForIpv6(addr), '15169');
    });

    test('asnForIpv6() -- empty string when unknown', () {
      // ignore: deprecated_member_use
      expect(store.asnForIpv6(Ip.tryParse('2001:db8::1')!), '');
    });

    test('asnForIpv6() -- throws for a malformed ip', () {
      // The thrown exception type is Dart-private (matching Go's own
      // unexported `*errorString` for this anonymous `errors.New(...)`),
      // so this asserts on the observable message instead of the type,
      // same as a Go caller only ever sees `err.Error()`.
      // ignore: deprecated_member_use
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

    test('init() -- documented no-op', () {
      // ignore: deprecated_member_use
      expect(() => store.init(), returnsNormally);
    });
  });
}
