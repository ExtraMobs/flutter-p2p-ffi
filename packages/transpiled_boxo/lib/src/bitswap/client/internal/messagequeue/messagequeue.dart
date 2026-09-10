// ignore_for_file: public_member_api_docs, sort_constructors_first, library_private_types_in_public_api, depend_on_referenced_packages, unused_element_parameter, inference_failure_on_instance_creation, directives_ordering
import 'dart:async';

import 'package:logging/logging.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_boxo/src/bitswap/message/pb/message.dart' as pb;
import 'package:transpiled_boxo/bitswap/network.dart';

import 'donthavetimeoutmgr.dart';
import '../peermanager/peerqueue.dart';

final log = Logger('bitswap/client/msgq');

const int _maxMessageSize = 1024 * 1024 * 2;
const int _maxPriority = 2147483647; // math.MaxInt32
const int _maxRetries = 3;
const Duration _maxValidLatency = Duration(seconds: 30);
const Duration _rebroadcastInterval = Duration(seconds: 30);
const Duration _sendErrorBackoff = Duration(milliseconds: 100);
const int _sendMessageCutoff = 256;
const Duration _sendTimeout = Duration(seconds: 30);
const Duration _defaultPerPeerDelay = Duration(microseconds: 125); // Millisecond / 8 is 125us
const Duration _maxSendMessageDelay = Duration(seconds: 2);
const Duration _minSendMessageDelay = Duration(milliseconds: 20);

int _peerCount = 0;

abstract class MessageNetwork {
  Future<void> connect(PeerId peer, {dynamic addrInfo});
  Future<MessageSender> newMessageSender(PeerId peer, MessageSenderOpts opts);
  Duration latency(PeerId peer);
  Future<Duration> ping(PeerId peer);
  PeerId self();
}

class MessageQueue implements PeerQueue {
  bool _isShutdown = false;
  final PeerId p;
  final MessageNetwork network;
  final DontHaveTimeoutManager? dhTimeoutMgr;

  final int maxMessageSize;
  final Duration sendErrorBackoff;
  final Duration maxValidLatency;

  final StreamController<void> _outgoingWork = StreamController<void>.broadcast();
  final StreamController<List<Cid>> _responses = StreamController<List<Cid>>.broadcast();

  final _RecallWantlist _bcstWants = _RecallWantlist();
  final _RecallWantlist _peerWants = _RecallWantlist();
  final Set<Cid> cancels = {};
  int priority = _maxPriority;

  MessageSender? _sender;
  final StreamController<void> _rebroadcastNow = StreamController<void>.broadcast();
  final BitSwapMessage msg = BitSwapMessage(false);

  final StreamSink<MessageEvent>? events;
  Duration perPeerDelay = _defaultPerPeerDelay;
  void Function()? bcastInc;
  
  Timer? _rebroadcastTimer;

  MessageQueue._({
    required this.p,
    required this.network,
    required this.maxMessageSize,
    required this.sendErrorBackoff,
    required this.maxValidLatency,
    this.dhTimeoutMgr,
    this.events,
  });

  factory MessageQueue.create(
    PeerId p,
    MessageNetwork network,
    OnDontHaveTimeout? onDontHaveTimeout, {
    DontHaveTimeoutConfig? dhtConfig,
    Duration? perPeerDelay,
  }) {
    DontHaveTimeoutManager? dhTimeoutMgr;
    if (onDontHaveTimeout != null) {
      void onTimeout(List<Cid> ks, Duration timeout) {
        log.info('Bitswap: timeout waiting for blocks timeout=$timeout cids=$ks peer=$p');
        onDontHaveTimeout(ks, timeout);
      }
      dhTimeoutMgr = DontHaveTimeoutManager.create(
        _PeerConn(p, network),
        onTimeout,
        dhtConfig,
      );
    }
    final mq = MessageQueue._(
      p: p,
      network: network,
      maxMessageSize: _maxMessageSize,
      sendErrorBackoff: _sendErrorBackoff,
      maxValidLatency: _maxValidLatency,
      dhTimeoutMgr: dhTimeoutMgr,
    );
    if (perPeerDelay != null && perPeerDelay.inMicroseconds > 0) {
      mq.perPeerDelay = perPeerDelay;
    }
    return mq;
  }

