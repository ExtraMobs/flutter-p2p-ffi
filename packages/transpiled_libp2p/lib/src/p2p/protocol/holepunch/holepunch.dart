import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/proto_varint.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';
import 'pb/holepunch_message.dart';

/// Protocol ID for Direct Connection Upgrade through Relay (DCUtR).
const String holePunchProtocol = '/libp2p/dcutr';

/// Checks if an address represents a relayed circuit connection.
bool isRelayAddress(Multiaddr addr) {
  for (final proto in addr.protocols) {
    if (proto.name == 'p2p-circuit') return true;
  }
  return false;
}

/// Service that coordinates DCUtR (Direct Connection Upgrade through Relay)
/// hole punching between two peers connected via a Circuit Relay.
class HolePunchService {
  HolePunchService({
    required this.host,
    this.directDialTimeout = const Duration(seconds: 10),
    this.listenAddrs,
  }) : holePuncher = HolePuncher(
          host: host,
          directDialTimeout: directDialTimeout,
          listenAddrs: listenAddrs,
        );

  final Host host;
  final Duration directDialTimeout;
  final List<Multiaddr> Function()? listenAddrs;
  final HolePuncher holePuncher;

  bool _started = false;
  bool _closed = false;

  bool get isStarted => _started;
  bool get isClosed => _closed;

  /// Starts the DCUtR hole punching service and registers the stream handler.
  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    host.setStreamHandler(holePunchProtocol, handleStream);
  }

  /// Closes the service and stops the stream handler.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _started = false;
    host.removeStreamHandler(holePunchProtocol);
    await holePuncher.close();
  }

  /// Handles an inbound DCUtR stream from an initiator behind a relay.
  Future<void> handleStream(NetworkStream stream) async {
    try {
      final remoteConn = stream.conn();
      PeerId? remotePeer;
      if (remoteConn case final ConnSecurity sec) {
        remotePeer = sec.remotePeer();
      }
      if (remotePeer == null) {
        await stream.reset();
        return;
      }

      // Step 1: Read CONNECT message from initiator
      final rawReq = await _readDelimited(stream);
      if (rawReq == null) {
        await stream.reset();
        return;
      }
      final req = HolePunchMessage.unmarshal(rawReq);
      if (req.type != HolePunchMessageType.connect) {
        await stream.reset();
        return;
      }

      // Parse initiator's observed direct addresses
      final initiatorAddrs = <Multiaddr>[];
      for (final addrBytes in req.obsAddrs) {
        try {
          final ma = Multiaddr.fromBytes(addrBytes);
          if (!isRelayAddress(ma)) {
            initiatorAddrs.add(ma);
          }
        } catch (_) {}
      }

      // Step 2: Send CONNECT message with our own addresses
      final ownAddrs = listenAddrs?.call() ?? host.addrs;
      final filteredOwn = ownAddrs.where((a) => !isRelayAddress(a)).toList();
      final resp = HolePunchMessage(
        type: HolePunchMessageType.connect,
        obsAddrs: filteredOwn.map((a) => a.toBytes()).toList(),
      );
      final tstart = DateTime.now();
      await _writeDelimited(stream, resp.marshal());

      // Step 3: Read SYNC message from initiator
      final rawSync = await _readDelimited(stream);
      if (rawSync == null) {
        await stream.reset();
        return;
      }
      final syncMsg = HolePunchMessage.unmarshal(rawSync);
      if (syncMsg.type != HolePunchMessageType.sync) {
        await stream.reset();
        return;
      }
      final rtt = DateTime.now().difference(tstart);

      await stream.close();

      // Step 4: Simultaneous connect attempt to remote peer
      if (initiatorAddrs.isNotEmpty) {
        // Save direct addresses into peerstore
        host.peerstore.addAddrs(
          remotePeer,
          initiatorAddrs,
          const Duration(minutes: 5),
        );
        try {
          await host.connect(
            AddrInfo(id: remotePeer, addrs: initiatorAddrs),
          ).timeout(directDialTimeout);
        } catch (_) {
          // Hole punch attempt completed; if direct dial failed, relay stays active
        }
      }
    } catch (_) {
      try {
        await stream.reset();
      } catch (_) {}
    }
  }

  /// Attempts a direct connection to a remote peer via DCUtR.
  Future<bool> directConnect(
    PeerId peer, {
    List<Multiaddr> addrs = const [],
  }) {
    return holePuncher.initiateHolePunch(peer, addrs);
  }

  static Future<Uint8List?> _readDelimited(NetworkStream stream) async {
    final firstByte = await stream.read(1);
    if (firstByte.isEmpty) return null;
    var len = firstByte[0] & 0x7f;
    var shift = 7;
    if ((firstByte[0] & 0x80) != 0) {
      while (true) {
        final b = await stream.read(1);
        if (b.isEmpty) return null;
        len |= (b[0] & 0x7f) << shift;
        if ((b[0] & 0x80) == 0) break;
        shift += 7;
      }
    }
    if (len == 0) return Uint8List(0);
    final buf = <int>[];
    while (buf.length < len) {
      final chunk = await stream.read(len - buf.length);
      if (chunk.isEmpty) break;
      buf.addAll(chunk);
    }
    return Uint8List.fromList(buf);
  }

  static Future<void> _writeDelimited(
    NetworkStream stream,
    Uint8List data,
  ) async {
    final prefix = encodeProtoVarint(data.length);
    final packet = Uint8List(prefix.length + data.length);
    packet.setRange(0, prefix.length, prefix);
    packet.setRange(prefix.length, packet.length, data);
    await stream.write(packet);
  }
}

