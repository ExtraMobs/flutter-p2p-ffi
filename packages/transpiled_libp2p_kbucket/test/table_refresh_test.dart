// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p-kbucket's table_refresh_test.go: TestGenRandPeerID,
// TestGenRandomKey, and TestRefreshAndGetTrackedCpls.
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';

class _NoOpMetrics implements PeerMetrics {
  @override
  Duration latencyEwma(PeerId id) => Duration.zero;
}

PeerId _randPeerId() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  return PeerId(value: bytes);
}

RoutingTable _newTable(int bucketSize, PeerId local) => RoutingTable(
  bucketSize: bucketSize,
  local: local,
  maxLatency: const Duration(hours: 1),
  metrics: _NoOpMetrics(),
  usefulnessGracePeriod: const Duration(hours: 100), // Go's NoOpThreshold.
);

void main() {
  test('genRandPeerId: rejects > maxCplForRefresh, produces the exact requested CPL', () {
    final local = _randPeerId();
    final rt = _newTable(1, local);

    expect(() => rt.genRandPeerId(maxCplForRefresh + 1), throwsArgumentError);

    for (var cpl = 0; cpl <= maxCplForRefresh; cpl++) {
      final peerId = rt.genRandPeerId(cpl);
      expect(
        commonPrefixLen(convertPeerId(PeerId(value: peerId)), convertPeerId(local)),
        equals(cpl),
        reason: 'failed for cpl=$cpl',
      );
    }
  });

  test('genRandomKey: matches local key up to cpl bits, differs at bit cpl+1', () {
    // Run multiple occurrences to make sure the test wasn't just lucky,
    // matching the Go test's own `for range 100`.
    for (var iteration = 0; iteration < 100; iteration++) {
      final local = _randPeerId();
      final rt = _newTable(1, local);
      final localKey = convertPeerId(local);

      expect(() => rt.genRandomKey(256), throwsArgumentError);
      expect(() => rt.genRandomKey(300), throwsArgumentError);

      // cpl = 0: first bit differs.
      final key0 = rt.genRandomKey(0);
      expect(key0[0] >> 7, isNot(equals(localKey[0] >> 7)));

      // cpl = 1: first bit equal, second bit differs.
      final key1 = rt.genRandomKey(1);
      expect(key1[0] >> 7, equals(localKey[0] >> 7));
      expect((key1[0] << 1) & 0xFF, isNot(equals((localKey[0] << 1) & 0xFF)));

      // cpl = 7: first 7 bits equal, 8th bit differs.
      final key7 = rt.genRandomKey(7);
      expect(key7[0] >> 1, equals(localKey[0] >> 1));
      expect(key7[0] & 0x01, isNot(equals(localKey[0] & 0x01)));

      // cpl = 8: first byte equal, 9th bit (first bit of 2nd byte) differs.
      final key8 = rt.genRandomKey(8);
      expect(key8[0], equals(localKey[0]));
      expect(key8[1] >> 7, isNot(equals(localKey[1] >> 7)));

      // cpl = 53: first 6 bytes plus the top 5 bits of byte 6 equal, the
      // bit right after that (bit 54) differs.
      final key53 = rt.genRandomKey(53);
      expect(key53.sublist(0, 6), equals(localKey.sublist(0, 6)));
      expect(key53[6] >> 3, equals(localKey[6] >> 3));
      expect((key53[6] >> 2) & 0x01, isNot(equals((localKey[6] >> 2) & 0x01)));
    }
  });

  test('refresh tracking grows/shrinks with TryAddPeer/RemovePeer and ResetCplRefreshedAtForId', () {
    const minCpl = 8;
    const testCpl = 10;
    const maxCpl = 12;

    final local = _randPeerId();
    final rt = _newTable(2, local);

    expect(rt.getTrackedCplsForRefresh(), hasLength(1));

    final peerIds = <PeerId>[
      for (var i = minCpl; i <= maxCpl; i++) PeerId(value: rt.genRandPeerId(i)),
    ];

    for (var i = 0; i < peerIds.length; i++) {
      final added = rt.tryAddPeer(peerIds[i], queryPeer: true, isReplaceable: false);
      expect(added, isTrue);
      expect(rt.getTrackedCplsForRefresh(), hasLength(minCpl + i + 1));
    }

    for (var i = maxCpl; i > testCpl; i--) {
      rt.removePeer(peerIds[i - minCpl]);
      expect(rt.getTrackedCplsForRefresh(), hasLength(i));
    }

    var trackedCpls = rt.getTrackedCplsForRefresh();
    expect(trackedCpls, hasLength(testCpl + 1));
    for (final refresh in trackedCpls) {
      expect(refresh.millisecondsSinceEpoch, equals(0));
    }

    final added = rt.tryAddPeer(local, queryPeer: true, isReplaceable: false);
    expect(added, isTrue);

    trackedCpls = rt.getTrackedCplsForRefresh();
    expect(trackedCpls, hasLength(maxCplForRefresh + 1));
    for (final refresh in trackedCpls) {
      expect(refresh.millisecondsSinceEpoch, equals(0));
    }

    final now = DateTime.now().toUtc();
    rt.resetCplRefreshedAtForId(convertPeerId(peerIds[testCpl - minCpl]), now);

    trackedCpls = rt.getTrackedCplsForRefresh();
    expect(trackedCpls, hasLength(maxCplForRefresh + 1));
    for (var i = 0; i < trackedCpls.length; i++) {
      if (i == testCpl) {
        expect(trackedCpls[i], equals(now));
      } else {
        expect(trackedCpls[i].millisecondsSinceEpoch, equals(0));
      }
    }
  });
}
