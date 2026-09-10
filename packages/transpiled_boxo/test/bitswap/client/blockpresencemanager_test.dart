import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/blockpresencemanager/blockpresencemanager.dart';

void main() {
  Cid newCid(String data) {
    return BasicBlock.fromData(Uint8List.fromList(utf8.encode(data))).cid();
  }

  PeerId newPeer(String id) {
    final bytes = utf8.encode(id);
    final mh = Uint8List(34)..setRange(0, 2, [0x12, 0x20]);
    for (var i = 0; i < bytes.length && i < 32; i++) {
      mh[i + 2] = bytes[i];
    }
    return PeerId.fromBytes(mh);
  }

  const expHasFalseMsg = 'Expected PeerHasBlock to return false';
  const expHasTrueMsg = 'Expected PeerHasBlock to return true';
  const expDoesNotHaveFalseMsg = 'Expected PeerDoesNotHaveBlock to return false';
  const expDoesNotHaveTrueMsg = 'Expected PeerDoesNotHaveBlock to return true';

  test('TestBlockPresenceManager', () {
    final bpm = BlockPresenceManager();

    final p = newPeer('peer_1');
    final c0 = newCid('c0');
    final c1 = newCid('c1');

    // Nothing stored yet, both PeerHasBlock and PeerDoesNotHaveBlock should
    // return false
    expect(bpm.peerHasBlock(p, c0), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c0), isFalse, reason: expDoesNotHaveFalseMsg);

    // HAVE cid0 / DONT_HAVE cid1
    bpm.receiveFrom(p, [c0], [c1]);

    // Peer has received HAVE for cid0
    expect(bpm.peerHasBlock(p, c0), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c0), isFalse, reason: expDoesNotHaveFalseMsg);

    // Peer has received DONT_HAVE for cid1
    expect(bpm.peerDoesNotHaveBlock(p, c1), isTrue, reason: expDoesNotHaveTrueMsg);
    expect(bpm.peerHasBlock(p, c1), isFalse, reason: expHasFalseMsg);

    // HAVE cid1 / DONT_HAVE cid0
    bpm.receiveFrom(p, [c1], [c0]);

    // DONT_HAVE cid0 should NOT over-write earlier HAVE cid0
    expect(bpm.peerDoesNotHaveBlock(p, c0), isFalse, reason: expDoesNotHaveFalseMsg);
    expect(bpm.peerHasBlock(p, c0), isTrue, reason: expHasTrueMsg);

    // HAVE cid1 should over-write earlier DONT_HAVE cid1
    expect(bpm.peerHasBlock(p, c1), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c1), isFalse, reason: expDoesNotHaveFalseMsg);

    // Remove cid0
    bpm.removeKeys([c0]);

    // Nothing stored, both PeerHasBlock and PeerDoesNotHaveBlock should
    // return false
    expect(bpm.peerHasBlock(p, c0), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c0), isFalse, reason: expDoesNotHaveFalseMsg);

    // Remove cid1
    bpm.removeKeys([c1]);

    // Nothing stored, both PeerHasBlock and PeerDoesNotHaveBlock should
    // return false
    expect(bpm.peerHasBlock(p, c1), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c1), isFalse, reason: expDoesNotHaveFalseMsg);

    bpm.receiveFrom(p, [c0], [c1]);
    expect(bpm.peerHasBlock(p, c0), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c1), isTrue, reason: expDoesNotHaveTrueMsg);

    bpm.removePeer(p);
    expect(bpm.peerHasBlock(p, c0), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c0), isFalse, reason: expDoesNotHaveFalseMsg);
    expect(bpm.peerHasBlock(p, c1), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p, c1), isFalse, reason: expDoesNotHaveFalseMsg);
  });

  test('TestAddRemoveMulti', () {
    final bpm = BlockPresenceManager();

    final p0 = newPeer('peer_0');
    final p1 = newPeer('peer_1');
    final c0 = newCid('c0');
    final c1 = newCid('c1');
    final c2 = newCid('c2');

    // p0: HAVE cid0, cid1 / DONT_HAVE cid1, cid2
    // p1: HAVE cid1, cid2 / DONT_HAVE cid0
    bpm.receiveFrom(p0, [c0, c1], [c1, c2]);
    bpm.receiveFrom(p1, [c1, c2], [c0]);

    // Peer 0 should end up with
    // - HAVE cid0
    // - HAVE cid1
    // - DONT_HAVE cid2
    expect(bpm.peerHasBlock(p0, c0), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerHasBlock(p0, c1), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerDoesNotHaveBlock(p0, c2), isTrue, reason: expDoesNotHaveTrueMsg);

    // Peer 1 should end up with
    // - HAVE cid1
    // - HAVE cid2
    // - DONT_HAVE cid0
    expect(bpm.peerHasBlock(p1, c1), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerHasBlock(p1, c2), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerDoesNotHaveBlock(p1, c0), isTrue, reason: expDoesNotHaveTrueMsg);

    // Remove cid1 and cid2. Should end up with
    // Peer 0: HAVE cid0
    // Peer 1: DONT_HAVE cid0
    bpm.removeKeys([c1, c2]);
    expect(bpm.peerHasBlock(p0, c0), isTrue, reason: expHasTrueMsg);
    expect(bpm.peerDoesNotHaveBlock(p1, c0), isTrue, reason: expDoesNotHaveTrueMsg);

    // The other keys should have been cleared, so both HasBlock() and
    // DoesNotHaveBlock() should return false
    expect(bpm.peerHasBlock(p0, c1), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p0, c1), isFalse, reason: expDoesNotHaveFalseMsg);
    expect(bpm.peerHasBlock(p0, c2), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p0, c2), isFalse, reason: expDoesNotHaveFalseMsg);
    expect(bpm.peerHasBlock(p1, c1), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p1, c1), isFalse, reason: expDoesNotHaveFalseMsg);
    expect(bpm.peerHasBlock(p1, c2), isFalse, reason: expHasFalseMsg);
    expect(bpm.peerDoesNotHaveBlock(p1, c2), isFalse, reason: expDoesNotHaveFalseMsg);
  });

  test('TestAllPeersDoNotHaveBlock', () {
    final bpm = BlockPresenceManager();

    final p0 = newPeer('peer_0');
    final p1 = newPeer('peer_1');
    final p2 = newPeer('peer_2');

    final c0 = newCid('c0');
    final c1 = newCid('c1');
    final c2 = newCid('c2');

    //      c0  c1  c2
    //  p0   ?  N   N
    //  p1   N  Y   ?
    //  p2   Y  Y   N
    bpm.receiveFrom(p0, [], [c1, c2]);
    bpm.receiveFrom(p1, [c1], [c0]);
    bpm.receiveFrom(p2, [c0, c1], [c2]);

    void runTestCase(List<PeerId> peers, List<Cid> ks, List<Cid> exp, int testIdx) {
      final res = bpm.allPeersDoNotHaveBlock(peers, ks);
      expect(res.map((e) => e.toString()), unorderedEquals(exp.map((e) => e.toString())), 
          reason: 'test case \$testIdx failed: expected matching keys');
    }

    runTestCase([p0], [c0], [], 0);
    runTestCase([p1], [c0], [c0], 1);
    runTestCase([p2], [c0], [], 2);

    runTestCase([p0], [c1], [c1], 3);
    runTestCase([p1], [c1], [], 4);
    runTestCase([p2], [c1], [], 5);

    runTestCase([p0], [c2], [c2], 6);
    runTestCase([p1], [c2], [], 7);
    runTestCase([p2], [c2], [c2], 8);

    // p0 received DONT_HAVE for c1 & c2 (but not for c0)
    runTestCase([p0], [c0, c1, c2], [c1, c2], 9);
    runTestCase([p0, p1], [c0, c1, c2], [], 10);
    // Both p0 and p2 received DONT_HAVE for c2
    runTestCase([p0, p2], [c0, c1, c2], [c2], 11);
    runTestCase([p0, p1, p2], [c0, c1, c2], [], 12);
  });
}
