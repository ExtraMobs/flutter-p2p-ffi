import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_boxo/src/blockstore.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/blockpresencemanager/blockpresencemanager.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/getter/getter.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/notifications/notifications.dart';
import 'package:transpiled_boxo/src/bitswap/client/wantlist/wantlist.dart'
    as wl;
import 'package:transpiled_boxo/src/bitswap/message/message.dart' as msg;
import 'package:transpiled_boxo/src/bitswap/message/pb/message.dart' as pb;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

// Traced through go-ipfs-reference/boxo-index/{blockstore,bitswap_message,
// bitswap_client_wantlist,bitswap_client_internal_blockpresencemanager,
// bitswap_client_internal_notifications,bitswap_client_internal_getter}.md
// and the corresponding Go declarations at boxo 25b1db8931508bb069eb6e67243b34d353cbe845.
// Message decoding delegates to go-cid Prefix.Sum and go-block-format;
// Blockstore delegates to go-datastore; getter delegates to notifications.
// These tests use the corresponding Dart ports with memory-only dependencies.
BasicBlock _block(String data) =>
    BasicBlock.fromData(Uint8List.fromList(data.codeUnits));
PeerId _peer(int n) =>
    PeerId.fromBytes(Uint8List.fromList([0x12, 0x20, ...List.filled(32, n)]));

