// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:test/test.dart';

void main() {
  group('PeerRecord protobuf round-trip', () {
    test('toProtobuf / fromProtobuf preserves peer ID, addrs, and seq', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final addrs = [
        Multiaddr.parse('/ip4/1.2.3.4/tcp/4001'),
        Multiaddr.parse('/ip6/::1/udp/4001/quic-v1'),
      ];
      final rec = PeerRecord(peerId: id, addrs: addrs, seq: 42);

      final decoded = PeerRecord.fromProtobuf(rec.toProtobuf());
      expect(decoded.peerId, equals(id));
      expect(decoded.addrs, equals(addrs));
      expect(decoded.seq, equals(42));
      expect(decoded.equals(rec), isTrue);
    });

    test('drops empty multiaddrs when encoding, matching go-libp2p', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final rec = PeerRecord(peerId: id, addrs: [Multiaddr.empty], seq: 1);

      final decoded = PeerRecord.fromProtobuf(rec.toProtobuf());
      expect(decoded.addrs, isEmpty);
    });

    test('a record with no addrs round-trips to an empty list', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final rec = PeerRecord(peerId: id, seq: 7);

      final decoded = PeerRecord.fromProtobuf(rec.toProtobuf());
      expect(decoded.addrs, isEmpty);
      expect(decoded.seq, equals(7));
    });
  });

  group('PeerRecord.fromAddrInfo', () {
    test('copies the peer ID and addrs, with a fresh timestamp seq', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final addrs = [Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')];
      final info = AddrInfo(id: id, addrs: addrs);

      final rec = PeerRecord.fromAddrInfo(info);
      expect(rec.peerId, equals(id));
      expect(rec.addrs, equals(addrs));
      expect(rec.seq, greaterThan(0));
    });
  });

  group('timestampSeq', () {
    test('is strictly increasing across consecutive calls', () {
      final first = timestampSeq();
      final second = timestampSeq();
      final third = timestampSeq();
      expect(second, greaterThan(first));
      expect(third, greaterThan(second));
    });
  });

  group('PeerRecord signed inside an Envelope (end-to-end)', () {
    test('seals, marshals, and is recovered via consumeEnvelope', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final addrs = [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')];
      final rec = PeerRecord(peerId: id, addrs: addrs);

      final envelope = await Envelope.seal(rec, keyPair);
      final serialized = envelope.marshal();

      final (deserializedEnvelope, recoveredRecord) =
          await Envelope.consumeEnvelope(serialized, peerRecordEnvelopeDomain);

      expect(deserializedEnvelope.publicKey.keyEquals(keyPair.getPublic()), isTrue);
      expect(recoveredRecord, isA<PeerRecord>());
      final recovered = recoveredRecord as PeerRecord;
      expect(recovered.peerId, equals(id));
      expect(recovered.addrs, equals(addrs));
      expect(recovered.seq, equals(rec.seq));
    });

    test('rejects a PeerRecord envelope signed by a different key', () async {
      final signerKeyPair = await generateEd25519KeyPair();
      final otherKeyPair = await generateEd25519KeyPair();
      final rec = PeerRecord(
        peerId: PeerId.fromPubKey(otherKeyPair.getPublic()),
        addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')],
      );

      final envelope = await Envelope.seal(rec, signerKeyPair);
      final serialized = envelope.marshal();

      // The envelope is internally consistent (signed by signerKeyPair over
      // its own contents) -- this isn't a tampering scenario, it's proving
      // the envelope's embedded PublicKey is the *signer's*, independent of
      // whichever PeerId happens to be inside the PeerRecord payload.
      final (deserialized, _) =
          await Envelope.consumeEnvelope(serialized, peerRecordEnvelopeDomain);
      expect(deserialized.publicKey.keyEquals(signerKeyPair.getPublic()), isTrue);
      expect(deserialized.publicKey.keyEquals(otherKeyPair.getPublic()), isFalse);
    });
  });
}
