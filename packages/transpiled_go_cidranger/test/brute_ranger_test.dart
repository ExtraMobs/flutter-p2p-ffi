// Parity port of github.com/libp2p/go-cidranger/brute_test.go (revision
// fixed in doc/transpilation/UPSTREAM_LOCK.md), exercised through
// [BruteRanger] (declared in its own `src/brute_ranger.dart` library, not
// exported by the package barrel -- see that file's header for why the
// class is public here despite Go's `newBruteRanger`/`bruteRanger` being
// unexported). The "invalid IP" sub-cases (a `net.IP` with an appended
// stray byte) are ported here as an [Ip] of that same malformed length,
// since -- unlike `dart:io`'s `InternetAddress` -- [Ip] accepts any byte
// length, just like Go's `net.IP`.
import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_go_cidranger/src/brute_ranger.dart';
import 'package:transpiled_go_cidranger/transpiled_go_cidranger.dart';

void main() {
  group('BruteRanger insert/remove', () {
    test('insert', () {
      final ranger = BruteRanger();
      final ipv4 = RangerEntry.basic(IpNet.tryParseCidr('0.0.1.0/24')!);
      final ipv6 = RangerEntry.basic(IpNet.tryParseCidr('8000::/96')!);
      ranger.insert(ipv4);
      ranger.insert(ipv6);
      expect(ranger.length, 2);
    });

    test('insert() -- throws InvalidNetworkInputException for a malformed '
        'ip', () {
      final ranger = BruteRanger();
      final malformed = IpNet(
        ip: Ip.fromBytes([0, 0, 1, 0, 4]),
        mask: Uint8List.fromList([0xff, 0xff, 0xff, 0]),
      );
      expect(
        () => ranger.insert(RangerEntry.basic(malformed)),
        throwsA(isA<InvalidNetworkInputException>()),
      );
    });

    test('remove', () {
      final ranger = BruteRanger();
      final ipv4 = RangerEntry.basic(IpNet.tryParseCidr('0.0.1.0/24')!);
      final ipv6 = RangerEntry.basic(IpNet.tryParseCidr('8000::/96')!);
      ranger.insert(ipv4);
      final removedV4 = ranger.remove(IpNet.tryParseCidr('0.0.1.0/24')!);
      ranger.insert(ipv6);
      final removedV6 = ranger.remove(IpNet.tryParseCidr('8000::/96')!);
      final notInserted = ranger.remove(IpNet.tryParseCidr('192.168.0.0/24')!);

      expect(removedV4, ipv4);
      expect(removedV6, ipv6);
      expect(notInserted, isNull);
      expect(ranger.length, 0);
    });

    test('remove() -- throws InvalidNetworkInputException for a malformed '
        'ip', () {
      final ranger = BruteRanger();
      final malformed = IpNet(
        ip: Ip.fromBytes([0, 0, 1, 0, 4]),
        mask: Uint8List.fromList([0xff, 0xff, 0xff, 0]),
      );
      expect(
        () => ranger.remove(malformed),
        throwsA(isA<InvalidNetworkInputException>()),
      );
    });
  });

  group('BruteRanger contains', () {
    late Ranger ranger;
    setUp(() {
      ranger = BruteRanger();
      ranger.insert(RangerEntry.basic(IpNet.tryParseCidr('0.0.1.0/24')!));
      ranger.insert(RangerEntry.basic(IpNet.tryParseCidr('8000::/112')!));
    });

    test('IPv4 should contain', () {
      expect(ranger.contains(Ip.tryParse('0.0.1.255')!), isTrue);
    });
    test('IPv4 should not contain', () {
      expect(ranger.contains(Ip.tryParse('0.0.0.255')!), isFalse);
    });
    test('IPv6 should contain', () {
      expect(ranger.contains(Ip.tryParse('8000::ffff')!), isTrue);
    });
    test('IPv6 should not contain', () {
      expect(ranger.contains(Ip.tryParse('8000::1:ffff')!), isFalse);
    });
    test('throws InvalidNetworkInputException for a malformed ip', () {
      final malformed = Ip.fromBytes([
        ...Ip.tryParse('8000::1:ffff')!.asBytes(),
        0,
      ]);
      expect(
        () => ranger.contains(malformed),
        throwsA(isA<InvalidNetworkInputException>()),
      );
    });
  });

  group('BruteRanger containingNetworks', () {
    late Ranger ranger;
    late RangerEntry entry1, entry2, entry3, entry4;
    setUp(() {
      ranger = BruteRanger();
      entry1 = RangerEntry.basic(IpNet.tryParseCidr('0.0.1.0/24')!);
      entry2 = RangerEntry.basic(IpNet.tryParseCidr('0.0.1.0/25')!);
      entry3 = RangerEntry.basic(IpNet.tryParseCidr('8000::/112')!);
      entry4 = RangerEntry.basic(IpNet.tryParseCidr('8000::/113')!);
      ranger
        ..insert(entry1)
        ..insert(entry2)
        ..insert(entry3)
        ..insert(entry4);
    });

    test('IPv4 should contain one', () {
      final r = ranger.containingNetworks(Ip.tryParse('0.0.1.255')!);
      expect(r, [entry1]);
    });
    test('IPv4 should contain both', () {
      final r = ranger.containingNetworks(Ip.tryParse('0.0.1.127')!);
      expect(r.length, 2);
      expect(r, containsAll([entry1, entry2]));
    });
    test('IPv4 should contain none', () {
      expect(ranger.containingNetworks(Ip.tryParse('0.0.0.127')!), isEmpty);
    });
    test('IPv6 should contain', () {
      expect(ranger.containingNetworks(Ip.tryParse('8000::ffff')!), [entry3]);
    });
    test('IPv6 should contain both', () {
      final r = ranger.containingNetworks(Ip.tryParse('8000::7fff')!);
      expect(r.length, 2);
      expect(r, containsAll([entry3, entry4]));
    });
    test('throws InvalidNetworkInputException for a malformed ip', () {
      final malformed = Ip.fromBytes([
        ...Ip.tryParse('8000::1:7fff')!.asBytes(),
        0,
      ]);
      expect(
        () => ranger.containingNetworks(malformed),
        throwsA(isA<InvalidNetworkInputException>()),
      );
    });
  });

  group('BruteRanger coveredNetworks', () {
    const cases = [
      (['192.168.0.0/24'], '192.168.0.0/16', ['192.168.0.0/24']),
      (['192.168.0.0/24'], '10.1.0.0/16', <String>[]),
      (
        ['192.168.0.0/24', '192.168.0.0/25', '192.168.0.1/32'],
        '192.168.0.0/16',
        ['192.168.0.0/24', '192.168.0.0/25', '192.168.0.1/32'],
      ),
    ];

    for (final (inserts, search, expectedNetworks) in cases) {
      test('covers $search', () {
        final ranger = BruteRanger();
        for (final c in inserts) {
          ranger.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
        }
        final results =
            ranger
                .coveredNetworks(IpNet.tryParseCidr(search)!)
                .map((e) => e.network().toString())
                .toList()
              ..sort();
        final expected =
            expectedNetworks
                .map((c) => IpNet.tryParseCidr(c)!.toString())
                .toList()
              ..sort();
        expect(results, expected);
      });
    }
  });
}
