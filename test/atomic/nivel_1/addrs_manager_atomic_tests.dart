import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/p2p/host/basic/addrs_manager.dart';
import 'package:transpiled_libp2p/src/p2p/host/basic/nat_manager.dart';
import 'package:transpiled_libp2p/src/p2p/net/interface_addrs.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _MockNatManager implements NatManager {
  _MockNatManager(this.getMappingFunc);
  final Multiaddr? Function(Multiaddr) getMappingFunc;

  @override
  Multiaddr? getMapping(Multiaddr addr) => getMappingFunc(addr);

  @override
  bool get hasDiscoveredNat => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> close() async {}
}

class _MockObservedAddrs implements ObservedAddrsManager {
  _MockObservedAddrs({this.addrsFunc, this.addrsForFunc});
  final List<Multiaddr> Function(int)? addrsFunc;
  final List<Multiaddr> Function(Multiaddr)? addrsForFunc;

  @override
  List<Multiaddr> addrs(int minObservers) => addrsFunc?.call(minObservers) ?? const [];

  @override
  List<Multiaddr> addrsFor(Multiaddr local) => addrsForFunc?.call(local) ?? const [];
}

class _MockInterfaceCache extends InterfaceAddrsCache {
  _MockInterfaceCache(this.mockAddrs);
  final List<Multiaddr> mockAddrs;

  @override
  List<Multiaddr> allSync() => mockAddrs;

  @override
  Future<List<Multiaddr>> all() async => mockAddrs;
}

void main() {
  group('AddrsManager [Atomic Audit - go-libp2p addrs_manager_test.go]', () {
    final lhquic = Multiaddr.parse('/ip4/127.0.0.1/udp/1/quic-v1');
    final lhtcp = Multiaddr.parse('/ip4/127.0.0.1/tcp/1');
    final publicQUIC = Multiaddr.parse('/ip4/1.2.3.4/udp/1/quic-v1');
    final publicTCP = Multiaddr.parse('/ip4/1.2.3.4/tcp/1');

    test('getLocalAddrs - only NAT', () {
      final am = AddrsManager(
        listenAddrs: () => [lhquic, lhtcp],
        natManager: _MockNatManager((addr) {
          if (addr.hasProtocol(Protocols.udp)) {
            return publicQUIC;
          }
          return null;
        }),
      );

      final addrs = am.getLocalAddrs();
      final strAddrs = addrs.map((a) => a.toString()).toSet();
      expect(strAddrs, contains(publicQUIC.toString()));
      expect(strAddrs, contains(lhquic.toString()));
      expect(strAddrs, contains(lhtcp.toString()));
    });

    test('getLocalAddrs - unconditionally deletes unspecified addresses (0.0.0.0 and ::)', () {
      final ifaceCache = _MockInterfaceCache([
        Multiaddr.parse('/ip4/127.0.0.1'),
        Multiaddr.parse('/ip4/192.168.1.50'),
      ]);

      final am = AddrsManager(
        listenAddrs: () => [
          Multiaddr.parse('/ip4/0.0.0.0/tcp/4002'),
          Multiaddr.parse('/ip6/::/tcp/4002'),
        ],
        interfaceAddrs: ifaceCache,
      );

      final addrs = am.getLocalAddrs();
      final strAddrs = addrs.map((a) => a.toString()).toList();

      // Zero 0.0.0.0 or :: addresses
      expect(strAddrs.any((a) => a.contains('0.0.0.0')), isFalse);
      expect(strAddrs.any((a) => a.contains('/ip6/::/')), isFalse);

      // Successfully expanded to interfaces
      expect(strAddrs, contains('/ip4/127.0.0.1/tcp/4002'));
      expect(strAddrs, contains('/ip4/192.168.1.50/tcp/4002'));
    });

    test('getLocalAddrs - incorporates observed addresses from Identify', () {
      final ifaceCache = _MockInterfaceCache([
        Multiaddr.parse('/ip4/127.0.0.1'),
        Multiaddr.parse('/ip4/192.168.1.50'),
      ]);

      final observedWan = Multiaddr.parse('/ip4/203.0.113.47/tcp/4002');
      final obsMgr = _MockObservedAddrs(
        addrsForFunc: (local) {
          if (local.toString().contains('192.168.1.50')) {
            return [observedWan];
          }
          return const [];
        },
        addrsFunc: (_) => [observedWan],
      );

      final am = AddrsManager(
        listenAddrs: () => [Multiaddr.parse('/ip4/0.0.0.0/tcp/4002')],
        interfaceAddrs: ifaceCache,
        observedAddrsManager: obsMgr,
      );

      final addrs = am.addrs();
      final strAddrs = addrs.map((a) => a.toString()).toList();

      expect(strAddrs, contains(observedWan.toString()));
      expect(strAddrs, contains('/ip4/192.168.1.50/tcp/4002'));
      expect(strAddrs, contains('/ip4/127.0.0.1/tcp/4002'));
      expect(strAddrs.any((a) => a.contains('0.0.0.0')), isFalse);
    });

    test('applyAddrsFactory - applies custom factory filtering', () {
      final am = AddrsManager(
        listenAddrs: () => [lhquic, lhtcp],
        addrsFactory: (addrs) => addrs.where((a) => a != lhquic).toList(),
      );

      final addrs = am.addrs();
      expect(addrs.map((a) => a.toString()), contains(lhtcp.toString()));
      expect(addrs.map((a) => a.toString()), isNot(contains(lhquic.toString())));
    });
  });
}