  void addBroadcastWantHaves(List<Cid> wantHaves) {
    if (wantHaves.isEmpty) return;

    for (final c in wantHaves) {
      _bcstWants.add(c, priority, pb.WantType.have);
      priority--;
      cancels.remove(c);
    }

    _signalWorkReady();
  }

  void addWants(List<Cid> wantBlocks, List<Cid> wantHaves) {
    if (wantBlocks.isEmpty && wantHaves.isEmpty) return;

    for (final c in wantHaves) {
      _peerWants.add(c, priority, pb.WantType.have);
      priority--;
      cancels.remove(c);
    }
    for (final c in wantBlocks) {
      _peerWants.add(c, priority, pb.WantType.block);
      priority--;
      cancels.remove(c);
    }

    _signalWorkReady();
  }

  void addCancels(List<Cid> cancelKs) {
    if (cancelKs.isEmpty) return;

    dhTimeoutMgr?.cancelPending(cancelKs);

    var workReady = false;

    for (final c in cancelKs) {
      final wasSentBcst = _bcstWants._sent.containsKey(c);
      final wasSentPeer = _peerWants._sent.containsKey(c);

      _bcstWants.remove(c);
      _peerWants.remove(c);

      if (wasSentBcst || wasSentPeer) {
        cancels.add(c);
        workReady = true;
      }
    }

    if (workReady) {
      _signalWorkReady();
    }
  }

  bool hasMessage() {
    return _bcstWants._pending.isNotEmpty || _peerWants._pending.isNotEmpty || cancels.isNotEmpty;
  }

  void responseReceived(List<Cid> ks) {
    if (ks.isEmpty) return;
    _responses.add(ks);
  }

  void rebroadcastNow() {
    _rebroadcastNow.add(null);
  }

  void startup() {
    unawaited(_runQueue());
  }

  void shutdown() {
    _isShutdown = true;
    _outgoingWork.close();
    _responses.close();
    _rebroadcastNow.close();
  }

  void _onShutdown() {
    dhTimeoutMgr?.shutdown();
    _sender?.reset();
    _rebroadcastTimer?.cancel();
  }

  Future<void> _runQueue() async {
    const runRebroadcastsInterval = Duration(seconds: 15); // rebroadcastInterval / 2

    _peerCount++;
    
    // We simulate `scheduleWork` as a Completer / Timer
    Timer? scheduleWork;

    _rebroadcastTimer = Timer.periodic(runRebroadcastsInterval, (timer) {
      if (_isShutdown) {
        timer.cancel();
        return;
      }
      _rebroadcastWantlist(DateTime.now(), _rebroadcastInterval);
    });

    final workSub = _outgoingWork.stream.listen((_) async {
      if (_isShutdown) return;
      events?.add(MessageEvent.messageQueued);
      await _sendMessage();
      
      var delayUs = _peerCount * perPeerDelay.inMicroseconds;
      if (delayUs < _minSendMessageDelay.inMicroseconds) delayUs = _minSendMessageDelay.inMicroseconds;
      if (delayUs > _maxSendMessageDelay.inMicroseconds) delayUs = _maxSendMessageDelay.inMicroseconds;
      
      scheduleWork?.cancel();
      scheduleWork = Timer(Duration(microseconds: delayUs), () {
        if (!_isShutdown && hasMessage()) {
          _signalWorkReady();
        }
      });
    });

    final rebroadcastSub = _rebroadcastNow.stream.listen((_) {
      if (_isShutdown) return;
      _rebroadcastWantlist(DateTime.now(), Duration.zero);
    });

    final responseSub = _responses.stream.listen((res) {
      if (_isShutdown) return;
      _handleResponse(res);
    });

    // Wait until shutdown
    while (!_isShutdown) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    unawaited(workSub.cancel());
    unawaited(rebroadcastSub.cancel());
    unawaited(responseSub.cancel());
    _peerCount--;
    _onShutdown();
  }

  void _rebroadcastWantlist(DateTime now, Duration interval) {
    final toRebroadcast = _bcstWants.refresh(now, interval) + _peerWants.refresh(now, interval);
    if (toRebroadcast > 0) {
      unawaited(_sendMessage());
      log.info('Rebroadcasting wants amount=$toRebroadcast peer=$p');
    }
  }

