// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Atomic tests for packages/transpiled_libp2p/lib/src/p2p/host/peerstore/pstoreds/**
// (port of go-libp2p's p2p/host/peerstore/pstoreds package).
//
// The acceptance criterion for this port is: a restart preserves known
// peers. `Pstoreds` group's 'restart preserves known peers' test is the
// direct proof of that -- everything else here is per-symbol coverage.
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart' hide Key;
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

Future<(PeerId, PrivKey)> _freshPeer() async {
  final kp = await generateEd25519KeyPair();
  return (PeerId.fromPubKey(kp.getPublic()), kp);
}

Multiaddr _addr(int port) => Multiaddr.parse('/ip4/127.0.0.1/tcp/$port');

/// A settable [Clock], so TTL-expiry behavior can be tested deterministically
/// instead of racing the real wall clock.
class _FakeClock implements Clock {
  _FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('pstoreds top-level functions', () {
    test('defaultOpts', () {
      final opts = defaultOpts();
      expect(opts.cacheSize, 1024);
      expect(opts.maxProtocols, 1024);
      expect(opts.maxAddrsPerPeer, 64);
      expect(opts.gcPurgeInterval, const Duration(hours: 2));
    });

    test('cleanAddrs', () async {
      final (pid, _) = await _freshPeer();
      final plain = _addr(4001);
      final withSuffix = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/p2p/${pid.toBase58()}');
      final (otherPid, _) = await _freshPeer();
      final wrongSuffix = Multiaddr.parse('/ip4/127.0.0.1/tcp/4002/p2p/${otherPid.toBase58()}');

      final result = cleanAddrs([plain, withSuffix, wrongSuffix], pid);
      expect(result.length, 2);
      expect(result[0], equals(plain));
      expect(result[1], equals(plain));
    });
  });

  group('AddrBookRecord', () {
    test('marshal', () {
      final rec = AddrBookRecord(
        id: Uint8List.fromList([1, 2, 3]),
        addrs: [AddrBookRecord_AddrEntry(addr: Uint8List.fromList([9, 9]), expiry: 100, ttl: 50)],
        certifiedRecord: CertifiedRecord(seq: 7, raw: Uint8List.fromList([4, 5])),
      );
      final bytes = rec.marshal();
      final decoded = AddrBookRecord.unmarshal(bytes);

      expect(decoded.id, equals(rec.id));
      expect(decoded.addrs, hasLength(1));
      expect(decoded.addrs[0].addr, equals(Uint8List.fromList([9, 9])));
      expect(decoded.addrs[0].expiry, 100);
      expect(decoded.addrs[0].ttl, 50);
      expect(decoded.certifiedRecord, isNotNull);
      expect(decoded.certifiedRecord!.seq, 7);
      expect(decoded.certifiedRecord!.raw, equals(Uint8List.fromList([4, 5])));
    });
  });

  group('Clock', () {
    test('now', () {
      final Clock clock = RealClock();
      final before = DateTime.now().subtract(const Duration(seconds: 2));
      final n = clock.now();
      final after = DateTime.now().add(const Duration(seconds: 2));
      expect(n.isAfter(before), isTrue);
      expect(n.isBefore(after), isTrue);
    });
  });

  group('RealClock', () {
    test('now', () {
      final n = RealClock().now();
      expect(n.difference(DateTime.now()).inSeconds.abs() < 2, isTrue);
    });
  });

  group('AddrsRecord', () {
    test('clean', () {
      final now = DateTime.now();
      final rec = AddrsRecord(
        AddrBookRecord(
          id: Uint8List(0),
          addrs: [
            AddrBookRecord_AddrEntry(
              addr: Uint8List.fromList([1]),
              expiry: now.subtract(const Duration(minutes: 1)).microsecondsSinceEpoch,
              ttl: const Duration(seconds: 1).inMicroseconds,
            ),
            AddrBookRecord_AddrEntry(
              addr: Uint8List.fromList([2]),
              expiry: now.add(const Duration(hours: 1)).microsecondsSinceEpoch,
              ttl: const Duration(hours: 1).inMicroseconds,
            ),
          ],
        ),
      );

      final changed = rec.clean(now);
      expect(changed, isTrue);
      expect(rec.record.addrs, hasLength(1));
      expect(rec.record.addrs.single.addr, equals(Uint8List.fromList([2])));
    });

    test('isGhost', () {
      final rec = AddrsRecord(AddrBookRecord(id: Uint8List(0)));
      expect(rec.isGhost, isTrue);
      rec.record.addrs.add(AddrBookRecord_AddrEntry(addr: Uint8List.fromList([1]), expiry: 0, ttl: 0));
      expect(rec.isGhost, isFalse);
    });
  });

