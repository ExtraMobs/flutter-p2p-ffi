// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/connmgr/gater.dart';
import '../../../core/control/disconnect.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';

const String _ns = '/libp2p/net/conngater';
const String _keyPeer = '/peer/';
const String _keyAddr = '/addr/';
const String _keySubnet = '/subnet/';

/// BasicConnectionGater implements a connection gater that allows the application to perform
/// access control on incoming and outgoing connections.
class BasicConnectionGater implements ConnectionGater {
  BasicConnectionGater([Datastore? ds]) : _ds = ds {
    if (_ds != null) {
      loadRules();
    }
  }

  final Datastore? _ds;
  final Map<String, PeerId> _blockedPeers = <String, PeerId>{};
  final Map<String, Ip> _blockedAddrs = <String, Ip>{};
  final Map<String, IpNet> _blockedSubnets = <String, IpNet>{};

  Future<void> loadRules() async {
    if (_ds == null) return;
    try {
      final peerResults = await _ds.query(const Query(prefix: '$_ns$_keyPeer'));
      for (final entry in peerResults.rest()) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          final p = PeerId.fromBytes(Uint8List.fromList(entry.value!));
          _blockedPeers[p.toString()] = p;
        }
      }

      final addrResults = await _ds.query(const Query(prefix: '$_ns$_keyAddr'));
      for (final entry in addrResults.rest()) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          final ip = Ip.fromBytes(entry.value!);
          _blockedAddrs[ip.toString()] = ip;
        }
      }

      final subnetResults = await _ds.query(
        const Query(prefix: '$_ns$_keySubnet'),
      );
      for (final entry in subnetResults.rest()) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          final ipnetStr = utf8.decode(entry.value!);
          final ipnet = IpNet.tryParseCidr(ipnetStr);
          if (ipnet != null) {
            _blockedSubnets[ipnetStr] = ipnet;
          }
        }
      }
    } catch (e, st) {
      dev.log(
        'error loading conngater rules: $e',
        name: 'net/conngater',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// BlockPeer adds a peer to the set of blocked peers.
  /// Note: active connections to the peer are not automatically closed.
  Future<void> blockPeer(PeerId p) async {
    _blockedPeers[p.toString()] = p;
    if (_ds != null) {
      await _ds.put(Key('$_ns$_keyPeer${p.toString()}'), p.value);
    }
  }

  /// UnblockPeer removes a peer from the set of blocked peers.
  Future<void> unblockPeer(PeerId p) async {
    _blockedPeers.remove(p.toString());
    if (_ds != null) {
      await _ds.delete(Key('$_ns$_keyPeer${p.toString()}'));
    }
  }

  /// ListBlockedPeers returns a list of blocked peers.
  List<PeerId> listBlockedPeers() => _blockedPeers.values.toList();

  /// BlockAddr adds an IP address to the set of blocked addresses.
  /// Note: active connections to the IP address are not automatically closed.
  Future<void> blockAddr(Ip ip) async {
    _blockedAddrs[ip.toString()] = ip;
    if (_ds != null) {
      await _ds.put(Key('$_ns$_keyAddr${ip.toString()}'), ip.asBytes());
    }
  }

  /// UnblockAddr removes an IP address from the set of blocked addresses.
  Future<void> unblockAddr(Ip ip) async {
    _blockedAddrs.remove(ip.toString());
    if (_ds != null) {
      await _ds.delete(Key('$_ns$_keyAddr${ip.toString()}'));
    }
  }

  /// ListBlockedAddrs returns a list of blocked IP addresses.
  List<Ip> listBlockedAddrs() => _blockedAddrs.values.toList();

  /// BlockSubnet adds an IP subnet to the set of blocked addresses.
  /// Note: active connections to the IP subnet are not automatically closed.
  Future<void> blockSubnet(IpNet ipnet) async {
    final str = ipnet.toString();
    _blockedSubnets[str] = ipnet;
    if (_ds != null) {
      await _ds.put(Key('$_ns$_keySubnet$str'), utf8.encode(str));
    }
  }

  /// UnblockSubnet removes an IP address from the set of blocked addresses.
  Future<void> unblockSubnet(IpNet ipnet) async {
    final str = ipnet.toString();
    _blockedSubnets.remove(str);
    if (_ds != null) {
      await _ds.delete(Key('$_ns$_keySubnet$str'));
    }
  }

  /// ListBlockedSubnets returns a list of blocked IP subnets.
  List<IpNet> listBlockedSubnets() => _blockedSubnets.values.toList();

  @override
  bool interceptPeerDial(PeerId peer) {
    return !_blockedPeers.containsKey(peer.toString());
  }

  @override
  bool interceptAddrDial(PeerId peer, Multiaddr address) {
    final ip = _toIp(address);
    if (ip == null) {
      return true;
    }

    if (_blockedAddrs.containsKey(ip.toString())) {
      return false;
    }

    for (final subnet in _blockedSubnets.values) {
      if (subnet.contains(ip)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool interceptAccept(ConnMultiaddrs connectionAddresses) {
    final a = connectionAddresses.remoteMultiaddr();
    final ip = _toIp(a);
    if (ip == null) {
      return true;
    }

    if (_blockedAddrs.containsKey(ip.toString())) {
      return false;
    }

    for (final subnet in _blockedSubnets.values) {
      if (subnet.contains(ip)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool interceptSecured(
    Direction direction,
    PeerId peer,
    ConnMultiaddrs connectionAddresses,
  ) {
    if (direction == Direction.outbound) {
      return true;
    }

    return !_blockedPeers.containsKey(peer.toString());
  }

  @override
  ({bool allow, DisconnectReason reason}) interceptUpgraded(Conn connection) {
    return (allow: true, reason: 0);
  }

  static Ip? _toIp(Multiaddr a) {
    for (final c in a.components) {
      if (c.protocol.code == Protocols.ip6zone) continue;
      if (c.protocol.code == Protocols.ip4 ||
          c.protocol.code == Protocols.ip6) {
        return Ip.fromBytes(c.valueBytes);
      }
      return null;
    }
    return null;
  }
}
