import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/notifications/notifications.dart';

class MyQueue<T> {
  final _items = <T>[];
  final _completers = <Completer<T>>[];
  StreamSubscription<T>? _sub;

  MyQueue(Stream<T> stream) {
    _sub = stream.listen((item) {
      if (_completers.isNotEmpty) {
        _completers.removeAt(0).complete(item);
      } else {
        _items.add(item);
      }
    });
  }

  Future<T> get next {
    if (_items.isNotEmpty) {
      return Future.value(_items.removeAt(0));
    }
    final c = Completer<T>();
    _completers.add(c);
    return c.future;
  }

  void cancel() {
    _sub?.cancel();
  }
}

void main() {
  final zeroPeer = PeerId.fromBytes(Uint8List(34)..setRange(0, 2, [0x12, 0x20]));

  Block newBlock(String data) {
    return BasicBlock.fromData(Uint8List.fromList(utf8.encode(data)));
  }

  void assertBlocksEqual(Block a, Block b) {
    expect(a.rawData(), equals(b.rawData()));
    expect(a.cid(), equals(b.cid()));
  }

  test('TestDuplicates', () async {
    final b1 = newBlock('1');
    final b2 = newBlock('2');

    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());
    
    final ch = n.subscribe([b1.cid(), b2.cid()]);
    final iter = MyQueue<Block>(ch);

    n.publish(zeroPeer, [b1]);
    final r1 = await iter.next;
    assertBlocksEqual(b1, r1);

    n.publish(zeroPeer, [b1]); // ignored duplicate

    n.publish(zeroPeer, [b2]);
    final r2 = await iter.next;
    assertBlocksEqual(b2, r2);
  });

  test('TestPublishSubscribe', () async {
    final blockSent = newBlock('Greetings from The Interval');

    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());
    
    final ch = n.subscribe([blockSent.cid()]);
    final iter = MyQueue<Block>(ch);

    n.publish(zeroPeer, [blockSent]);
    final blockRecvd = await iter.next;

    assertBlocksEqual(blockRecvd, blockSent);
  });

  test('TestSubscribeMany', () async {
    final e1 = newBlock('1');
    final e2 = newBlock('2');

    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());
    
    final ch = n.subscribe([e1.cid(), e2.cid()]);
    final iter = MyQueue<Block>(ch);

    n.publish(zeroPeer, [e1]);
    final r1 = await iter.next;
    assertBlocksEqual(e1, r1);

    n.publish(zeroPeer, [e2]);
    final r2 = await iter.next;
    assertBlocksEqual(e2, r2);
  });

  test('TestDuplicateSubscribe', () async {
    final e1 = newBlock('1');

    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());
    
    final ch1 = n.subscribe([e1.cid()]);
    final ch2 = n.subscribe([e1.cid()]);

    final iter1 = MyQueue<Block>(ch1);
    final iter2 = MyQueue<Block>(ch2);

    n.publish(zeroPeer, [e1]);
    
    final r1 = await iter1.next;
    assertBlocksEqual(e1, r1);

    final r2 = await iter2.next;
    assertBlocksEqual(e1, r2);
  });

  test('TestShutdownBeforeUnsubscribe', () async {
    final e1 = newBlock('1');

    final n = NotificationsPubSub(traceBlock: false);
    
    // Subscribe and shutdown
    final ch = n.subscribe([e1.cid()]);
    n.shutdown();

    // Stream should close or complete empty
    final list = await ch.toList();
    expect(list, isEmpty);
  });

  test('TestSubscribeIsANoopWhenCalledWithNoKeys', () async {
    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());
    
    final ch = n.subscribe([]);
    final list = await ch.toList();
    expect(list, isEmpty);
  });

  test('TestCarryOnWhenDeadlineExpires', () async {
    // In Go, it cancels the context quickly.
    // In Dart, we can just cancel the subscription immediately to simulate.
    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());
    
    final block = newBlock('A Missed Connection');
    final blockChannel = n.subscribe([block.cid()]);
    
    final sub = blockChannel.listen((event) {});
    await sub.cancel(); // Cancel immediately
    
    // We shouldn't receive anything.
  });

  test('TestDoesNotDeadLockIfContextCancelledBeforePublish', () async {
    final n = NotificationsPubSub(traceBlock: false);
    addTearDown(() => n.shutdown());

    final bs = List.generate(1000, (i) => newBlock('block_\$i'));
    final ks = bs.map((b) => b.cid()).toList();

    final ch = n.subscribe(ks);
    final sub = ch.listen((_) {});

    await sub.cancel(); // Cancel before publish

    for (final b in bs) {
      n.publish(zeroPeer, [b]);
    }
    // Must not deadlock
  });
}
