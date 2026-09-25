// Parity port of github.com/libp2p/go-cidranger/trie_test.go (revision
// fixed in doc/transpilation/UPSTREAM_LOCK.md), exercised through the
// public [Ranger] interface ([Ranger.pcTrie]) rather than the private
// `newPrefixTree` Go's own test file uses directly -- this port keeps the
// single-version trie Dart-private (see trie.dart's header), and driving
// only IPv4 (or only IPv6) entries into the dual-version [Ranger.pcTrie]
// exercises exactly one single-version subtree, matching upstream's
// per-case behavior 1:1. `TestPrefixTrieString` (asserting the internal
// tree-rendering format) is not ported: it inspects `prefixTrie.String()`,
// which Go itself calls "mainly for visualization and debugging" and
// keeps unexported outside its own test file -- there is no public Dart
// surface to assert the same internal shape against.
import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_go_cidranger/transpiled_go_cidranger.dart';

void main() {
  group('Ranger.pcTrie insert', () {
    const cases = [
      (['192.168.0.1/24'], ['192.168.0.1/24'], 'basic insert'),
      (
        ['1.2.3.4/32', '1.2.3.5/32'],
        ['1.2.3.4/32', '1.2.3.5/32'],
        'single ip IPv4 network insert',
      ),
      (
        ['192.168.0.1/16', '192.168.0.1/24'],
        ['192.168.0.1/16', '192.168.0.1/24'],
        'in order insert',
      ),
      (
        ['192.168.0.1/32', '192.168.0.1/32'],
        ['192.168.0.1/32'],
        'duplicate network insert',
      ),
      (
        ['192.168.0.1/24', '192.168.0.1/16'],
        ['192.168.0.1/16', '192.168.0.1/24'],
        'reverse insert',
      ),
      (
        ['192.168.0.1/24', '192.168.1.1/24'],
        ['192.168.0.1/24', '192.168.1.1/24'],
        'branch insert',
      ),
      (
        ['192.168.0.1/24', '192.168.1.1/24', '192.168.1.1/30'],
        ['192.168.0.1/24', '192.168.1.1/24', '192.168.1.1/30'],
        'branch inserts',
      ),
    ];

    for (final (inserts, expectedNetworks, name) in cases) {
      test(name, () {
        final trie = Ranger.pcTrie();
        for (final cidr in inserts) {
          trie.insert(RangerEntry.basic(IpNet.tryParseCidr(cidr)!));
        }
        expect(trie.length, expectedNetworks.length);

        final all = trie.coveredNetworks(allIpv4);
        expect(all.length, trie.length);
        final expectedEntries = [
          for (final cidr in expectedNetworks)
            RangerEntry.basic(IpNet.tryParseCidr(cidr)!),
        ];
        for (final e in expectedEntries) {
          expect(all, contains(e));
        }
      });
    }
  });

  group('Ranger.pcTrie remove', () {
    test('basic remove', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/24')!));
      final removed = trie.remove(IpNet.tryParseCidr('192.168.0.1/24')!);
      expect(removed, RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/24')!));
      expect(trie.length, 0);
    });

    test('single ip IPv4 network remove', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('1.2.3.4/32')!));
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('1.2.3.5/32')!));
      final removed = trie.remove(IpNet.tryParseCidr('1.2.3.5/32')!);
      expect(removed, RangerEntry.basic(IpNet.tryParseCidr('1.2.3.5/32')!));
      expect(trie.length, 1);
      expect(trie.coveredNetworks(allIpv4), [
        RangerEntry.basic(IpNet.tryParseCidr('1.2.3.4/32')!),
      ]);
    });

    test('remove path prefix', () {
      final trie = Ranger.pcTrie();
      for (final c in ['192.168.0.1/24', '192.168.0.1/25', '192.168.0.1/26']) {
        trie.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
      }
      final removed = trie.remove(IpNet.tryParseCidr('192.168.0.1/25')!);
      expect(removed, RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/25')!));
      expect(trie.length, 2);
    });

    test('remove non existent returns null', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/24')!));
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/25')!));
      final removed = trie.remove(IpNet.tryParseCidr('192.168.0.1/26')!);
      expect(removed, isNull);
      expect(trie.length, 2);
    });
  });

  group('Ranger.pcTrie contains / containingNetworks', () {
    test('basic containing network for /32 mask', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/32')!));
      final ip = Ip.tryParse('192.168.0.1')!;
      expect(trie.contains(ip), isTrue);
      expect(trie.containingNetworks(ip), [
        RangerEntry.basic(IpNet.tryParseCidr('192.168.0.1/32')!),
      ]);
    });

    test('basic containing network for /128 mask (IPv6)', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('a::1/128')!));
      final ip = Ip.tryParse('a::1')!;
      expect(trie.contains(ip), isTrue);
      expect(trie.containingNetworks(ip), [
        RangerEntry.basic(IpNet.tryParseCidr('a::1/128')!),
      ]);
    });

    test('basic contains over a range', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.0/24')!));

      var ip = Ip.tryParse('192.168.0.0')!;
      final end = Ip.tryParse('192.168.1.0')!;
      while (ip != end) {
        expect(trie.contains(ip), isTrue);
        ip = nextIp(ip);
      }
      expect(trie.contains(previousIp(Ip.tryParse('192.168.0.0')!)), isFalse);
      expect(trie.contains(nextIp(Ip.tryParse('192.168.1.0')!)), isFalse);
    });

    test('inclusive containing networks (broadest first)', () {
      final trie = Ranger.pcTrie();
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.0/24')!));
      trie.insert(RangerEntry.basic(IpNet.tryParseCidr('192.168.0.0/25')!));
      expect(trie.containingNetworks(Ip.tryParse('192.168.0.1')!), [
        RangerEntry.basic(IpNet.tryParseCidr('192.168.0.0/24')!),
        RangerEntry.basic(IpNet.tryParseCidr('192.168.0.0/25')!),
      ]);
    });
  });

  group('Ranger.pcTrie coveredNetworks', () {
    const cases = [
      (['192.168.0.0/24'], '192.168.0.0/16', ['192.168.0.0/24']),
      (['192.168.0.0/24'], '10.1.0.0/16', <String>[]),
      (
        ['192.168.0.0/24', '192.168.0.0/25'],
        '192.168.0.0/16',
        ['192.168.0.0/24', '192.168.0.0/25'],
      ),
      (['192.168.1.1/32'], '192.168.0.0/16', ['192.168.1.1/32']),
      (['0.0.0.0/0', '192.168.1.1/32'], '192.168.0.0/16', ['192.168.1.1/32']),
      (['192.168.0.0/15'], '192.168.0.0/16', <String>[]),
    ];

    for (final (inserts, search, expectedNetworks) in cases) {
      test('covered networks for $search', () {
        final trie = Ranger.pcTrie();
        for (final c in inserts) {
          trie.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
        }
        final expectedEntries = [
          for (final c in expectedNetworks)
            RangerEntry.basic(IpNet.tryParseCidr(c)!),
        ];
        final results = trie.coveredNetworks(IpNet.tryParseCidr(search)!);
        expect(results.length, expectedEntries.length);
        for (final e in expectedEntries) {
          expect(results, contains(e));
        }
      });
    }
  });
}
