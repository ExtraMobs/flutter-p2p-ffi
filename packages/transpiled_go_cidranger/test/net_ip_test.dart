// Parity port of github.com/libp2p/go-cidranger/net/ip_test.go (revision
// fixed in doc/transpilation/UPSTREAM_LOCK.md).
import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_go_cidranger/transpiled_go_cidranger.dart';

void main() {
  group('NetworkNumber.fromIp', () {
    test('nil input returns null', () {
      expect(NetworkNumber.fromIp(null), isNull);
    });

    test('malformed input (neither 4 nor 16 bytes) returns null', () {
      // Go's "bad input" case: a malformed 5-byte net.IP. Unreachable
      // through dart:io's InternetAddress (always 4 or 16 bytes), but
      // reachable through Ip, which -- like net.IP -- accepts any length.
      expect(NetworkNumber.fromIp(Ip.fromBytes([1, 2, 3, 4, 5])), isNull);
    });

    test('IPv4', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('128.0.0.0')!)!;
      expect(nn.length, 1);
      expect(nn[0], 2147483648);
    });

    test('IPv6', () {
      final nn = NetworkNumber.fromIp(
        Ip.tryParse('2001:0db8::ff00:0042:8329')!,
      )!;
      expect(nn.length, 4);
      expect(nn[0], 536939960);
      expect(nn[1], 0);
      expect(nn[2], 65280);
      expect(nn[3], 4358953);
    });
  });

  group('NetworkNumber.toV4 / toV6', () {
    test('is IPv4', () {
      final nn = const NetworkNumber([1]);
      expect(nn.toV4(), nn);
      expect(nn.toV6(), isNull);
    });

    test('is IPv6', () {
      final nn = const NetworkNumber([1, 1, 1, 1]);
      expect(nn.toV4(), isNull);
      expect(nn.toV6(), nn);
    });

    test('is invalid (neither v4 nor v6 word count)', () {
      final nn = const NetworkNumber([1, 1]);
      expect(nn.toV4(), isNull);
      expect(nn.toV6(), isNull);
    });
  });

  group('NetworkNumber.bit', () {
    test('128.0.0.0 has bit 31 set, all else clear', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('128.0.0.0')!)!;
      for (var i = 0; i < 32; i++) {
        expect(nn.bit(i), i == 31 ? 1 : 0);
      }
    });

    test('1.1.1.1 has bits 0, 8, 16, 24 set', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('1.1.1.1')!)!;
      const ones = {0, 8, 16, 24};
      for (var i = 0; i < 32; i++) {
        expect(nn.bit(i), ones.contains(i) ? 1 : 0);
      }
    });

    test('8000:: has bit 127 set', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('8000::')!)!;
      for (var i = 0; i < 128; i++) {
        expect(nn.bit(i), i == 127 ? 1 : 0);
      }
    });

    test('throws InvalidBitPositionException out of bounds', () {
      final v4 = NetworkNumber.fromIp(Ip.tryParse('128.0.0.0')!)!;
      expect(v4.bit(0), 0);
      expect(v4.bit(31), 1);
      expect(() => v4.bit(32), throwsA(isA<InvalidBitPositionException>()));

      final v6 = NetworkNumber.fromIp(Ip.tryParse('8000::')!)!;
      expect(v6.bit(0), 0);
      expect(v6.bit(127), 1);
      expect(() => v6.bit(128), throwsA(isA<InvalidBitPositionException>()));
    });
  });

  group('NetworkNumber ==', () {
    test('IPv4 equals / does not equal', () {
      expect(
        const NetworkNumber([0xFFFFFFFF]) == const NetworkNumber([0xFFFFFFFF]),
        isTrue,
      );
      expect(
        const NetworkNumber([0xFFFFFFFF]) == const NetworkNumber([0xFFFFFFFE]),
        isFalse,
      );
    });

    test('IPv6 equals / does not equal', () {
      expect(
        const NetworkNumber([1, 1, 1, 1]) == const NetworkNumber([1, 1, 1, 1]),
        isTrue,
      );
      expect(
        const NetworkNumber([1, 1, 1, 1]) == const NetworkNumber([1, 1, 1, 2]),
        isFalse,
      );
    });

    test('version mismatch is not equal', () {
      expect(
        const NetworkNumber([1]) == const NetworkNumber([1, 2, 3, 4]),
        isFalse,
      );
    });
  });

  group('NetworkNumber.next / previous', () {
    const cases = [
      ('0.0.0.0', '0.0.0.1', 'IPv4 basic'),
      ('0.0.0.255', '0.0.1.0', 'IPv4 rollover'),
      ('0.255.255.255', '1.0.0.0', 'IPv4 consecutive rollover'),
      ('8000::0', '8000::1', 'IPv6 basic'),
      ('0::ffff', '0::1:0', 'IPv6 rollover'),
      (
        '0:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
        '1::',
        'IPv6 consecutive rollover',
      ),
    ];

    for (final (ip, next, name) in cases) {
      test('next() -- $name', () {
        final nn = NetworkNumber.fromIp(Ip.tryParse(ip)!)!;
        final expected = NetworkNumber.fromIp(Ip.tryParse(next)!)!;
        expect(nn.next(), expected);
      });

      test('previous() -- $name (reversed)', () {
        final nn = NetworkNumber.fromIp(Ip.tryParse(next)!)!;
        final expected = NetworkNumber.fromIp(Ip.tryParse(ip)!)!;
        expect(nn.previous(), expected);
      });
    }
  });

  group('NetworkNumber.leastCommonBitPosition', () {
    test('version mismatch throws', () {
      const n1 = NetworkNumber([2147483648]);
      const n2 = NetworkNumber([3221225472, 0, 0, 0]);
      expect(
        () => n1.leastCommonBitPosition(n2),
        throwsA(isA<VersionMismatchException>()),
      );
    });

    test('IPv4 31st position', () {
      const n1 = NetworkNumber([2147483648]);
      const n2 = NetworkNumber([3221225472]);
      expect(n1.leastCommonBitPosition(n2), 31);
    });

    test('IPv4 0th position', () {
      const n1 = NetworkNumber([2147483648]);
      expect(n1.leastCommonBitPosition(n1), 0);
    });

    test('IPv4 diverge at first bit throws', () {
      const n1 = NetworkNumber([2147483648]);
      const n2 = NetworkNumber([1]);
      expect(
        () => n1.leastCommonBitPosition(n2),
        throwsA(isA<NoGreatestCommonBitException>()),
      );
    });

    test('IPv6 127th position', () {
      const n1 = NetworkNumber([2147483648, 0, 0, 0]);
      const n2 = NetworkNumber([3221225472, 0, 0, 0]);
      expect(n1.leastCommonBitPosition(n2), 127);
    });
  });

  group('NetworkNumber.toIp', () {
    test('round-trips through fromIp', () {
      for (final s in ['192.128.0.0', '8000::ffff']) {
        final addr = Ip.tryParse(s)!;
        expect(NetworkNumber.fromIp(addr)!.toIp(), addr);
      }
    });
  });

  group('Network', () {
    test('fromIpNetwork', () {
      final ipNet = IpNet.tryParseCidr('192.128.0.0/24')!;
      final n = Network.fromIpNetwork(ipNet);
      expect(n.toIpNetwork(), ipNet);
      expect(n.number, const NetworkNumber([3229614080]));
      expect(n.mask, const NetworkNumberMask(24));
    });

    test('masked', () {
      const cases = [
        ('192.168.0.0/16', 16, '192.168.0.0/16'),
        ('192.168.0.0/16', 14, '192.168.0.0/14'),
        ('192.168.0.0/16', 18, '192.168.0.0/18'),
        ('192.168.0.0/16', 8, '192.0.0.0/8'),
        ('8000::/128', 96, '8000::/96'),
        ('8000::/128', 128, '8000::/128'),
        ('8000::/96', 112, '8000::/112'),
        ('8000:ffff::/96', 16, '8000::/16'),
      ];
      for (final (network, mask, maskedNetwork) in cases) {
        final n1 = Network.fromIpNetwork(IpNet.tryParseCidr(network)!);
        final expected = Network.fromIpNetwork(
          IpNet.tryParseCidr(maskedNetwork)!,
        );
        expect(n1.masked(mask).toString(), expected.toString());
      }
    });

    test('==', () {
      expect(
        Network.fromIpNetwork(IpNet.tryParseCidr('192.128.0.0/24')!) ==
            Network.fromIpNetwork(IpNet.tryParseCidr('192.128.0.0/24')!),
        isTrue,
      );
      expect(
        Network.fromIpNetwork(IpNet.tryParseCidr('192.128.0.0/24')!) ==
            Network.fromIpNetwork(IpNet.tryParseCidr('192.128.0.0/23')!),
        isFalse,
      );
    });

    test('contains', () {
      final network = Network.fromIpNetwork(
        IpNet.tryParseCidr('192.168.0.0/24')!,
      );
      var ip = NetworkNumber.fromIp(Ip.tryParse('192.168.0.0')!)!;
      final last = NetworkNumber.fromIp(Ip.tryParse('192.168.0.255')!)!;
      expect(network.contains(ip.previous()), isFalse);
      expect(network.contains(last.next()), isFalse);
      while (ip != last.next()) {
        expect(network.contains(ip), isTrue);
        ip = ip.next();
      }
    });

    test('version mismatch is not contained', () {
      final v4Net = Network.fromIpNetwork(
        IpNet.tryParseCidr('192.168.0.0/24')!,
      );
      expect(
        v4Net.contains(NetworkNumber.fromIp(Ip.tryParse('8000::0')!)!),
        isFalse,
      );
    });

    test('covers', () {
      const cases = [
        ('10.0.0.0/24', '10.0.0.1/25', true),
        ('10.0.0.0/24', '11.0.0.1/25', false),
        ('10.0.0.0/16', '10.0.0.0/15', false),
        ('10.0.0.0/15', '10.0.0.0/16', true),
        ('10.0.0.0/15', '10.0.0.0/15', true),
        ('10::0/15', '10::0/16', true),
      ];
      for (final (network, covers, result) in cases) {
        final n = Network.fromIpNetwork(IpNet.tryParseCidr(network)!);
        final c = Network.fromIpNetwork(IpNet.tryParseCidr(covers)!);
        expect(n.covers(c), result, reason: '$network covers $covers');
      }
    });

    test('leastCommonBitPosition', () {
      const cases = [
        ('0.0.1.0/24', '0.0.0.0/24', 9),
        ('0.0.0.0/24', '0.0.0.0/24', 8),
        ('0.0.0.128/24', '0.0.0.0/16', 16),
        ('8000::/96', '8000::1:0:0/96', 33),
        ('8000::/96', '8000::8:0/96', 32),
        ('8000::/96', '8000::/95', 33),
      ];
      for (final (cidr1, cidr2, expectedPos) in cases) {
        final n1 = Network.fromIpNetwork(IpNet.tryParseCidr(cidr1)!);
        final n2 = Network.fromIpNetwork(IpNet.tryParseCidr(cidr2)!);
        expect(n1.leastCommonBitPosition(n2), expectedPos);
      }
    });

    test('leastCommonBitPosition throws when diverging at 1st position', () {
      final n1 = Network.fromIpNetwork(IpNet.tryParseCidr('128.0.0.0/24')!);
      final n2 = Network.fromIpNetwork(IpNet.tryParseCidr('0.0.0.0/24')!);
      expect(
        () => n1.leastCommonBitPosition(n2),
        throwsA(isA<NoGreatestCommonBitException>()),
      );
    });
  });

  group('NetworkNumberMask.mask', () {
    test('IPv4 and IPv6 masking', () {
      expect(
        const NetworkNumberMask(32).mask(const NetworkNumber([0xFFFFFFFF])),
        const NetworkNumber([0xFFFFFFFF]),
      );
      expect(
        const NetworkNumberMask(16).mask(const NetworkNumber([0xFFFFFFFF])),
        const NetworkNumber([0xFFFF0000]),
      );
      expect(
        const NetworkNumberMask(
          16,
        ).mask(const NetworkNumber([0xFFFFFFFF, 0, 0, 0])),
        const NetworkNumber([0xFFFF0000, 0, 0, 0]),
      );
    });
  });

  group('nextIp / previousIp', () {
    const cases = [
      ('0.0.0.0', '0.0.0.1'),
      ('0.0.0.255', '0.0.1.0'),
      ('8000::0', '8000::1'),
    ];
    for (final (ip, next) in cases) {
      test('nextIp($ip) == $next', () {
        expect(nextIp(Ip.tryParse(ip)!), Ip.tryParse(next)!);
      });
      test('previousIp($next) == $ip', () {
        expect(previousIp(Ip.tryParse(next)!), Ip.tryParse(ip)!);
      });
    }
  });
}