void main() {
  final a = _block('atomic a');
  final b = _block('atomic b');
  final c = a.cid();
  final d = b.cid();
  final p = _peer(1);
  final q = _peer(2);

  // bitswap/message/pb/message.proto and message.pb.go, resolved via
  // bitswap_message_pb.md; codec delegates to transpiled_protobuf/protowire.
  group('Entry [Atomic Audit protobuf]', () {
    final entry = pb.Entry(
      block: Uint8List.fromList([1]),
      priority: 2,
      cancel: true,
      wantType: pb.WantType.have,
      sendDontHave: true,
    );
    test('getBlock() - stored bytes', () {
      expect(entry.getBlock(), [1]);
    });
    test('getPriority() - stored priority', () {
      expect(entry.getPriority(), 2);
    });
    test('getCancel() - stored cancel flag', () {
      expect(entry.getCancel(), isTrue);
    });
    test('getWantType() - stored request kind', () {
      expect(entry.getWantType(), pb.WantType.have);
    });
    test('getSendDontHave() - stored response flag', () {
      expect(entry.getSendDontHave(), isTrue);
    });
    test('size() - exact wire length', () {
      expect(entry.size(), 11);
    });
    test('encode() - known protobuf vector', () {
      expect(entry.encode(), [10, 1, 1, 16, 2, 24, 1, 32, 1, 40, 1]);
    });
    test('decode() - known protobuf vector and negative int32', () {
      final decoded = pb.Entry.decode(
        Uint8List.fromList([10, 1, 1, 16, 2, 24, 1, 32, 1, 40, 1]),
      );
      expect(decoded.block, [1]);
      expect(decoded.priority, 2);
      expect(decoded.cancel, isTrue);
      expect(decoded.wantType, pb.WantType.have);
      expect(decoded.sendDontHave, isTrue);
      final negative = pb.Entry.decode(
        Uint8List.fromList([
          16,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          1,
        ]),
      );
      expect(negative.priority, -1);
      expect(
        () => pb.Entry.decode(Uint8List.fromList([10, 2, 1])),
        throwsA(isA<Exception>()),
      );
    });
  });
  group('Wantlist [Atomic Audit protobuf]', () {
    final wants = pb.Wantlist(entries: [pb.Entry(priority: 2)], full: true);
    test('getEntries() - repeated entries', () {
      expect(wants.getEntries().single.priority, 2);
    });
    test('getFull() - full flag', () {
      expect(wants.getFull(), isTrue);
    });
    test('size() - known encoded length', () {
      expect(wants.size(), 6);
    });
    test('encode() - embedded entry wire vector', () {
      expect(wants.encode(), [10, 2, 16, 2, 16, 1]);
    });
    test('decode() - repeated embedded entries', () {
      final decoded = pb.Wantlist.decode(
        Uint8List.fromList([10, 2, 16, 2, 10, 2, 16, 3, 16, 1]),
      );
      expect(decoded.entries.map((e) => e.priority), [2, 3]);
      expect(decoded.full, isTrue);
    });
  });
  group('Block [Atomic Audit protobuf]', () {
    final block = pb.Block(
      prefix: Uint8List.fromList([1]),
      data: Uint8List.fromList([2, 3]),
    );
    test('getPrefix() - CID prefix bytes', () {
      expect(block.getPrefix(), [1]);
    });
    test('getData() - payload bytes', () {
      expect(block.getData(), [2, 3]);
    });
    test('size() - known encoded length', () {
      expect(block.size(), 7);
    });
    test('encode() - length-delimited wire vector', () {
      expect(block.encode(), [10, 1, 1, 18, 2, 2, 3]);
    });
    test('decode() - skips unknown fields and validates wire type', () {
      final decoded = pb.Block.decode(
        Uint8List.fromList([10, 1, 1, 18, 2, 2, 3, 24, 4]),
      );
      expect(decoded.prefix, [1]);
      expect(decoded.data, [2, 3]);
      expect(
        () => pb.Block.decode(Uint8List.fromList([8, 1])),
        throwsFormatException,
      );
    });
  });
  group('BlockPresence [Atomic Audit protobuf]', () {
    final presence = pb.BlockPresence(
      cid: Uint8List.fromList([1]),
      type: pb.BlockPresenceType.dontHave,
    );
    test('getCid() - CID bytes', () {
      expect(presence.getCid(), [1]);
    });
    test('getType() - response kind', () {
      expect(presence.getType(), pb.BlockPresenceType.dontHave);
    });
    test('size() - known encoded length', () {
      expect(presence.size(), 5);
    });
    test('encode() - presence wire vector', () {
      expect(presence.encode(), [10, 1, 1, 16, 1]);
    });
    test('decode() - presence wire vector', () {
      final decoded = pb.BlockPresence.decode(
        Uint8List.fromList([10, 1, 1, 16, 1]),
      );
      expect(decoded.cid, [1]);
      expect(decoded.type, pb.BlockPresenceType.dontHave);
      expect(
        pb.BlockPresence.decode(Uint8List(0)).type,
        pb.BlockPresenceType.have,
      );
    });
  });
  group('Message [Atomic Audit protobuf]', () {
    final message = pb.Message(
      wantlist: pb.Wantlist(full: true),
      blocks: [
        Uint8List.fromList([1]),
      ],
      payload: [
        pb.Block(data: Uint8List.fromList([2])),
      ],
      blockPresences: [pb.BlockPresence(type: pb.BlockPresenceType.dontHave)],
      pendingBytes: 3,
    );
    test('getWantlist() - optional wantlist', () {
      expect(message.getWantlist()!.full, isTrue);
      expect(pb.Message().getWantlist(), isNull);
    });
    test('getBlocks() - legacy raw blocks', () {
      expect(message.getBlocks(), [
        [1],
      ]);
    });
    test('getPayload() - prefixed payload blocks', () {
      expect(message.getPayload().single.data, [2]);
    });
    test('getBlockPresences() - presence entries', () {
      expect(
        message.getBlockPresences().single.type,
        pb.BlockPresenceType.dontHave,
      );
    });
    test('getPendingBytes() - byte count', () {
      expect(message.getPendingBytes(), 3);
    });
    test('size() - known complete message length', () {
      expect(message.size(), 18);
    });
    test('encode() - complete wire vector', () {
      expect(message.encode(), [
        10,
        2,
        16,
        1,
        18,
        1,
        1,
        26,
        3,
        18,
        1,
        2,
        34,
        2,
        16,
        1,
        40,
        3,
      ]);
    });
    test('decode() - complete wire vector', () {
      final decoded = pb.Message.decode(
        Uint8List.fromList([
          10,
          2,
          16,
          1,
          18,
          1,
          1,
          26,
          3,
          18,
          1,
          2,
          34,
          2,
          16,
          1,
          40,
          3,
        ]),
      );
      expect(decoded.wantlist!.full, isTrue);
      expect(decoded.blocks, [
        [1],
      ]);
      expect(decoded.payload.single.data, [2]);
      expect(decoded.blockPresences.single.type, pb.BlockPresenceType.dontHave);
      expect(decoded.pendingBytes, 3);
    });
  });
  test('WantType.code - protobuf enum values', () {
    expect(pb.WantType.block.code, 0);
    expect(pb.WantType.have.code, 1);
  });
  test('WantType.fromValue() - declared protobuf values', () {
    expect(pb.WantType.fromValue(0), pb.WantType.block);
    expect(pb.WantType.fromValue(1), pb.WantType.have);
  });
  test('BlockPresenceType.code - protobuf enum values', () {
    expect(pb.BlockPresenceType.have.code, 0);
    expect(pb.BlockPresenceType.dontHave.code, 1);
  });
  test('BlockPresenceType.fromValue() - declared protobuf values', () {
    expect(pb.BlockPresenceType.fromValue(0), pb.BlockPresenceType.have);
    expect(pb.BlockPresenceType.fromValue(1), pb.BlockPresenceType.dontHave);
  });

  group('ByteReader [Atomic Audit]', () {
    test('read() - partial reads and EOF preserve unused bytes', () {
      final reader = msg.ByteReader(Uint8List.fromList([1, 2, 3]));
      final out = [9, 9];
      expect(reader.read(out), 2);
      expect(out, [1, 2]);
      expect(reader.read(out), 1);
      expect(out, [3, 2]);
      expect(reader.read(out), 0);
    });
  });
  group('Buffer [Atomic Audit]', () {
    test('read() - advances unread offset', () {
      final buffer = msg.Buffer([1, 2]);
      final out = [0];
      expect(buffer.read(out), 1);
      expect(out, [1]);
      expect(buffer.toBytes(), [2]);
    });
    test('write() - appends after partially consumed content', () {
      final buffer = msg.Buffer([1, 2]);
      buffer.read([0]);
      buffer.write([3]);
      expect(buffer.toBytes(), [2, 3]);
    });
    test('length - counts unread bytes only', () {
      final buffer = msg.Buffer([1, 2]);
      expect(buffer.length, 2);
      buffer.read([0]);
      expect(buffer.length, 1);
    });
    test('toBytes() - returns an independent unread copy', () {
      final buffer = msg.Buffer([1, 2]);
      buffer.toBytes()[0] = 99;
      expect(buffer.toBytes(), [1, 2]);
    });
    test('bytes() - follows unread offset', () {
      final buffer = msg.Buffer([1, 2]);
      buffer.read([0]);
      expect(buffer.bytes(), [2]);
    });
  });
  test('Reader.read() - interface consumes memory reader', () {
    final msg.Reader reader = msg.ByteReader(Uint8List.fromList([3]));
    final out = [0, 0];
    expect(reader.read(out), 1);
    expect(out, [3, 0]);
  });
  test('Writer.write() - interface writes bytes to buffer', () {
    final buffer = msg.Buffer();
    final msg.Writer writer = buffer;
    writer.write([4, 5]);
    expect(buffer.bytes(), [4, 5]);
  });
  group('VarintReader [Atomic Audit]', () {
    test('readMsg() - consecutive and empty frames', () {
      final reader = msg.VarintReader(msg.Buffer([2, 7, 8, 0]));
      expect(reader.readMsg(), [7, 8]);
      expect(reader.readMsg(), isEmpty);
      expect(reader.readMsg, throwsFormatException);
    });
    test('readMsg() - rejects oversized and truncated frames', () {
      expect(
        msg.VarintReader(msg.Buffer([3, 1, 2, 3]), 2).readMsg,
        throwsFormatException,
      );
      expect(
        msg.VarintReader(msg.Buffer([2, 1])).readMsg,
        throwsFormatException,
      );
    });
    test('releaseMsg() - no-op does not alter payload or next frame', () {
      final reader = msg.VarintReader(msg.Buffer([1, 7, 1, 8]));
      final payload = reader.readMsg();
      reader.releaseMsg(payload);
      expect(payload, [7]);
      expect(reader.readMsg(), [8]);
    });
  });
  test('MsgReader.readMsg() - interface returns framed payload', () {
    final msg.MsgReader reader = msg.VarintReader(msg.Buffer([1, 7]));
    expect(reader.readMsg(), [7]);
  });
  test('MsgReader.releaseMsg() - interface release preserves read cursor', () {
    final msg.MsgReader reader = msg.VarintReader(msg.Buffer([1, 7, 0]));
    reader.releaseMsg(reader.readMsg());
    expect(reader.readMsg(), isEmpty);
  });
  group('Entry [Atomic Audit]', () {
    late msg.Entry entry;
    setUp(
      () => entry = msg.Entry(
        cid: c,
        priority: -1,
        wantType: pb.WantType.have,
        sendDontHave: true,
      ),
    );
    test('entry - exposes canonical wantlist fields', () {
      expect(entry.entry.cid, c);
      expect(entry.entry.priority, -1);
      expect(entry.entry.wantType, pb.WantType.have);
    });
    test('size() - agrees with encoded protobuf length', () {
      expect(entry.size(), entry.toPb().encode().length);
    });
    test('toPb() - retains all flags and CID bytes', () {
      entry.cancel = true;
      final proto = entry.toPb();
      expect(proto.block, c.toBytes());
      expect(proto.priority, -1);
      expect(proto.cancel, isTrue);
      expect(proto.sendDontHave, isTrue);
      expect(proto.wantType, pb.WantType.have);
    });
    test('clone() - independent mutable fields', () {
      final clone = entry.clone();
      clone.priority = 5;
      expect(entry.priority, -1);
      expect(clone.cid, c);
    });
    test('operator == - compares all fields', () {
      expect(entry == entry.clone(), isTrue);
      final other = entry.clone()..cancel = true;
      expect(entry == other, isFalse);
    });
    test('hashCode - equal entries have equal hashes', () {
      expect(entry.hashCode, entry.clone().hashCode);
    });
    test('toString() - carries CID and flags', () {
      expect(entry.toString(), contains(c.toString()));
      expect(entry.toString(), contains('sendDontHave: true'));
    });
  });
  group('BlockPresence [Atomic Audit]', () {
    test('operator == - CID and type determine equality', () {
      expect(
        msg.BlockPresence(c, pb.BlockPresenceType.have),
        msg.BlockPresence(c, pb.BlockPresenceType.have),
      );
      expect(
        msg.BlockPresence(c, pb.BlockPresenceType.have),
        isNot(msg.BlockPresence(c, pb.BlockPresenceType.dontHave)),
      );
    });
    test('hashCode - equality-compatible hashing', () {
      expect(
        msg.BlockPresence(c, pb.BlockPresenceType.have).hashCode,
        msg.BlockPresence(c, pb.BlockPresenceType.have).hashCode,
      );
    });
    test('toString() - identifies block', () {
      expect(
        msg.BlockPresence(c, pb.BlockPresenceType.have).toString(),
        contains(c.toString()),
      );
    });
  });
  test('blockPresenceSize() - serialized presence length', () {
    expect(
      msg.blockPresenceSize(c),
      pb.BlockPresence(
        cid: c.toBytes(),
        type: pb.BlockPresenceType.have,
      ).encode().length,
    );
  });
  test('wantlistBlock() - validates expected content hash', () {
    expect(msg.wantlistBlock(a.rawData(), c).cid(), c);
    expect(
      () => msg.wantlistBlock(b.rawData(), c),
      throwsA(isA<WrongHashException>()),
    );
    expect(() => msg.wantlistBlock(a.rawData()), throwsArgumentError);
  });
  test('fromNet() - decodes byte list framing', () {
    final message = msg.Impl()..addHave(c);
    final buffer = msg.Buffer();
    message.toNetV1(buffer);
    expect(msg.fromNet(buffer.bytes()).$1.haves(), [c]);
    expect(() => msg.fromNet(Object()), throwsArgumentError);
  });
  test('fromMsgReader() - returns protobuf payload byte count', () {
    final message = msg.Impl()..addHave(c);
    final buffer = msg.Buffer();
    message.toNetV1(buffer);
    final (decoded, size) = msg.fromMsgReader(msg.VarintReader(buffer));
    expect(decoded.haves(), [c]);
    expect(size, message.toProtoV1().encode().length);
  });
  test('BitSwapMessage.fromBytes() - decodes protobuf message', () {
    final message = msg.Impl()..addBlock(a);
    final decoded = msg.BitSwapMessage.fromBytes(message.toProtoV1().encode());
    expect(decoded.blocks().single.cid(), c);
    expect(decoded.blocks().single.rawData(), a.rawData());
  });

  group('Blockstore [Atomic Audit]', () {
    late Blockstore store;
    setUp(() => store = Blockstore(MapDatastore()));
    test('has() - absence and insertion', () async {
      expect(await store.has(c), isFalse);
      await store.put(a);
      expect(await store.has(c), isTrue);
    });
    test('put() - CID versions share the multihash key', () async {
      await store.put(a);
      final v1 = Cid.v1('raw', c.multihash);
      expect((await store.get(v1)).rawData(), a.rawData());
    });
    test('get() - returns bytes and requested CID', () async {
      await store.put(a);
      final result = await store.get(c);
      expect(result.cid(), c);
      expect(result.rawData(), a.rawData());
    });
    test('get() - maps missing datastore entry', () async {
      await expectLater(
        store.get(c),
        throwsA(
          isA<BlockstoreNotFoundException>().having((e) => e.cid, 'cid', c),
        ),
      );
    });
    test('getSize() - size and missing error', () async {
      await store.put(a);
      expect(await store.getSize(c), a.rawData().length);
      await expectLater(
        store.getSize(d),
        throwsA(isA<BlockstoreNotFoundException>()),
      );
    });
    test('putMany() - empty single and batch writes', () async {
      await store.putMany([]);
      await store.putMany([a]);
      await store.putMany([a, b]);
      expect((await store.get(c)).rawData(), a.rawData());
      expect((await store.get(d)).rawData(), b.rawData());
    });
  });
  test('BlockstoreNotFoundException.toString() - includes requested CID', () {
    expect(
      BlockstoreNotFoundException(c).toString(),
      'blockstore: block not found: $c',
    );
  });

  group('Wantlist [Atomic Audit]', () {
    late wl.Wantlist wants;
    setUp(() => wants = wl.Wantlist());
    test('length - counts unique CIDs', () {
      wants.add(c, 1, pb.WantType.have);
      wants.add(c, 2, pb.WantType.block);
      expect(wants.length, 1);
    });
    test('add() - HAVE upgrades to BLOCK but never downgrades', () {
      expect(wants.add(c, 1, pb.WantType.have), isTrue);
      expect(wants.add(c, 2, pb.WantType.block), isTrue);
      expect(wants.add(c, 3, pb.WantType.have), isFalse);
      expect(wants.get(c)!.priority, 2);
    });
    test('remove() - absent removal is harmless and invalidates entries', () {
      wants.add(c, 1, pb.WantType.block);
      wants.entries();
      wants.remove(c);
      wants.remove(c);
      expect(wants.entries(), isEmpty);
    });
    test('removeType() - HAVE cannot remove BLOCK', () {
      wants.add(c, 1, pb.WantType.block);
      expect(wants.removeType(c, pb.WantType.have), isFalse);
      expect(wants.removeType(c, pb.WantType.block), isTrue);
      expect(wants.removeType(c, pb.WantType.block), isFalse);
    });
    test('has() - tracks membership', () {
      expect(wants.has(c), isFalse);
      wants.add(c, 1, pb.WantType.have);
      expect(wants.has(c), isTrue);
    });
    test('get() - absent and stored entries', () {
      expect(wants.get(c), isNull);
      wants.add(c, -4, pb.WantType.have);
      expect(wants.get(c)!.cid, c);
      expect(wants.get(c)!.priority, -4);
    });
    test('entries() - descending priority and cache invalidation', () {
      wants.add(c, -4, pb.WantType.have);
      final previous = wants.entries();
      wants.add(d, 3, pb.WantType.block);
      expect(wants.entries().map((e) => e.cid), [d, c]);
      expect(previous.map((e) => e.cid), [c]);
      expect(() => wants.entries().clear(), throwsUnsupportedError);
    });
  });

  group('BlockPresenceManager [Atomic Audit]', () {
    late BlockPresenceManager manager;
    setUp(() => manager = BlockPresenceManager());
    test('receiveFrom() - HAVE remains authoritative', () {
      manager.receiveFrom(p, [c], [c, d]);
      manager.receiveFrom(p, [], [c]);
      expect(manager.peerHasBlock(p, c), isTrue);
      expect(manager.peerDoesNotHaveBlock(p, d), isTrue);
    });
    test('peerHasBlock() - unknown is false and HAVE is true', () {
      expect(manager.peerHasBlock(p, c), isFalse);
      manager.receiveFrom(p, [c], []);
      expect(manager.peerHasBlock(p, c), isTrue);
      expect(manager.peerHasBlock(q, c), isFalse);
    });
    test('peerDoesNotHaveBlock() - unknown differs from DONT_HAVE', () {
      expect(manager.peerDoesNotHaveBlock(p, c), isFalse);
      manager.receiveFrom(p, [], [c]);
      expect(manager.peerDoesNotHaveBlock(p, c), isTrue);
      manager.receiveFrom(p, [c], []);
      expect(manager.peerDoesNotHaveBlock(p, c), isFalse);
    });
    test('allPeersDoNotHaveBlock() - requires every peer to answer', () {
      manager.receiveFrom(p, [], [c, d]);
      expect(manager.allPeersDoNotHaveBlock([p, q], [c, d]), isEmpty);
      manager.receiveFrom(q, [d], [c]);
      expect(manager.allPeersDoNotHaveBlock([p, q], [c, d]), [c]);
    });
    test('removeKeys() - selective removal', () {
      manager.receiveFrom(p, [c, d], []);
      manager.removeKeys([c]);
      manager.removeKeys([]);
      expect(manager.hasKey(c), isFalse);
      expect(manager.hasKey(d), isTrue);
    });
    test('removePeer() - keeps other peers and removes empty keys', () {
      manager.receiveFrom(p, [c, d], []);
      manager.receiveFrom(q, [d], []);
      manager.removePeer(p);
      expect(manager.hasKey(c), isFalse);
      expect(manager.peerHasBlock(q, d), isTrue);
      expect(manager.peerHasBlock(p, d), isFalse);
    });
    test('hasKey() - DONT_HAVE is still tracked', () {
      expect(manager.hasKey(c), isFalse);
      manager.receiveFrom(p, [], [c]);
      expect(manager.hasKey(c), isTrue);
    });
  });

  group('NotificationsPubSub [Atomic Audit]', () {
    late NotificationsPubSub notifications;
    setUp(() => notifications = NotificationsPubSub());
    tearDown(() => notifications.shutdown());
    test('publish() - routes matching blocks only', () async {
      final result = notifications.subscribe([c]).toList();
      notifications.publish(p, [b, a]);
      expect(await result, [a]);
    });
    test(
      'subscribe() - deduplicates and completes after requested blocks',
      () async {
        final result = notifications.subscribe([c, c, d]).toList();
        notifications.publish(p, [a, a, b]);
        expect(await result, [a, b]);
        expect(await notifications.subscribe([]).toList(), isEmpty);
      },
    );
    test('shutdown() - closes outstanding and future subscriptions', () async {
      final pending = notifications.subscribe([c]).toList();
      notifications.shutdown();
      notifications.shutdown();
      expect(await pending, isEmpty);
      expect(await notifications.subscribe([c]).toList(), isEmpty);
    });
  });
  test(
    'syncGetBlock() - delegates requested CID and returns first block',
    () async {
      final result = await syncGetBlock(c, (keys) async {
        expect(keys, [c]);
        return Stream.fromIterable([a, b]);
      });
      expect(result, a);
    },
  );
  test('syncGetBlock() - propagates provider errors', () async {
    final failure = StateError('provider failed');
    await expectLater(
      syncGetBlock(c, (_) async => throw failure),
      throwsA(same(failure)),
    );
  });
  test('syncGetBlock() - closed promise fails', () async {
    await expectLater(
      syncGetBlock(c, (_) async => const Stream.empty()),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('promise channel was closed'),
        ),
      ),
    );
  });
  test('asyncGetBlocks() - subscribes before expressing wants', () async {
    final notifications = NotificationsPubSub();
    addTearDown(notifications.shutdown);
    final cancelled = <Cid>[];
    final stream = await asyncGetBlocks([c], notifications, (keys) {
      expect(keys, [c]);
      notifications.publish(p, [a]);
    }, cancelled.addAll);
    expect(await stream.toList(), [a]);
    expect(cancelled, isEmpty);
  });
  test('asyncGetBlocks() - empty request has no wants', () async {
    final notifications = NotificationsPubSub();
    addTearDown(notifications.shutdown);
    var called = false;
    final stream = await asyncGetBlocks(
      [],
      notifications,
      (_) => called = true,
      (_) => called = true,
    );
    expect(await stream.toList(), isEmpty);
    expect(called, isFalse);
  });

  group('Impl [Atomic Audit]', () {
    late msg.Impl message;
    setUp(() => message = msg.Impl());
    test('full() - default and reset flag', () {
      expect(message.full(), isFalse);
      message.reset(true);
      expect(message.full(), isTrue);
    });
    test('empty() - pending bytes alone are not content', () {
      message.setPendingBytes(9);
      expect(message.empty(), isTrue);
      message.addHave(c);
      expect(message.empty(), isFalse);
    });
    test('addEntry() - merges without duplicate wire entries', () {
      expect(message.addEntry(c, 7, pb.WantType.have, false), greaterThan(0));
      expect(message.addEntry(c, 9, pb.WantType.block, true), 0);
      expect(message.wantlist().single.wantType, pb.WantType.block);
      expect(message.wantlist().single.sendDontHave, isTrue);
      expect(message.wantlist().single.priority, 7);
    });
    test('addEntryRaw() - decoding preserves cancel flags', () {
      message.addEntryRaw(c, 4, true, pb.WantType.have, true);
      expect(message.wantlist().single.cancel, isTrue);
      expect(message.wantlist().single.priority, 4);
    });
    test('wantlist() - returned entries are copies', () {
      message.addEntry(c, 7, pb.WantType.block, false);
      message.wantlist().single.priority = 999;
      expect(message.wantlist().single.priority, 7);
    });
    test('fillWantlist() - replaces reused output and copies entries', () {
      message.addEntry(c, 7, pb.WantType.block, false);
      final output = <msg.Entry>[
        msg.Entry(cid: d, priority: 0, wantType: pb.WantType.have),
      ];
      expect(message.fillWantlist(output), same(output));
      expect(output.single.cid, c);
      output.single.priority = 9;
      expect(message.wantlist().single.priority, 7);
    });
    test('cancel() - marks existing request', () {
      message.addEntry(c, 7, pb.WantType.block, false);
      expect(message.cancel(c), 0);
      expect(message.wantlist().single.cancel, isTrue);
    });
    test('remove() - removes request only', () {
      message.addEntry(c, 7, pb.WantType.block, false);
      message.addBlock(a);
      message.remove(c);
      expect(message.wantlist(), isEmpty);
      expect(message.blocks(), [a]);
    });
    test('addBlock() - supersedes presence and deduplicates CID', () {
      message.addHave(c);
      message.addBlock(a);
      message.addBlock(a);
      expect(message.blockPresences(), isEmpty);
      expect(message.blocks(), [a]);
    });
    test('blocks() - returned list cannot change message membership', () {
      message.addBlock(a);
      message.blocks().clear();
      expect(message.blocks(), [a]);
    });
    test('addBlockPresence() - cannot shadow a full block', () {
      message.addBlock(a);
      message.addBlockPresence(c, pb.BlockPresenceType.dontHave);
      expect(message.blockPresences(), isEmpty);
    });
    test('blockPresences() - reports CID and kind', () {
      message.addHave(c);
      expect(message.blockPresences(), [
        msg.BlockPresence(c, pb.BlockPresenceType.have),
      ]);
    });
    test('addHave() - overwrites previous DONT_HAVE', () {
      message.addDontHave(c);
      message.addHave(c);
      expect(message.haves(), [c]);
      expect(message.dontHaves(), isEmpty);
    });
    test('addDontHave() - overwrites previous HAVE', () {
      message.addHave(c);
      message.addDontHave(c);
      expect(message.dontHaves(), [c]);
      expect(message.haves(), isEmpty);
    });
    test('haves() - filters presence kinds', () {
      message.addHave(c);
      message.addDontHave(d);
      expect(message.haves(), [c]);
    });
    test('dontHaves() - filters presence kinds', () {
      message.addHave(c);
      message.addDontHave(d);
      expect(message.dontHaves(), [d]);
    });
    test('pendingBytes() - defaults to zero', () {
      expect(message.pendingBytes(), 0);
    });
    test('setPendingBytes() - replaces byte count', () {
      message.setPendingBytes(100);
      message.setPendingBytes(20);
      expect(message.pendingBytes(), 20);
    });
    test('size() - sums payload and presence sizes', () {
      message.addBlock(a);
      message.addHave(d);
      expect(message.size(), a.rawData().length + msg.blockPresenceSize(d));
    });
    test('toProtoV0() - legacy raw blocks omit presence and pending bytes', () {
      message.addBlock(a);
      message.addHave(d);
      message.setPendingBytes(12);
      final proto = message.toProtoV0();
      expect(proto.blocks, [a.rawData()]);
      expect(proto.payload, isEmpty);
      expect(proto.blockPresences, isEmpty);
      expect(proto.pendingBytes, 0);
    });
    test('toProtoV1() - encodes payload prefix and presence', () {
      message.addBlock(a);
      message.addDontHave(d);
      message.setPendingBytes(12);
      final proto = message.toProtoV1();
      expect(proto.payload.single.data, a.rawData());
      expect(proto.payload.single.prefix, c.prefix.bytes());
      expect(proto.blockPresences.single.cid, d.toBytes());
      expect(proto.pendingBytes, 12);
    });
    test('toNetV0() - framed legacy block round trip', () {
      message.addBlock(a);
      final buffer = msg.Buffer();
      message.toNetV0(buffer);
      expect(msg.fromNet(buffer).$1.blocks().single.rawData(), a.rawData());
    });
    test('toNetV1() - framed presence round trip', () {
      message.addHave(c);
      final buffer = msg.Buffer();
      message.toNetV1(buffer);
      expect(msg.fromNet(buffer).$1.haves(), [c]);
    });
    test('loggable() - contains block CIDs and wants', () {
      message.addBlock(a);
      message.addEntry(d, 1, pb.WantType.have, false);
      expect(message.loggable()['blocks'], [c.toString()]);
      expect(message.loggable()['wants'], message.wantlist());
    });
    test('reset() - clears every collection and pending count', () {
      message.addBlock(a);
      message.addHave(d);
      message.addEntry(c, 1, pb.WantType.have, false);
      message.setPendingBytes(12);
      message.reset(true);
      expect(message.empty(), isTrue);
      expect(message.pendingBytes(), 0);
      expect(message.full(), isTrue);
    });
    test('clone() - preserves contents with independent mutations', () {
      message.addEntry(c, 1, pb.WantType.have, false);
      message.addBlock(b);
      message.setPendingBytes(12);
      final copy = message.clone();
      message.reset(true);
      expect(copy.wantlist().single.cid, c);
      expect(copy.blocks(), [b]);
      expect(copy.pendingBytes(), 12);
      expect(copy.full(), isFalse);
    });
  });
}