  group('DsKeyBook', () {
    test('open', () async {
      final kb = await DsKeyBook.open(MapDatastore());
      expect(kb.peersWithKeys(), isEmpty);
    });

    test('pubKey', () async {
      final store = MapDatastore();
      final kb = await DsKeyBook.open(store);
      final (pid, kp) = await _freshPeer();
      // Ed25519 keys are short enough to be inlined ("identity" multihash)
      // in the peer ID itself, so pubKey() extracts it without an explicit
      // addPubKey call -- and, as a side effect, persists the extraction.
      final extracted = kb.pubKey(pid);
      expect(extracted, isNotNull);
      expect(extracted!.keyEquals(kp.getPublic()), isTrue);
      await kb.flush();
      final reopened = await DsKeyBook.open(store);
      expect(reopened.pubKey(pid)!.keyEquals(kp.getPublic()), isTrue);
    });

    test('addPubKey', () async {
      final store = MapDatastore();
      final kb = await DsKeyBook.open(store);
      final (pid, kp) = await _freshPeer();
      kb.addPubKey(pid, kp.getPublic());
      expect(kb.pubKey(pid)!.keyEquals(kp.getPublic()), isTrue);

      final (otherPid, otherKp) = await _freshPeer();
      expect(() => kb.addPubKey(otherPid, kp.getPublic()), throwsArgumentError);
      expect(kb.pubKey(otherPid)!.keyEquals(otherKp.getPublic()), isTrue);
    });

    test('privKey', () async {
      final kb = await DsKeyBook.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(kb.privKey(pid), isNull);
    });

    test('addPrivKey', () async {
      final store = MapDatastore();
      final kb = await DsKeyBook.open(store);
      final (pid, kp) = await _freshPeer();
      kb.addPrivKey(pid, kp);
      expect(kb.privKey(pid)!.keyEquals(kp), isTrue);
      await kb.flush();
      final reopened = await DsKeyBook.open(store);
      expect(reopened.privKey(pid)!.keyEquals(kp), isTrue);
    });

    test('peersWithKeys', () async {
      final kb = await DsKeyBook.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      kb.addPrivKey(pid, kp);
      expect(kb.peersWithKeys(), contains(pid));
    });

    test('removePeer', () async {
      final kb = await DsKeyBook.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      kb.addPrivKey(pid, kp);
      kb.removePeer(pid);
      expect(kb.peersWithKeys(), isNot(contains(pid)));
    });

    test('flush', () async {
      final kb = await DsKeyBook.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      kb.addPrivKey(pid, kp);
      await expectLater(kb.flush(), completes);
    });
  });

  group('DsPeerMetadata', () {
    test('open', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(() => pm.get(pid, 'x'), throwsA(isA<ItemNotFoundException>()));
    });

    test('put', () async {
      final store = MapDatastore();
      final pm = await DsPeerMetadata.open(store);
      final (pid, _) = await _freshPeer();
      pm.put(pid, 'agent', 'dart-ipfs/1.0');
      expect(pm.get(pid, 'agent'), 'dart-ipfs/1.0');
    });

    test('get', () async {
      final store = MapDatastore();
      final pm = await DsPeerMetadata.open(store);
      final (pid, _) = await _freshPeer();
      pm.put(pid, 'protoVersion', 'ipfs/0.1.0');
      await pm.flush();
      final reopened = await DsPeerMetadata.open(store);
      expect(reopened.get(pid, 'protoVersion'), 'ipfs/0.1.0');
    });

    test('removePeer', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      pm.put(pid, 'k', 'v');
      pm.removePeer(pid);
      expect(() => pm.get(pid, 'k'), throwsA(isA<ItemNotFoundException>()));
    });

