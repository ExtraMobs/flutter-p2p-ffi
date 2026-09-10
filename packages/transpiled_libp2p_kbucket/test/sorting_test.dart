// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p-kbucket's sorting_test.go: TestSortClosestPeersIsSorted,
// TestSortClosestPeersDoesNotMutateInput.
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';

PeerId _randPeerId() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  return PeerId(value: bytes);
}

int _compareDhtId(DhtId a, DhtId b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

void main() {
  test('sortClosestPeers: returns every peer, sorted by ascending XOR distance', () {
    final target = convertPeerId(_randPeerId());

    for (final n in [0, 1, 2, 3, 17, 200]) {
      final peers = List.generate(n, (_) => _randPeerId());
      final sorted = sortClosestPeers(peers, target);

      expect(sorted, hasLength(n));
      for (var i = 1; i < sorted.length; i++) {
        final prev = xor(target, convertPeerId(sorted[i - 1]));
        final cur = xor(target, convertPeerId(sorted[i]));
        expect(_compareDhtId(prev, cur), lessThanOrEqualTo(0), reason: 'n=$n: not sorted at index $i');
      }
    }
  });

  test('sortClosestPeers: does not mutate its input list', () {
    final peers = List.generate(64, (_) => _randPeerId());
    final original = List.of(peers);
    final target = convertPeerId(peers[0]);

    sortClosestPeers(peers, target);

    expect(peers, equals(original));
  });
}
