// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity tests ported from boxo/bitswap/message/message_test.go.

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/src/bitswap/message/message.dart';
import 'package:transpiled_boxo/src/bitswap/message/pb/message.dart' as pb;
import 'package:transpiled_boxo/src/chunker.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

Cid mkFakeCid(String s) {
  final bytes = Uint8List.fromList(utf8.encode(s));
  return blocks.BasicBlock.fromData(bytes).cid();
}

bool wantlistContains(pb.Wantlist? wantlist, Cid c) {
  if (wantlist == null) return false;
  for (final e in wantlist.getEntries()) {
    try {
      final blkCid = Cid.fromBytes(e.block);
      if (blkCid == c) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

void main() {
  test('TestAppendWanted', () {
    final str = mkFakeCid('foo');
    final m = BitSwapMessage(true);
    m.addEntry(str, 1, pb.WantType.block, true);

    expect(wantlistContains(m.toProtoV0().wantlist, str), isTrue);
  });

  test('TestNewMessageFromProto', () {
    final str = mkFakeCid('a_key');

    final protoMessage = pb.Message(
      wantlist: pb.Wantlist(
        entries: [
          pb.Entry(block: str.toBytes()),
        ],
      ),
    );

    expect(wantlistContains(protoMessage.wantlist, str), isTrue);
    final m = BitSwapMessage.fromProto(protoMessage);
    expect(wantlistContains(m.toProtoV0().wantlist, str), isTrue);
  });

  test('TestAppendBlock', () {
    final strs = <String>['Celeritas', 'Incendia'];

    final m = BitSwapMessage(true);
    for (final str in strs) {
      final block = blocks.BasicBlock.fromData(
        Uint8List.fromList(utf8.encode(str)),
      );
      m.addBlock(block);
    }

    // assert strings are in proto message
    for (final blockBytes in m.toProtoV0().getBlocks()) {
      final s = utf8.decode(blockBytes);
      expect(strs.contains(s), isTrue);
    }
  });

  test('TestWantlist', () {
    final keystrs = [
      mkFakeCid('foo'),
      mkFakeCid('bar'),
      mkFakeCid('baz'),
      mkFakeCid('bat'),
    ];
    final m = BitSwapMessage(true);
    for (final s in keystrs) {
      m.addEntry(s, 1, pb.WantType.block, true);
    }
    final exported = m.wantlist();

    for (final k in exported) {
      var present = false;
      for (final s in keystrs) {
        if (s == k.cid) {
          present = true;
        }
      }
      expect(present, isTrue, reason: "${k.cid} isn't in original list");
    }
  });

  test('TestCopyProtoByValue', () {
    final str = mkFakeCid('foo');
    final m = BitSwapMessage(true);
    final protoBeforeAppend = m.toProtoV0();
    m.addEntry(str, 1, pb.WantType.block, true);
    expect(wantlistContains(protoBeforeAppend.wantlist, str), isFalse);
  });

  test('TestToNetFromNetPreservesWantList', () {
    final original = BitSwapMessage(true);
    original.addEntry(mkFakeCid('M'), 1, pb.WantType.block, true);
    original.addEntry(mkFakeCid('B'), 1, pb.WantType.block, true);
    original.addEntry(mkFakeCid('D'), 1, pb.WantType.block, true);
    original.addEntry(mkFakeCid('T'), 1, pb.WantType.block, true);
    original.addEntry(mkFakeCid('F'), 1, pb.WantType.block, true);

    final buf = Buffer();
    original.toNetV1(buf);

    final (copied, _) = fromNet(buf);

    expect(
      copied.full(),
      isTrue,
      reason: 'fullness attribute got dropped on marshal',
    );

    final keys = <Cid, bool>{};
    for (final k in copied.wantlist()) {
      keys[k.cid] = true;
    }

    for (final k in original.wantlist()) {
      expect(
        keys.containsKey(k.cid),
        isTrue,
        reason: 'Key Missing: "${k.cid}"',
      );
    }
  });

  test('TestToAndFromNetMessage', () {
    final original = BitSwapMessage(true);
    original.addBlock(
      blocks.BasicBlock.fromData(Uint8List.fromList(utf8.encode('W'))),
    );
    original.addBlock(
      blocks.BasicBlock.fromData(Uint8List.fromList(utf8.encode('E'))),
    );
    original.addBlock(
      blocks.BasicBlock.fromData(Uint8List.fromList(utf8.encode('F'))),
    );
    original.addBlock(
      blocks.BasicBlock.fromData(Uint8List.fromList(utf8.encode('M'))),
    );

    final buf = Buffer();
    original.toNetV1(buf);

    final (m2, _) = fromNet(buf);

    final keys = <Cid, bool>{};
    for (final b in m2.blocks()) {
      keys[b.cid()] = true;
    }

    for (final b in original.blocks()) {
      expect(keys.containsKey(b.cid()), isTrue);
    }
  });

  test('TestDuplicates', () {
    final b = blocks.BasicBlock.fromData(
      Uint8List.fromList(utf8.encode('foo')),
    );
    final msg = BitSwapMessage(true);

    msg.addEntry(b.cid(), 1, pb.WantType.block, true);
    msg.addEntry(b.cid(), 1, pb.WantType.block, true);
    expect(
      msg.wantlist().length,
      equals(1),
      reason: 'Duplicate in BitSwapMessage',
    );

    msg.addBlock(b);
    msg.addBlock(b);
    expect(
      msg.blocks().length,
      equals(1),
      reason: 'Duplicate in BitSwapMessage',
    );

    final b2 = blocks.BasicBlock.fromData(
      Uint8List.fromList(utf8.encode('bar')),
    );
    msg.addBlockPresence(b2.cid(), pb.BlockPresenceType.have);
    msg.addBlockPresence(b2.cid(), pb.BlockPresenceType.have);
    expect(
      msg.haves().length,
      equals(1),
      reason: 'Duplicate in BitSwapMessage',
    );
  });

  test('TestBlockPresences', () {
    final b1 = blocks.BasicBlock.fromData(
      Uint8List.fromList(utf8.encode('foo')),
    );
    final b2 = blocks.BasicBlock.fromData(
      Uint8List.fromList(utf8.encode('bar')),
    );
    final msg = BitSwapMessage(true);

    msg.addBlockPresence(b1.cid(), pb.BlockPresenceType.have);
    msg.addBlockPresence(b2.cid(), pb.BlockPresenceType.dontHave);
    expect(msg.haves().length, equals(1));
    expect(msg.haves()[0], equals(b1.cid()));
    expect(msg.dontHaves().length, equals(1));
    expect(msg.dontHaves()[0], equals(b2.cid()));

    msg.addBlock(b1);
    expect(
      msg.haves().length,
      equals(0),
      reason: 'Expected block to overwrite HAVE',
    );

    msg.addBlock(b2);
    expect(
      msg.dontHaves().length,
      equals(0),
      reason: 'Expected block to overwrite DONT_HAVE',
    );

    msg.addBlockPresence(b1.cid(), pb.BlockPresenceType.have);
    expect(
      msg.haves().length,
      equals(0),
      reason: 'Expected HAVE not to overwrite block',
    );

    msg.addBlockPresence(b2.cid(), pb.BlockPresenceType.dontHave);
    expect(
      msg.dontHaves().length,
      equals(0),
      reason: 'Expected DONT_HAVE not to overwrite block',
    );
  });

  test('TestAddWantlistEntry', () {
    final b = blocks.BasicBlock.fromData(
      Uint8List.fromList(utf8.encode('foo')),
    );
    final msg = BitSwapMessage(true);

    msg.addEntry(b.cid(), 1, pb.WantType.have, false);
    msg.addEntry(b.cid(), 2, pb.WantType.block, true);
    var entries = msg.wantlist();
    expect(entries.length, equals(1), reason: 'Duplicate in BitSwapMessage');
    var e = entries[0];
    expect(
      e.wantType,
      equals(pb.WantType.block),
      reason: 'want-block should override want-have',
    );
    expect(
      e.sendDontHave,
      isTrue,
      reason: 'true SendDontHave should override false SendDontHave',
    );
    expect(
      e.priority,
      equals(1),
      reason: 'priority should only be overridden if wants are of same type',
    );

    msg.addEntry(b.cid(), 2, pb.WantType.block, true);
    e = msg.wantlist()[0];
    expect(
      e.priority,
      equals(2),
      reason: 'priority should be overridden if wants are of same type',
    );

    msg.addEntry(b.cid(), 3, pb.WantType.have, false);
    e = msg.wantlist()[0];
    expect(
      e.wantType,
      equals(pb.WantType.block),
      reason: 'want-have should not override want-block',
    );
    expect(
      e.sendDontHave,
      isTrue,
      reason: 'false SendDontHave should not override true SendDontHave',
    );
    expect(
      e.priority,
      equals(2),
      reason: 'priority should only be overridden if wants are of same type',
    );

    msg.cancel(b.cid());
    e = msg.wantlist()[0];
    expect(e.cancel, isTrue, reason: 'cancel should override want');

    msg.addEntry(b.cid(), 10, pb.WantType.block, true);
    e = msg.wantlist()[0];
    expect(e.cancel, isTrue, reason: 'want should not override cancel');
  });

  test('TestEntrySize', () {
    final c = mkFakeCid('random_entry_cid');
    final e = Entry(
      cid: c,
      priority: 10,
      wantType: pb.WantType.have,
      sendDontHave: true,
      cancel: false,
    );
    final epb = e.toPb();
    expect(
      e.size(),
      equals(epb.size()),
      reason: 'entry size calculation incorrect',
    );
  });

  test('TestBlockSizeLimitFitsInLibp2pMessage', () {
    // create a CIDv1 + raw + SHA2-256 block at exactly BlockSizeLimit
    final data = Uint8List(blockSizeLimit);
    final prefix = Prefix(
      version: 1,
      codec: 'raw',
      mhType: 'sha2-256',
      mhLength: -1,
    );
    final c = prefix.sum(data);
    final blk = blocks.BasicBlock.withCid(data, c);

    // build a bitswap message with the block
    final msg = BitSwapMessage(true);
    msg.addBlock(blk);

    // serialize and check size fits in libp2p message limit
    final buf = Buffer();
    msg.toNetV1(buf);

    final wireSize = buf.length;
    expect(
      wireSize,
      lessThanOrEqualTo(messageSizeMax),
      reason:
          'serialized message ($wireSize bytes) exceeds network.MessageSizeMax ($messageSizeMax bytes)',
    );

    // round-trip: verify FromNet can read it back (uses MessageSizeMax as reader limit)
    final (m2, _) = fromNet(ByteReader(buf.bytes()));
    final received = m2.blocks();
    expect(received.length, equals(1));
    expect(received[0].rawData().length, equals(blockSizeLimit));
  });

  test('TestEmptyMessageBoxoVector', () {
    final m0 = BitSwapMessage(false);
    final buf0 = Buffer();
    m0.toNetV0(buf0);
    // Boxo empty frame: varint length prefix 2 followed by [0x0a, 0x00]
    expect(buf0.bytes(), equals(Uint8List.fromList([0x02, 0x0a, 0x00])));

    final mFull = BitSwapMessage(true);
    final bufFull = Buffer();
    mFull.toNetV0(bufFull);
    // Full wantlist empty entries: varint length prefix 4 followed by [0x0a, 0x02, 0x10, 0x01]
    expect(
      bufFull.bytes(),
      equals(Uint8List.fromList([0x04, 0x0a, 0x02, 0x10, 0x01])),
    );
  });

  test('TestCloneAndReset', () {
    final m = BitSwapMessage(true);
    final c = mkFakeCid('test_clone');
    m.addEntry(c, 5, pb.WantType.block, true);
    final b = blocks.BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));
    m.addBlock(b);
    m.setPendingBytes(100);

    final cl = m.clone();
    expect(cl.full(), isTrue);
    expect(cl.wantlist().length, equals(1));
    expect(cl.blocks().length, equals(1));
    expect(cl.pendingBytes(), equals(100));

    m.reset(false);
    expect(m.full(), isFalse);
    expect(m.empty(), isTrue);
    expect(m.pendingBytes(), equals(0));

    // Clone should remain intact
    expect(cl.wantlist().length, equals(1));
    expect(cl.blocks().length, equals(1));
    expect(cl.pendingBytes(), equals(100));
  });

  test('TestBlockPresenceSize', () {
    final c = mkFakeCid('test_presence_size');
    expect(
      blockPresenceSize(c),
      equals(
        pb.BlockPresence(
          cid: c.toBytes(),
          type: pb.BlockPresenceType.have,
        ).size(),
      ),
    );
  });

  test('TestNewWantlistBlock', () {
    final data = Uint8List.fromList([10, 20, 30]);
    final prefix = Prefix(
      version: 1,
      codec: 'raw',
      mhType: 'sha2-256',
      mhLength: -1,
    );
    final expectedCid = prefix.sum(data);

    final blk = wantlistBlock(data, null, prefix);
    expect(blk.cid(), equals(expectedCid));
    expect(blk.rawData(), equals(data));

    // Calling with matching Cid succeeds
    final blk2 = wantlistBlock(data, expectedCid, prefix);
    expect(blk2.cid(), equals(expectedCid));

    // Calling with mismatching Cid throws ErrWrongHash
    final wrongCid = mkFakeCid('different');
    expect(
      () => wantlistBlock(data, wrongCid, prefix),
      throwsA(isA<blocks.WrongHashException>()),
    );
  });

  test('TestNewMessageFromProtoValidation', () {
    // Missing CID in wantlist entry throws
    final badWl = pb.Message(
      wantlist: pb.Wantlist(
        entries: [pb.Entry(block: Uint8List(0))],
      ),
    );
    expect(() => BitSwapMessage.fromProto(badWl), throwsFormatException);

    // Missing CID in block presence throws
    final badBp = pb.Message(
      blockPresences: [pb.BlockPresence(cid: Uint8List(0))],
    );
    expect(() => BitSwapMessage.fromProto(badBp), throwsFormatException);
  });
}
