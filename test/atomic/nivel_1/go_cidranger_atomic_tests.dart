// Testes atômicos 1 para 1 para o módulo transpiled_go_cidranger (porte de
// github.com/libp2p/go-cidranger, revisão fixada em
// doc/transpilation/UPSTREAM_LOCK.md).
import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_go_cidranger/src/brute_ranger.dart';
import 'package:transpiled_go_cidranger/transpiled_go_cidranger.dart';

void main() {
  group('IpVersion [Atomic Audit]', () {
    test('values -- has exactly ipv4 and ipv6', () {
      expect(IpVersion.values, [IpVersion.ipv4, IpVersion.ipv6]);
    });
  });

  group('constants [Atomic Audit]', () {
    test(
      'ipv4Uint32Count / ipv6Uint32Count / bitsPerUint32 / bytePerUint32',
      () {
        expect(ipv4Uint32Count, 1);
        expect(ipv6Uint32Count, 4);
        expect(bitsPerUint32, 32);
        expect(bytePerUint32, 4);
      },
    );
  });

  group('InvalidBitPositionException [Atomic Audit]', () {
    test('toString() -- describes the error', () {
      expect(
        const InvalidBitPositionException().toString(),
        'bit position not valid',
      );
    });
  });

  group('VersionMismatchException [Atomic Audit]', () {
    test('toString() -- describes the error', () {
      expect(
        const VersionMismatchException().toString(),
        'Network input version mismatch',
      );
    });
  });

  group('NoGreatestCommonBitException [Atomic Audit]', () {
    test('toString() -- describes the error', () {
      expect(
        const NoGreatestCommonBitException().toString(),
        'No greatest common bit',
      );
    });
  });

  group('InvalidNetworkInputException [Atomic Audit]', () {
    test('toString() -- describes the error', () {
      expect(
        const InvalidNetworkInputException().toString(),
        'Invalid network input',
      );
    });
  });

  group('InvalidNetworkNumberInputException [Atomic Audit]', () {
    test('toString() -- describes the error', () {
      expect(
        const InvalidNetworkNumberInputException().toString(),
        'Invalid network number input',
      );
    });
  });

  group('NetworkNumber [Atomic Audit]', () {
    test('fromIp() -- null input returns null', () {
      expect(NetworkNumber.fromIp(null), isNull);
    });

    test('fromIp() -- builds words from an Ip', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('128.0.0.0'))!;
      expect(nn.length, 1);
      expect(nn[0], 2147483648);
    });

    test('fromIp() -- malformed ip (neither 4 nor 16 bytes) returns null', () {
      expect(NetworkNumber.fromIp(Ip.fromBytes([1, 2, 3, 4, 5])), isNull);
    });

    test('length getter -- word count', () {
      expect(const NetworkNumber([1]).length, 1);
      expect(const NetworkNumber([1, 2, 3, 4]).length, 4);
    });

    test('operator [] -- indexes a word', () {
      expect(const NetworkNumber([7, 8])[1], 8);
    });

    test('toV4() -- returns self for a 1-word number, null otherwise', () {
      final v4 = const NetworkNumber([1]);
      expect(v4.toV4(), v4);
      expect(const NetworkNumber([1, 1, 1, 1]).toV4(), isNull);
    });

    test('toV6() -- returns self for a 4-word number, null otherwise', () {
      final v6 = const NetworkNumber([1, 1, 1, 1]);
      expect(v6.toV6(), v6);
      expect(const NetworkNumber([1]).toV6(), isNull);
    });

    test('toIp() -- round-trips through fromIp', () {
      final addr = Ip.tryParse('192.128.0.1')!;
      expect(NetworkNumber.fromIp(addr)!.toIp(), addr);
    });

    test('operator == -- value equality, including version mismatch', () {
      expect(const NetworkNumber([1]) == const NetworkNumber([1]), isTrue);
      expect(const NetworkNumber([1]) == const NetworkNumber([2]), isFalse);
      expect(
        const NetworkNumber([1]) == const NetworkNumber([1, 0, 0, 0]),
        isFalse,
      );
    });

    test('hashCode -- equal values hash equal', () {
      expect(
        const NetworkNumber([1, 2]).hashCode,
        const NetworkNumber([1, 2]).hashCode,
      );
    });

    test('next() -- increments, wrapping on overflow', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('0.0.0.255'))!;
      expect(nn.next(), NetworkNumber.fromIp(Ip.tryParse('0.0.1.0')));
    });

    test('previous() -- decrements, wrapping on underflow', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('0.0.1.0'))!;
      expect(nn.previous(), NetworkNumber.fromIp(Ip.tryParse('0.0.0.255')));
    });

    test('bit() -- reads a bit, throws out of range', () {
      final nn = NetworkNumber.fromIp(Ip.tryParse('128.0.0.0'))!;
      expect(nn.bit(31), 1);
      expect(nn.bit(0), 0);
      expect(() => nn.bit(32), throwsA(isA<InvalidBitPositionException>()));
    });

    test('leastCommonBitPosition() -- finds divergence, throws at first bit '
        'or on version mismatch', () {
      const a = NetworkNumber([2147483648]);
      const b = NetworkNumber([3221225472]);
      expect(a.leastCommonBitPosition(b), 31);
      expect(
        () => a.leastCommonBitPosition(const NetworkNumber([1])),
        throwsA(isA<NoGreatestCommonBitException>()),
      );
      expect(
        () => a.leastCommonBitPosition(const NetworkNumber([1, 1, 1, 1])),
        throwsA(isA<VersionMismatchException>()),
      );
    });
  });

  group('NetworkNumberMask [Atomic Audit]', () {
    test('mask() -- masks a NetworkNumber to the given prefix length', () {
      expect(
        const NetworkNumberMask(16).mask(const NetworkNumber([0xFFFFFFFF])),
        const NetworkNumber([0xFFFF0000]),
      );
    });

    test('compareTo() -- orders by prefix length', () {
      expect(
        const NetworkNumberMask(16).compareTo(const NetworkNumberMask(24)),
        lessThan(0),
      );
    });

    test('operator < -- fewer leading one-bits than other', () {
      expect(const NetworkNumberMask(16) < const NetworkNumberMask(24), isTrue);
    });

    test('operator <= -- no more leading one-bits than other', () {
      expect(
        const NetworkNumberMask(24) <= const NetworkNumberMask(24),
        isTrue,
      );
    });

    test('operator == -- value equality', () {
      expect(
        const NetworkNumberMask(24) == const NetworkNumberMask(24),
        isTrue,
      );
    });

    test('hashCode -- equal values hash equal', () {
      expect(
        const NetworkNumberMask(24).hashCode,
        const NetworkNumberMask(24).hashCode,
      );
    });

    test('toString() -- the prefix length as text', () {
      expect(const NetworkNumberMask(24).toString(), '24');
    });
  });

  group('Network [Atomic Audit]', () {
    test('fromIpNetwork() -- converts from the outer IpNet', () {
      final n = Network.fromIpNetwork(IpNet.tryParseCidr('192.128.0.0/24')!);
      expect(n.number, const NetworkNumber([3229614080]));
      expect(n.mask, const NetworkNumberMask(24));
    });

    test('masked() -- re-masks to a broader or narrower prefix', () {
      final n = Network.fromIpNetwork(IpNet.tryParseCidr('192.168.0.0/16')!);
      expect(
        n.masked(8).toIpNetwork(),
        Network.fromIpNetwork(IpNet.tryParseCidr('192.0.0.0/8')!).toIpNetwork(),
      );
    });

    test('contains() -- membership by masked prefix', () {
      final n = Network.fromIpNetwork(IpNet.tryParseCidr('192.168.0.0/24')!);
      expect(
        n.contains(NetworkNumber.fromIp(Ip.tryParse('192.168.0.5'))!),
        isTrue,
      );
      expect(
        n.contains(NetworkNumber.fromIp(Ip.tryParse('192.168.1.5'))!),
        isFalse,
      );
    });

    test('covers() -- subsumption by address and mask breadth', () {
      final broad = Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/15')!);
      final narrow = Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/16')!);
      expect(broad.covers(narrow), isTrue);
      expect(narrow.covers(broad), isFalse);
    });

    test('leastCommonBitPosition() -- floored at the narrower mask', () {
      final n1 = Network.fromIpNetwork(IpNet.tryParseCidr('0.0.0.128/24')!);
      final n2 = Network.fromIpNetwork(IpNet.tryParseCidr('0.0.0.0/16')!);
      expect(n1.leastCommonBitPosition(n2), 16);
    });

    test('operator == -- value equality', () {
      final a = Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/8')!);
      final b = Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/8')!);
      expect(a == b, isTrue);
    });

    test('hashCode -- equal values hash equal', () {
      final a = Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/8')!);
      final b = Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/8')!);
      expect(a.hashCode, b.hashCode);
    });

    test('toString() -- "address/prefixLength"', () {
      expect(
        Network.fromIpNetwork(IpNet.tryParseCidr('10.0.0.0/8')!).toString(),
        '10.0.0.0/8',
      );
    });

    test('toIpNetwork() -- round-trips through fromIpNetwork', () {
      final ipNet = IpNet.tryParseCidr('10.0.0.0/8')!;
      expect(Network.fromIpNetwork(ipNet).toIpNetwork(), ipNet);
    });
  });

  group('nextIp / previousIp [Atomic Audit]', () {
    test('nextIp() -- the next sequential address', () {
      expect(nextIp(Ip.tryParse('0.0.0.255')!), Ip.tryParse('0.0.1.0')!);
    });

    test('previousIp() -- the previous sequential address', () {
      expect(previousIp(Ip.tryParse('0.0.1.0')!), Ip.tryParse('0.0.0.255')!);
    });

    test('nextIp() -- a malformed ip yields the nil address, not a throw', () {
      expect(nextIp(Ip.fromBytes([1, 2, 3, 4, 5])), const Ip.nil());
    });
  });

  group('RangerEntry [Atomic Audit]', () {
    test('basic() -- stores the given network', () {
      final ipNet = IpNet.tryParseCidr('192.168.0.0/24')!;
      expect(RangerEntry.basic(ipNet).network(), ipNet);
    });

    test('network() -- returns the network as-is', () {
      final ipNet = IpNet.tryParseCidr('192.168.0.0/24')!;
      expect(RangerEntry.basic(ipNet).network(), ipNet);
    });
  });

  group('allIpv4 / allIpv6 [Atomic Audit]', () {
    test('allIpv4 -- the 0.0.0.0/0 CIDR', () {
      expect(allIpv4, IpNet.tryParseCidr('0.0.0.0/0')!);
    });

    test('allIpv6 -- the ::/0 CIDR', () {
      expect(allIpv6, IpNet.tryParseCidr('0::0/0')!);
    });
  });

  group('Ranger [Atomic Audit]', () {
    test('pcTrie() -- insert/contains/length over a trie-backed ranger', () {
      final r = Ranger.pcTrie();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      expect(r.length, 1);
      expect(r.contains(Ip.tryParse('10.1.2.3')!), isTrue);
      expect(r.contains(Ip.tryParse('11.0.0.0')!), isFalse);
    });

    test('insert() -- increases length', () {
      final r = Ranger.pcTrie();
      expect(r.length, 0);
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      expect(r.length, 1);
    });

    test('remove() -- returns the removed entry, null if absent', () {
      final r = Ranger.pcTrie();
      final entry = RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!);
      r.insert(entry);
      expect(r.remove(IpNet.tryParseCidr('10.0.0.0/8')!), entry);
      expect(r.remove(IpNet.tryParseCidr('10.0.0.0/8')!), isNull);
    });

    test('contains() -- membership test', () {
      final r = Ranger.pcTrie();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      expect(r.contains(Ip.tryParse('10.0.0.1')!), isTrue);
    });

    test(
      'containingNetworks() -- every entry whose network contains the ip',
      () {
        final r = Ranger.pcTrie();
        r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
        r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/16')!));
        expect(r.containingNetworks(Ip.tryParse('10.0.0.1')!).length, 2);
      },
    );

    test('coveredNetworks() -- every entry subsumed by the search network', () {
      final r = Ranger.pcTrie();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/16')!));
      expect(r.coveredNetworks(IpNet.tryParseCidr('10.0.0.0/8')!).length, 1);
    });

    test('length getter -- number of stored networks', () {
      final r = Ranger.pcTrie();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('11.0.0.0/8')!));
      expect(r.length, 2);
    });
  });

  group('BruteRanger [Atomic Audit]', () {
    // BruteRanger (go-cidranger's unexported `bruteRanger`/`newBruteRanger`)
    // lives in its own `src/brute_ranger.dart` library, not exported by
    // the package barrel -- see that file's header. Its full behavior
    // (insert/remove/contains/containingNetworks/coveredNetworks over
    // both IPv4 and IPv6, plus the malformed-ip exception paths) is
    // covered 1:1 by
    // packages/transpiled_go_cidranger/test/brute_ranger_test.dart, which
    // every "Suíte verde" pass under AGENTS.md already runs; the tests
    // below are this method's own one-per-symbol atomic entry.
    test('BruteRanger() -- constructs an empty ranger', () {
      final r = BruteRanger();
      expect(r.length, 0);
      expect(r.contains(Ip.tryParse('10.1.2.3')!), isFalse);
    });

    test('insert() -- adds an entry, reachable via contains()', () {
      final r = BruteRanger();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      expect(r.length, 1);
      expect(r.contains(Ip.tryParse('10.1.2.3')!), isTrue);
    });

    test('remove() -- returns the removed entry, null if absent', () {
      final r = BruteRanger();
      final entry = RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!);
      r.insert(entry);
      expect(r.remove(IpNet.tryParseCidr('10.0.0.0/8')!), entry);
      expect(r.remove(IpNet.tryParseCidr('10.0.0.0/8')!), isNull);
    });

    test('contains() -- membership test', () {
      final r = BruteRanger();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      expect(r.contains(Ip.tryParse('10.0.0.1')!), isTrue);
      expect(r.contains(Ip.tryParse('11.0.0.0')!), isFalse);
    });

    test(
      'containingNetworks() -- every entry whose network contains the ip',
      () {
        final r = BruteRanger();
        r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
        r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/16')!));
        expect(r.containingNetworks(Ip.tryParse('10.0.0.1')!).length, 2);
      },
    );

    test('coveredNetworks() -- every entry subsumed by the search network', () {
      final r = BruteRanger();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/16')!));
      expect(r.coveredNetworks(IpNet.tryParseCidr('10.0.0.0/8')!).length, 1);
    });

    test('length getter -- number of stored networks', () {
      final r = BruteRanger();
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('10.0.0.0/8')!));
      r.insert(RangerEntry.basic(IpNet.tryParseCidr('11.0.0.0/8')!));
      expect(r.length, 2);
    });
  });
}