  void _signalWorkReady() {
    if (!_outgoingWork.isClosed) {
      _outgoingWork.add(null);
    }
  }

  Future<void> _sendMessage() async {
    final sender = await _initializeSender();
    if (sender == null) return;

    dhTimeoutMgr?.start();

    final supportsHave = sender.supportsHave();

    while (true) {
      final res = _extractOutgoingMessage(supportsHave);
      final message = res.message;
      final onSent = res.onSent;

      if (message.empty()) {
        message.reset(false);
        return;
      }

      final wantlist = message.fillWantlist(<Entry>[]);
      _logOutgoingMessage(wantlist);

      try {
        await sender.sendMsg(message);
      } catch (e) {
        log.info('Could not send message to peer $p: $e');
        message.reset(false);
        return;
      }

      onSent();
      _simulateDontHaveWithTimeout(wantlist);

      final pendingWork = _pendingWorkCount();
      if (pendingWork < _sendMessageCutoff) {
        if (pendingWork > 0) {
          _signalWorkReady();
        }
        message.reset(false);
        return;
      }

      message.reset(false);
    }
  }

  void _simulateDontHaveWithTimeout(List<Entry> wantlist) {
    final wants = <Cid>[];

    for (final entry in wantlist) {
      if (entry.wantType == pb.WantType.block && entry.sendDontHave) {
        final c = entry.cid;
        if (_peerWants._sent.containsKey(c)) {
          wants.add(c);
        }
      }
    }

    dhTimeoutMgr?.addPending(wants);
  }

  void _handleResponse(List<Cid> ks) {
    final now = DateTime.now();
    DateTime? earliest;

    for (final c in ks) {
      if (_bcstWants._sentAt.containsKey(c)) {
        final at = _bcstWants._sentAt[c]!;
        if ((earliest == null || at.isBefore(earliest)) && now.difference(at) < maxValidLatency) {
          earliest = at;
        }
        _bcstWants.clearSentAt(c);
      }
      if (_peerWants._sentAt.containsKey(c)) {
        final at = _peerWants._sentAt[c]!;
        if ((earliest == null || at.isBefore(earliest)) && now.difference(at) < maxValidLatency) {
          earliest = at;
        }
        _peerWants.clearSentAt(c);
      }
    }

    if (earliest != null) {
      dhTimeoutMgr?.updateMessageLatency(now.difference(earliest));
    }
    events?.add(MessageEvent.latenciesRecorded);
  }

  void _logOutgoingMessage(List<Entry> wantlist) {
    // simplified log
  }

  int _pendingWorkCount() {
    return _bcstWants._pending.length + _peerWants._pending.length + cancels.length;
  }

  _ExtractRes _extractOutgoingMessage(bool supportsHave) {
    var peerEntries = _peerWants._pending.values.toList();
    final bcstEntries = _bcstWants._pending.values.toList();
    final cancelList = cancels.toList();

    if (!supportsHave) {
      peerEntries = peerEntries.where((e) => e.wantType != pb.WantType.have).toList();
      // Wait, we also need to remove them from peerWants pending if they are removed?
      // "doing this here under the lock makes everything else simpler."
      final toRemove = _peerWants._pending.values.where((e) => e.wantType == pb.WantType.have).map((e) => e.cid).toList();
      for (final c in toRemove) {
        _peerWants.removeType(c, pb.WantType.have);
      }
    }

    var msgSize = 0;
    var sentCancels = 0;
    var sentPeerEntries = 0;
    var sentBcstEntries = 0;

    for (final c in cancelList) {
      msgSize += msg.cancel(c);
      sentCancels++;
      if (msgSize >= maxMessageSize) break;
    }

    if (msgSize < maxMessageSize) {
      for (final e in peerEntries) {
        msgSize += msg.addEntry(e.cid, e.priority, e.wantType, true);
        sentPeerEntries++;
        if (msgSize >= maxMessageSize) break;
      }
    }

    if (msgSize < maxMessageSize) {
      for (final e in bcstEntries) {
        var wantType = pb.WantType.have;
        if (!supportsHave) {
          wantType = pb.WantType.block;
        }
        msgSize += msg.addEntry(e.cid, e.priority, wantType, false);
        sentBcstEntries++;
        if (msgSize >= maxMessageSize) break;
      }
    }

    for (var i = 0; i < sentPeerEntries; i++) {
      final e = peerEntries[i];
      if (!_peerWants.markSent(e)) {
        msg.remove(e.cid);
        // e.cid = undefined ... we just null it in a wrapper or handle it differently
      }
    }

    for (var i = 0; i < sentBcstEntries; i++) {
      final e = bcstEntries[i];
      if (!_bcstWants.markSent(e)) {
        msg.remove(e.cid);
      }
    }

    for (var i = 0; i < sentCancels; i++) {
      final c = cancelList[i];
      if (!cancels.contains(c)) {
        msg.remove(c);
      } else {
        cancels.remove(c);
      }
    }

    void onSent() {
      final now = DateTime.now();
      for (var i = 0; i < sentPeerEntries; i++) {
        final e = peerEntries[i];
        if (_peerWants._sent.containsKey(e.cid)) { // approximate check if it wasn't nullified
          _peerWants.setSentAt(e.cid, now);
        }
      }
      for (var i = 0; i < sentBcstEntries; i++) {
        final e = bcstEntries[i];
        if (_bcstWants._sent.containsKey(e.cid)) {
          _bcstWants.setSentAt(e.cid, now);
          bcastInc?.call();
        }
      }
      events?.add(MessageEvent.messageFinishedSending);
    }

    return _ExtractRes(msg, onSent);
  }

