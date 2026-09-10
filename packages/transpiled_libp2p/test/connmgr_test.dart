// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/connmgr/decay.dart';
import 'package:transpiled_libp2p/src/core/connmgr/gater.dart';
import 'package:transpiled_libp2p/src/core/connmgr/manager.dart';
import 'package:transpiled_libp2p/src/core/connmgr/null.dart';
import 'package:transpiled_libp2p/src/core/connmgr/presets.dart';
import 'package:transpiled_libp2p/src/core/control/disconnect.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  final peer = PeerId(value: Uint8List.fromList([1, 2, 3]));
  final tag = _Tag();

  test('presets match the core connmgr contracts', () {
    final value = DecayingValue(
      tag: tag,
      peer: peer,
      added: DateTime.now().subtract(const Duration(seconds: 5)),
      lastVisit: DateTime.now().subtract(const Duration(seconds: 5)),
      value: 10,
    );

    expect(decayNone()(value), (after: 10, remove: false));
    expect(decayFixed(3)(value), (after: 7, remove: false));
    expect(decayFixed(10)(value), (after: 0, remove: true));
    expect(decayLinear(.5)(value), (after: 5, remove: false));
    expect(
      decayExpireWhenInactive(const Duration(seconds: 1))(value).remove,
      isFalse,
    );
    expect(bumpSumUnbounded()(value, 4), 14);
    expect(bumpSumBounded(0, 12)(value, 4), 12);
    expect(bumpSumBounded(0, 12)(value, -20), 0);
    expect(bumpOverwrite()(value, 4), 4);
  });

  test('NullConnMgr preserves the no-op upstream behavior', () {
    const manager = NullConnMgr();
    manager.tagPeer(peer, 'tag', 1);
    manager.untagPeer(peer, 'tag');
    manager.upsertTag(peer, 'tag', (value) => value + 1);
    manager.trimOpenConns();
    manager.protect(peer, 'tag');
    expect(manager.getTagInfo(peer), isA<TagInfo>());
    expect(manager.unprotect(peer, 'tag'), isFalse);
    expect(manager.isProtected(peer, ''), isFalse);
    expect(manager.notifiee(), same(globalNoopNotifiee));
    manager.checkLimit(_Limiter());
    manager.close();
  });

  test('supportsDecay uses the optional interface', () {
    final manager = _DecayingManager();
    final supported = supportsDecay(manager);
    expect(supported.$1, same(manager));
    expect(supported.$2, isTrue);
    final unsupported = supportsDecay(const NullConnMgr());
    expect(unsupported.$1, isNull);
    expect(unsupported.$2, isFalse);
  });

  test('gater contract retains peer/address and disconnect reason types', () {
    final gater = _Gater();
    expect(gater.interceptPeerDial(peer), isTrue);
    expect(gater.interceptAddrDial(peer, Multiaddr.empty), isTrue);
    final addresses = _ConnAddresses();
    expect(gater.interceptAccept(addresses), isTrue);
    expect(gater.interceptSecured(Direction.inbound, peer, addresses), isTrue);
    expect(gater.interceptUpgraded(_Conn()), (allow: false, reason: 7));
  });
}

class _Tag implements DecayingTag {
  @override
  void bump(PeerId peer, int delta) {}

  @override
  void close() {}

  @override
  Duration interval() => const Duration(seconds: 1);

  @override
  String name() => 'test';

  @override
  void remove(PeerId peer) {}
}

class _Limiter implements GetConnLimiter {
  @override
  int getConnLimit() => 1;
}

class _DecayingManager implements ConnManager, Decayer {
  _DecayingManager();

  @override
  void tagPeer(PeerId peer, String tag, int value) {}

  @override
  void untagPeer(PeerId peer, String tag) {}

  @override
  void upsertTag(PeerId peer, String tag, int Function(int value) upsert) {}

  @override
  TagInfo? getTagInfo(PeerId peer) => null;

  @override
  void trimOpenConns() {}

  @override
  Notifiee notifiee() => globalNoopNotifiee;

  @override
  void protect(PeerId peer, String tag) {}

  @override
  bool unprotect(PeerId peer, String tag) => false;

  @override
  bool isProtected(PeerId peer, String tag) => false;

  @override
  void checkLimit(GetConnLimiter limiter) {}

  @override
  void close() {}

  @override
  DecayingTag registerDecayingTag(
    String name,
    Duration interval,
    DecayFn decayFn,
    BumpFn bumpFn,
  ) => _Tag();
}

class _Gater implements ConnectionGater {
  @override
  bool interceptAccept(ConnMultiaddrs connectionAddresses) => true;

  @override
  bool interceptAddrDial(PeerId peer, Multiaddr address) => true;

  @override
  bool interceptPeerDial(PeerId peer) => true;

  @override
  bool interceptSecured(
    Direction direction,
    PeerId peer,
    ConnMultiaddrs connectionAddresses,
  ) => true;

  @override
  ({bool allow, DisconnectReason reason}) interceptUpgraded(Conn connection) =>
      (allow: false, reason: 7);
}

class _Conn implements Conn {}

class _ConnAddresses implements ConnMultiaddrs {
  @override
  Multiaddr localMultiaddr() => Multiaddr.empty;

  @override
  Multiaddr remoteMultiaddr() => Multiaddr.empty;
}
