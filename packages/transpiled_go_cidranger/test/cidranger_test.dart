// Parity port of github.com/libp2p/go-cidranger/cidranger_test.go's
// "against base ranger" randomized cross-check (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md): [Ranger.pcTrie] is checked against
// [BruteRanger] (the ground-truth linear-scan implementation) over
// random IPs, using the same real-world AWS IP-range CIDR list upstream
// ships as testdata.
//
// Upstream runs 100000 iterations per case; this port runs far fewer
// (still catching any prefix-trie divergence, since every iteration is an
// independent random draw) to keep the default `dart test` run fast --
// a deliberate scope reduction on iteration COUNT only, not on the
// technique or the data used.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_go_cidranger/src/brute_ranger.dart';
import 'package:transpiled_go_cidranger/transpiled_go_cidranger.dart';

const _iterations = 2000;

void main() {
  final raw =
      jsonDecode(File('test/testdata/aws_ip_ranges.json').readAsStringSync())
          as Map<String, dynamic>;
  final v4Prefixes = [
    for (final p in raw['prefixes'] as List<dynamic>)
      (p as Map<String, dynamic>)['ip_prefix'] as String,
  ];
  final v6Prefixes = [
    for (final p in raw['ipv6_prefixes'] as List<dynamic>)
      (p as Map<String, dynamic>)['ipv6_prefix'] as String,
  ];

  Ranger pcTrie() {
    final r = Ranger.pcTrie();
    for (final c in v4Prefixes) {
      r.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
    }
    for (final c in v6Prefixes) {
      r.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
    }
    return r;
  }

  Ranger brute() {
    final r = BruteRanger();
    for (final c in v4Prefixes) {
      r.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
    }
    for (final c in v6Prefixes) {
      r.insert(RangerEntry.basic(IpNet.tryParseCidr(c)!));
    }
    return r;
  }

  final rand = Random(42);

  Ip randIpv4() {
    final bytes = Uint8List(4);
    for (var i = 0; i < 4; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return Ip.fromBytes(bytes);
  }

  Ip curatedIpv6() {
    final cidr = v6Prefixes[rand.nextInt(v6Prefixes.length)];
    final network = Network.fromIpNetwork(IpNet.tryParseCidr(cidr)!);
    final words = [for (var i = 0; i < 4; i++) network.number[i]];
    final zeros = 128 - network.mask.ones;
    final wordIdx = zeros ~/ 32;
    words[wordIdx] = (rand.nextInt(1 << 16) << 16) | rand.nextInt(1 << 16);
    return NetworkNumber(words).toIp();
  }

  test('pcTrie.contains matches brute.contains over random IPv4', () {
    final trie = pcTrie();
    final base = brute();
    for (var i = 0; i < _iterations; i++) {
      final ip = randIpv4();
      expect(trie.contains(ip), base.contains(ip));
    }
  });

  test('pcTrie.containingNetworks matches brute.containingNetworks over '
      'random IPv4', () {
    final trie = pcTrie();
    final base = brute();
    for (var i = 0; i < _iterations; i++) {
      final ip = randIpv4();
      final expected = base.containingNetworks(ip);
      final actual = trie.containingNetworks(ip);
      expect(actual.length, expected.length);
      for (final n in actual) {
        expect(expected, contains(n));
      }
    }
  });

  test('pcTrie.contains matches brute.contains over curated IPv6', () {
    final trie = pcTrie();
    final base = brute();
    for (var i = 0; i < _iterations; i++) {
      final ip = curatedIpv6();
      expect(trie.contains(ip), base.contains(ip));
    }
  });
}