  Future<MessageSender?> _initializeSender() async {
    if (_sender == null) {
      final opts = MessageSenderOpts(
        maxRetries: _maxRetries,
        sendTimeout: _sendTimeout,
        sendErrorBackoff: sendErrorBackoff,
      );
      try {
        _sender = await network.newMessageSender(p, opts);
      } catch (e) {
        return null;
      }
    }
    return _sender;
  }
}

class _ExtractRes {
  final BitSwapMessage message;
  final void Function() onSent;
  _ExtractRes(this.message, this.onSent);
}

enum MessageEvent {
  messageQueued,
  messageFinishedSending,
  latenciesRecorded,
}

class _RecallWantlist {
  final Map<Cid, _WantEntry> _pending = {};
  final Map<Cid, _WantEntry> _sent = {};
  final Map<Cid, DateTime> _sentAt = {};

  void add(Cid c, int priority, pb.WantType wtype) {
    _pending[c] = _WantEntry(c, priority, wtype);
  }

  void remove(Cid c) {
    _pending.remove(c);
    _sent.remove(c);
    _sentAt.remove(c);
  }

  void removeType(Cid c, pb.WantType wtype) {
    if (_pending[c]?.wantType == wtype) {
      _pending.remove(c);
    }
    if (_sent[c]?.wantType == wtype) {
      _sent.remove(c);
    }
    if (!_sent.containsKey(c)) {
      _sentAt.remove(c);
    }
  }

  bool markSent(_WantEntry e) {
    if (_pending[e.cid]?.wantType == e.wantType) {
      _pending.remove(e.cid);
      _sent[e.cid] = e;
      return true;
    }
    return false;
  }

  void setSentAt(Cid c, DateTime at) {
    if (_sent.containsKey(c)) {
      _sentAt.putIfAbsent(c, () => at);
    }
  }

  void clearSentAt(Cid c) {
    _sentAt.remove(c);
  }

  int refresh(DateTime now, Duration interval) {
    var refreshed = 0;
    final keysToRefresh = <Cid>[];
    
    for (final want in _sent.values) {
      final at = _sentAt[want.cid];
      if (at != null && now.difference(at) >= interval) {
        keysToRefresh.add(want.cid);
      }
    }

    for (final wantCid in keysToRefresh) {
      final want = _sent.remove(wantCid)!;
      _pending[wantCid] = want;
      refreshed++;
    }

    return refreshed;
  }
}

class _WantEntry {
  final Cid cid;
  final int priority;
  final pb.WantType wantType;

  _WantEntry(this.cid, this.priority, this.wantType);
}

class _PeerConn implements PeerConnection {
  final PeerId p;
  final MessageNetwork network;

  _PeerConn(this.p, this.network);

  @override
  Future<Duration> ping(Duration timeout) async {
    return await network.ping(p); // using timeout inside ping if supported
  }

  @override
  Duration latency() {
    return network.latency(p);
  }
}
