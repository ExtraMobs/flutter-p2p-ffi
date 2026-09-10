import 'dart:typed_data';
// ignore_for_file: depend_on_referenced_packages, directives_ordering, inference_failure_on_instance_creation
import 'dart:async';
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_boxo/bitswap/network.dart';

import 'package:transpiled_boxo/src/bitswap/client/internal/messagequeue/messagequeue.dart';

class FakeMessageNetwork implements MessageNetwork {
  final Exception? connectError;
  final Exception? messageSenderError;
  final MessageSender messageSender;

  FakeMessageNetwork({
    this.connectError,
    this.messageSenderError,
    required this.messageSender,
  });

  @override
  Future<void> connect(PeerId peer, {dynamic addrInfo}) async {
    if (connectError != null) throw connectError!;
  }

  @override
  Future<MessageSender> newMessageSender(PeerId peer, MessageSenderOpts opts) async {
    if (messageSenderError != null) throw messageSenderError!;
    return messageSender;
  }

  @override
  Duration latency(PeerId peer) => Duration.zero;

  @override
  Future<Duration> ping(PeerId peer) async => Duration.zero;

  @override
  PeerId self() => PeerId(value: Uint8List(0));
}

class FakeMessageSender implements MessageSender {
  final StreamSink<void> resetChan;
  final StreamSink<List<Entry>> messagesSent;
  final bool _supportsHave;

  FakeMessageSender(this.resetChan, this.messagesSent, this._supportsHave);

  @override
  Future<void> sendMsg(BitSwapMessage msg) async {
    messagesSent.add(msg.wantlist());
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> reset() async {
    resetChan.add(null);
  }

  @override
  bool supportsHave() => _supportsHave;
}

var _cidCounter = 0;
List<Cid> _randomCids(int count) {
  return List.generate(count, (i) {
    _cidCounter++;
    return Cid.fromBytes(Uint8List.fromList([1, 85, 0, 5, 0, 1, 2, _cidCounter, 4, 5]));
  });
}

void mockTimeoutCb(List<Cid> cids, Duration timeout) {}

void main() {
  test('TestStartupAndShutdown', () async {
    final messagesSent = StreamController<List<Entry>>.broadcast();
    final resetChan = StreamController<void>.broadcast();
    
    final fakeSender = FakeMessageSender(resetChan.sink, messagesSent.sink, true);
    final fakeNet = FakeMessageNetwork(messageSender: fakeSender);
    
    final peerID = PeerId(value: Uint8List.fromList([1, 2, 3]));
    final messageQueue = MessageQueue.create(peerID, fakeNet, mockTimeoutCb);
    
    final bcstwh = _randomCids(10);
    
    messageQueue.startup();
    messageQueue.addBroadcastWantHaves(bcstwh);
    
    final message = await messagesSent.stream.first.timeout(const Duration(seconds: 2));
    expect(message.length, bcstwh.length);
    
    for (final entry in message) {
      expect(entry.cancel, false);
    }
    
    messageQueue.shutdown();
    
    await resetChan.stream.first.timeout(const Duration(seconds: 1));
  });

  test('TestSendingMessagesDeduped', () async {
    final messagesSent = StreamController<List<Entry>>.broadcast();
    final resetChan = StreamController<void>.broadcast();
    
    final fakeSender = FakeMessageSender(resetChan.sink, messagesSent.sink, true);
    final fakeNet = FakeMessageNetwork(messageSender: fakeSender);
    
    final peerID = PeerId(value: Uint8List.fromList([1, 2, 3]));
    final messageQueue = MessageQueue.create(peerID, fakeNet, mockTimeoutCb);
    
    final wantHaves = _randomCids(10);
    final wantBlocks = _randomCids(10);
    
    messageQueue.startup();
    messageQueue.addWants(wantBlocks, wantHaves);
    messageQueue.addWants(wantBlocks, wantHaves); // Duplicate
    
    final message = await messagesSent.stream.first.timeout(const Duration(seconds: 2));
    
    expect(message.length, wantHaves.length + wantBlocks.length);
    
    messageQueue.shutdown();
  });
}