/// Helper class that manages active DCUtR hole punch attempts per peer.
class HolePuncher {
  HolePuncher({
    required this.host,
    this.directDialTimeout = const Duration(seconds: 10),
    this.listenAddrs,
  });

  final Host host;
  final Duration directDialTimeout;
  final List<Multiaddr> Function()? listenAddrs;

  final Set<PeerId> _active = {};
  bool _closed = false;

  bool isPeerActive(PeerId peer) => _active.contains(peer);

  Future<void> close() async {
    _closed = true;
    _active.clear();
  }

  /// Initiates a DCUtR hole punch to [remotePeer].
  Future<bool> initiateHolePunch(
    PeerId remotePeer,
    List<Multiaddr> peerAddrs,
  ) async {
    if (_closed) return false;
    if (_active.contains(remotePeer)) return false;
    _active.add(remotePeer);

    try {
      // Step 1: Open /libp2p/dcutr stream over the existing connection
      final stream = await host.newStream(
        remotePeer,
        [holePunchProtocol],
        context: NetworkContext(dialPeerTimeout: directDialTimeout),
      ).timeout(directDialTimeout);

      try {
        // Step 2: Send CONNECT with our direct addresses
        final ownAddrs = listenAddrs?.call() ?? host.addrs;
        final filteredOwn = ownAddrs.where((a) => !isRelayAddress(a)).toList();
        final connectMsg = HolePunchMessage(
          type: HolePunchMessageType.connect,
          obsAddrs: filteredOwn.map((a) => a.toBytes()).toList(),
        );
        final tstart = DateTime.now();
        await HolePunchService._writeDelimited(stream, connectMsg.marshal());

        // Step 3: Receive CONNECT response from receiver
        final rawResp = await HolePunchService._readDelimited(stream);
        if (rawResp == null) return false;
        final resp = HolePunchMessage.unmarshal(rawResp);
        if (resp.type != HolePunchMessageType.connect) return false;

        final rtt = DateTime.now().difference(tstart);

        // Step 4: Send SYNC message
        final syncMsg = HolePunchMessage(type: HolePunchMessageType.sync);
        await HolePunchService._writeDelimited(stream, syncMsg.marshal());

        // Step 5: Wait rtt / 2 for sync packet propagation
        final halfRtt = Duration(
          microseconds: (rtt.inMicroseconds / 2).round().clamp(10000, 500000),
        );
        await Future<void>.delayed(halfRtt);

        await stream.close();

        // Step 6: Simultaneously dial remote peer direct addresses
        final remoteDirectAddrs = <Multiaddr>[];
        for (final b in resp.obsAddrs) {
          try {
            final ma = Multiaddr.fromBytes(b);
            if (!isRelayAddress(ma)) remoteDirectAddrs.add(ma);
          } catch (_) {}
        }
        if (peerAddrs.isNotEmpty) {
          for (final a in peerAddrs) {
            if (!isRelayAddress(a) && !remoteDirectAddrs.contains(a)) {
              remoteDirectAddrs.add(a);
            }
          }
        }

        if (remoteDirectAddrs.isNotEmpty) {
          host.peerstore.addAddrs(
            remotePeer,
            remoteDirectAddrs,
            const Duration(minutes: 5),
          );
          await host.connect(
            AddrInfo(id: remotePeer, addrs: remoteDirectAddrs),
          ).timeout(directDialTimeout);
          return true;
        }
        return false;
      } finally {
        try {
          await stream.close();
        } catch (_) {}
      }
    } catch (_) {
      return false;
    } finally {
      _active.remove(remotePeer);
    }
  }
}
