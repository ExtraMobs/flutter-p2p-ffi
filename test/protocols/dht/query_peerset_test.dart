import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/src/protocols/dht/query_peerset.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

void main() {
  PeerId peer(int value) => PeerId(value: Uint8List.fromList([value]));

  int compare(PeerId target, PeerId a, PeerId b) =>
      (target.value.first ^ a.value.first).compareTo(
        target.value.first ^ b.value.first,
      );

  test('tracks state, referrer, uniqueness and XOR order', () {
    final target = peer(0);
    final oracle = peer(9);
    final peers = QueryPeerset(target, compare);

    expect(peers.tryAdd(peer(2), oracle), isTrue);
    expect(peers.tryAdd(peer(2), oracle), isFalse);
    expect(peers.tryAdd(peer(4), oracle), isTrue);
    expect(peers.getClosestNInStates(2, {PeerState.heard}), [peer(2), peer(4)]);
    expect(peers.getReferrer(peer(2)), oracle);
    expect(peers.numHeard, 2);

    peers.setState(peer(2), PeerState.waiting);
    expect(peers.numWaiting, 1);
    peers.setState(peer(2), PeerState.queried);
    peers.setState(peer(4), PeerState.unreachable);

    expect(peers.getClosestInStates({PeerState.heard, PeerState.queried}), [
      peer(2),
    ]);
    expect(() => peers.setState(peer(8), PeerState.heard), throwsStateError);
  });

  test('matches the upstream qpeerset transition vector', () {
    // The upstream test uses random IDs arranged as:
    // target < peer3 < peer1 < peer4 < peer2.
    final target = peer(0);
    final oracle = peer(9);
    final peers = QueryPeerset(target, compare);
    final peer2 = peer(8);
    final peer4 = peer(4);
    final peer1 = peer(2);
    final peer3 = peer(1);

    expect(peers.getClosestInStates({PeerState.heard}), isEmpty);
    expect(peers.tryAdd(peer2, oracle), isTrue);
    expect(peers.getState(peer2), PeerState.heard);
    expect(peers.tryAdd(peer2, oracle), isFalse);
    expect(peers.numWaiting, 0);

    expect(peers.tryAdd(peer4, oracle), isTrue);
    expect(
      peers.getClosestNInStates(2, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      }),
      [peer4, peer2],
    );
    expect(
      peers.getClosestNInStates(3, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      }),
      [peer4, peer2],
    );
    expect(
      peers.getClosestNInStates(1, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      }),
      [peer4],
    );
    expect(peers.getClosestNInStates(0, {PeerState.heard}), isEmpty);
    expect(peers.getClosestNInStates(2, const {}), isEmpty);
    expect(
      () => peers.getClosestNInStates(-1, {PeerState.heard}),
      throwsRangeError,
    );

    peers.setState(peer4, PeerState.unreachable);
    expect(
      peers.getClosestNInStates(1, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      }),
      [peer2],
    );

    expect(peers.tryAdd(peer1, oracle), isTrue);
    expect(
      peers.getClosestNInStates(1, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      }),
      [peer1],
    );
    expect(
      peers.getClosestNInStates(2, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      }),
      [peer1, peer2],
    );

    peers.setState(peer2, PeerState.waiting);
    expect(peers.getClosestInStates({PeerState.waiting}), [peer2]);
    expect(peers.getClosestInStates({PeerState.heard}), [peer1]);
    expect(peers.tryAdd(peer3, oracle), isTrue);
    expect(peers.getClosestInStates({PeerState.heard}), [peer3, peer1]);
    expect(peers.numHeard, 2);
    expect(peers.getReferrer(peer3), oracle);
    expect(() => peers.getState(peer(7)), throwsStateError);
  });
}