    test('flush', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      pm.put(pid, 'k', 1);
      await expectLater(pm.flush(), completes);
    });
  });

  group('DsProtoBook', () {
    test('maxProtos', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm, maxProtocols: 3);
      expect(pb.maxProtos, 3);
    });

    test('setProtocols', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      pb.setProtocols(pid, ['/ipfs/id/1.0.0']);
      expect(pb.getProtocols(pid), ['/ipfs/id/1.0.0']);
    });

    test('addProtocols', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      pb.addProtocols(pid, ['/a']);
      pb.addProtocols(pid, ['/b']);
      expect(pb.getProtocols(pid), containsAll(['/a', '/b']));
    });

    test('getProtocols', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      expect(pb.getProtocols(pid), isEmpty);
    });

    test('supportsProtocols', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      pb.setProtocols(pid, ['/a', '/b']);
      expect(pb.supportsProtocols(pid, ['/a', '/c']), ['/a']);
    });

    test('firstSupportedProtocol', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      pb.setProtocols(pid, ['/a', '/b']);
      expect(pb.firstSupportedProtocol(pid, ['/z', '/b']), '/b');
      expect(pb.firstSupportedProtocol(pid, ['/z']), isNull);
    });

    test('removeProtocols', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      pb.setProtocols(pid, ['/a', '/b']);
      pb.removeProtocols(pid, ['/a']);
      expect(pb.getProtocols(pid), ['/b']);
    });

    test('removePeer', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm);
      final (pid, _) = await _freshPeer();
      pb.setProtocols(pid, ['/a']);
      pb.removePeer(pid);
      expect(pb.getProtocols(pid), isEmpty);
    });

    test('too many protocols throws', () async {
      final pm = await DsPeerMetadata.open(MapDatastore());
      final pb = DsProtoBook(pm, maxProtocols: 1);
      final (pid, _) = await _freshPeer();
      expect(() => pb.setProtocols(pid, ['/a', '/b']), throwsStateError);
    });
  });

  group('DsAddrBook', () {
    test('open', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      expect(ab.peersWithAddrs(), isEmpty);
    });

    test('addAddr', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      expect(ab.addrs(pid), [_addr(4001)]);
    });

    test('addAddrs', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.addAddrs(pid, [_addr(4001), _addr(4002)], const Duration(minutes: 5));
      expect(ab.addrs(pid), containsAll([_addr(4001), _addr(4002)]));
    });

    test('setAddr', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      // setAddr upserts (overriding TTL on a collision); unlike setAddrs
      // with a zero TTL, it never clears addresses absent from its own
      // argument list -- ClearAddrs is the only full-wipe operation.
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      ab.setAddr(pid, _addr(4002), const Duration(minutes: 5));
      expect(ab.addrs(pid), containsAll([_addr(4001), _addr(4002)]));

      ab.setAddr(pid, _addr(4002), const Duration(minutes: 1));
      expect(ab.addrs(pid), containsAll([_addr(4001), _addr(4002)]));
    });

    test('setAddrs', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.setAddrs(pid, [_addr(4001), _addr(4002)], const Duration(minutes: 5));
      expect(ab.addrs(pid), hasLength(2));
      ab.setAddrs(pid, [_addr(4001)], Duration.zero);
      expect(ab.addrs(pid), [_addr(4002)]);
    });

    test('updateAddrs', () async {
      // A fake, advanceable clock proves the TTL rewrite deterministically
      // instead of racing the real wall clock with a tiny TTL.
      final clock = _FakeClock(DateTime(2024, 1, 1));
      final ab = await DsAddrBook.open(MapDatastore(), Options(clock: clock));
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));

      ab.updateAddrs(pid, const Duration(minutes: 5), const Duration(seconds: 1));
      expect(ab.addrs(pid), [_addr(4001)]);

      clock.advance(const Duration(seconds: 2));
      expect(ab.addrs(pid), isEmpty);
    });

    test('addrs', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      expect(ab.addrs(pid), isEmpty);
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      expect(ab.addrs(pid), [_addr(4001)]);
    });

    test('peersWithAddrs', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      expect(ab.peersWithAddrs(), [pid]);
    });

    test('addrStream', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));

      final received = <Multiaddr>[];
      final sub = ab.addrStream(pid).listen(received.add);
      await Future<void>.delayed(Duration.zero);
      ab.addAddr(pid, _addr(4002), const Duration(minutes: 5));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, containsAll([_addr(4001), _addr(4002)]));
    });

    test('clearAddrs', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      ab.clearAddrs(pid);
      expect(ab.addrs(pid), isEmpty);
    });

    test('consumePeerRecord', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, priv) = await _freshPeer();
      final rec = PeerRecord(peerId: pid, addrs: [_addr(4001)], seq: 1);
      final envelope = await Envelope.seal(rec, priv);

      expect(ab.consumePeerRecord(envelope, const Duration(minutes: 5)), isTrue);
      expect(ab.addrs(pid), [_addr(4001)]);

      final stale = PeerRecord(peerId: pid, addrs: [_addr(4002)], seq: 0);
      final staleEnvelope = await Envelope.seal(stale, priv);
      expect(ab.consumePeerRecord(staleEnvelope, const Duration(minutes: 5)), isFalse);
    });

    test('getPeerRecord', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, priv) = await _freshPeer();
      expect(ab.getPeerRecord(pid), isNull);

      final rec = PeerRecord(peerId: pid, addrs: [_addr(4001)], seq: 1);
      final envelope = await Envelope.seal(rec, priv);
      ab.consumePeerRecord(envelope, const Duration(minutes: 5));

      final stored = ab.getPeerRecord(pid);
      expect(stored, isNotNull);
      expect(stored!.publicKey, equals(priv.getPublic()));
    });

    test('flush', () async {
      final ab = await DsAddrBook.open(MapDatastore(), defaultOpts());
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      await expectLater(ab.flush(), completes);
    });

    test('maxAddrsPerPeer evicts nearest expiry', () async {
      final opts = Options(maxAddrsPerPeer: 2);
      final ab = await DsAddrBook.open(MapDatastore(), opts);
      final (pid, _) = await _freshPeer();
      ab.addAddr(pid, _addr(1), const Duration(minutes: 1));
      ab.addAddr(pid, _addr(2), const Duration(minutes: 10));
      ab.addAddr(pid, _addr(3), const Duration(minutes: 5));
      // Cap is 2: the soonest-expiring (port 1, 1 minute) should be evicted.
      expect(ab.addrs(pid), hasLength(2));
      expect(ab.addrs(pid), isNot(contains(_addr(1))));
    });
  });

  group('Pstoreds', () {
    test('open', () async {
      final ps = await Pstoreds.open(MapDatastore());
      expect(ps.peers(), isEmpty);
    });

    test('addAddr', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      expect(ps.addrs(pid), [_addr(4001)]);
    });

    test('addAddrs', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddrs(pid, [_addr(4001), _addr(4002)], const Duration(minutes: 5));
      expect(ps.addrs(pid), hasLength(2));
    });

    test('setAddr', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.setAddr(pid, _addr(4001), const Duration(minutes: 5));
      expect(ps.addrs(pid), [_addr(4001)]);
    });

    test('setAddrs', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.setAddrs(pid, [_addr(4001)], const Duration(minutes: 5));
      expect(ps.addrs(pid), [_addr(4001)]);
    });

    test('updateAddrs', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      ps.updateAddrs(pid, const Duration(minutes: 5), const Duration(hours: 1));
      expect(ps.addrs(pid), [_addr(4001)]);
    });

    test('addrs', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(ps.addrs(pid), isEmpty);
    });

    test('addrStream', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      final first = await ps.addrStream(pid).first;
      expect(first, _addr(4001));
    });

    test('clearAddrs', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      ps.clearAddrs(pid);
      expect(ps.addrs(pid), isEmpty);
    });

    test('peersWithAddrs', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      expect(ps.peersWithAddrs(), [pid]);
    });

    test('consumePeerRecord', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, priv) = await _freshPeer();
      final rec = PeerRecord(peerId: pid, addrs: [_addr(4001)], seq: 1);
      final envelope = await Envelope.seal(rec, priv);
      expect(ps.consumePeerRecord(envelope, const Duration(minutes: 5)), isTrue);
    });

    test('getPeerRecord', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, priv) = await _freshPeer();
      final rec = PeerRecord(peerId: pid, addrs: [_addr(4001)], seq: 1);
      final envelope = await Envelope.seal(rec, priv);
      ps.consumePeerRecord(envelope, const Duration(minutes: 5));
      expect(ps.getPeerRecord(pid), isNotNull);
    });

    test('pubKey', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      expect(ps.pubKey(pid)!.keyEquals(kp.getPublic()), isTrue);
    });

    test('addPubKey', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      ps.addPubKey(pid, kp.getPublic());
      expect(ps.pubKey(pid)!.keyEquals(kp.getPublic()), isTrue);
    });

    test('privKey', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(ps.privKey(pid), isNull);
    });

    test('addPrivKey', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      ps.addPrivKey(pid, kp);
      expect(ps.privKey(pid)!.keyEquals(kp), isTrue);
    });

    test('peersWithKeys', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      ps.addPrivKey(pid, kp);
      expect(ps.peersWithKeys(), contains(pid));
    });

    test('getProtocols', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(ps.getProtocols(pid), isEmpty);
    });

    test('addProtocols', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addProtocols(pid, ['/a']);
      expect(ps.getProtocols(pid), ['/a']);
    });

    test('setProtocols', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.setProtocols(pid, ['/a', '/b']);
      expect(ps.getProtocols(pid), containsAll(['/a', '/b']));
    });

    test('removeProtocols', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.setProtocols(pid, ['/a', '/b']);
      ps.removeProtocols(pid, ['/a']);
      expect(ps.getProtocols(pid), ['/b']);
    });

    test('supportsProtocols', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.setProtocols(pid, ['/a']);
      expect(ps.supportsProtocols(pid, ['/a', '/z']), ['/a']);
    });

    test('firstSupportedProtocol', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.setProtocols(pid, ['/a']);
      expect(ps.firstSupportedProtocol(pid, ['/a']), '/a');
    });

    test('get', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(() => ps.get(pid, 'k'), throwsA(isA<ItemNotFoundException>()));
    });

    test('put', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.put(pid, 'k', 'v');
      expect(ps.get(pid, 'k'), 'v');
    });

    test('recordLatency', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.recordLatency(pid, const Duration(milliseconds: 50));
      expect(ps.latencyEwma(pid), const Duration(milliseconds: 50));
    });

    test('latencyEwma', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      expect(ps.latencyEwma(pid), Duration.zero);
      ps.recordLatency(pid, const Duration(milliseconds: 100));
      expect(ps.latencyEwma(pid), const Duration(milliseconds: 100));
      ps.recordLatency(pid, const Duration(milliseconds: 200));
      expect(ps.latencyEwma(pid) > const Duration(milliseconds: 100), isTrue);
    });

    test('removePeer', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, kp) = await _freshPeer();
      ps.addPrivKey(pid, kp);
      ps.setProtocols(pid, ['/a']);
      ps.removePeer(pid);
      expect(ps.peersWithKeys(), isNot(contains(pid)));
      expect(ps.getProtocols(pid), isEmpty);
    });

    test('peerInfo', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      final info = ps.peerInfo(pid);
      expect(info.id, pid);
      expect(info.addrs, [_addr(4001)]);
    });

    test('peers', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid1, kp1) = await _freshPeer();
      final (pid2, _) = await _freshPeer();
      ps.addPrivKey(pid1, kp1);
      ps.addAddr(pid2, _addr(4001), const Duration(minutes: 5));
      expect(ps.peers(), containsAll([pid1, pid2]));
    });

    test('close', () async {
      final ps = await Pstoreds.open(MapDatastore());
      final (pid, _) = await _freshPeer();
      ps.addAddr(pid, _addr(4001), const Duration(minutes: 5));
      await expectLater(ps.close(), completes);
    });

    test('restart preserves known peers', () async {
      final store = MapDatastore();
      final ps1 = await Pstoreds.open(store);

      final (pid1, kp1) = await _freshPeer();
      final (pid2, priv2) = await _freshPeer();

      ps1.addAddr(pid1, _addr(4001), const Duration(hours: 1));
      ps1.addAddr(pid1, _addr(4002), permanentAddrTtl);
      ps1.addPrivKey(pid1, kp1);
      ps1.setProtocols(pid1, ['/ipfs/id/1.0.0']);
      ps1.put(pid1, 'agent', 'dart-ipfs/1.0');

      final rec = PeerRecord(peerId: pid2, addrs: [_addr(5001)], seq: 1);
      final envelope = await Envelope.seal(rec, priv2);
      ps1.consumePeerRecord(envelope, const Duration(hours: 1));

      // "Restart": close (drains all pending writes) and re-open a brand
      // new Pstoreds instance against the SAME underlying datastore --
      // exactly what surviving a process restart onto persistent storage
      // means, and the acceptance criterion for this whole port.
      await ps1.close();
      final ps2 = await Pstoreds.open(store);

      expect(ps2.peers(), containsAll([pid1, pid2]));
      expect(ps2.addrs(pid1), containsAll([_addr(4001), _addr(4002)]));
      expect(ps2.privKey(pid1)!.keyEquals(kp1), isTrue);
      expect(ps2.getProtocols(pid1), ['/ipfs/id/1.0.0']);
      expect(ps2.get(pid1, 'agent'), 'dart-ipfs/1.0');
      expect(ps2.addrs(pid2), [_addr(5001)]);
      expect(ps2.getPeerRecord(pid2), isNotNull);
    });
  });
}
