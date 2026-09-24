// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart' as net;
import 'package:transpiled_pion_stun/transpiled_pion_stun.dart' as pion_stun;
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    as pion_transport;

const String ufragPrefixV1 = 'libp2p+webrtc+v1/';
const String ufragPrefixV2 = 'libp2p+webrtc+v2/';

/// Candidate represents an incoming connection candidate inferred from STUN checks.
class Candidate {
  Candidate({
    required this.localUfrag,
    required this.remoteUfrag,
    required this.remotePwd,
    required this.addr,
  });

  String localUfrag;
  String remoteUfrag;
  String remotePwd;
  dynamic addr;
}

class _UfragConnKey {
  _UfragConnKey(this.ufrag, this.isIPv6);
  final String ufrag;
  final bool isIPv6;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UfragConnKey &&
          runtimeType == other.runtimeType &&
          ufrag == other.ufrag &&
          isIPv6 == other.isIPv6;

  @override
  int get hashCode => Object.hash(ufrag, isIPv6);
}

/// MuxedConnection represents a single multiplexed connection over the shared UDP socket.
class MuxedConnection {
  MuxedConnection({required this.mux, required this.ufrag, required this.addr});

  final UdpMux mux;
  final String ufrag;
  final dynamic addr;

  final List<(Uint8List, dynamic)> _inboundQueue = [];
  Completer<void>? _readWaiter;
  bool _closed = false;

  DateTime? _readDeadline;
  DateTime? _writeDeadline;

  void push(Uint8List buf, dynamic fromAddr) {
    if (_closed) return;
    _inboundQueue.add((Uint8List.fromList(buf), fromAddr));
    final waiter = _readWaiter;
    _readWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<(int, dynamic)> readFrom(Uint8List p) async {
    while (_inboundQueue.isEmpty) {
      if (_closed) throw StateError('MuxedConnection closed');
      if (_readDeadline != null && DateTime.now().isAfter(_readDeadline!)) {
        throw TimeoutException('read deadline reached');
      }
      _readWaiter = Completer<void>();
      await _readWaiter!.future;
    }
    final (chunk, from) = _inboundQueue.removeAt(0);
    final toCopy = chunk.length > p.length ? p.length : chunk.length;
    p.setRange(0, toCopy, chunk);
    return (toCopy, from);
  }

  Future<int> writeTo(Uint8List p, dynamic toAddr) async {
    if (_closed) throw StateError('MuxedConnection closed');
    return mux._writeDirect(p, toAddr);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    mux.removeConnByUfrag(ufrag);
    final waiter = _readWaiter;
    _readWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  dynamic localAddr() => mux.socket is RawDatagramSocket
      ? (mux.socket as RawDatagramSocket).address
      : null;

  void setDeadline(DateTime? t) {
    setReadDeadline(t);
    setWriteDeadline(t);
  }

  void setReadDeadline(DateTime? t) {
    _readDeadline = t;
  }

  void setWriteDeadline(DateTime? t) {
    _writeDeadline = t;
  }
}

/// UdpMux multiplexes multiple ICE connections over a single UDP socket.
class UdpMux {
  UdpMux(this.socket) {
    start();
  }

  final dynamic socket;
  bool _closed = false;

  final Map<_UfragConnKey, MuxedConnection> _ufragMap = {};
  final Map<String, MuxedConnection> _addrMap = {};
  final List<Candidate> _acceptQueue = [];
  Completer<Candidate>? _acceptWaiter;

  void start() {
    if (socket is RawDatagramSocket) {
      final s = socket as RawDatagramSocket;
      s.listen((event) {
        if (event == RawSocketEvent.read) {
          while (true) {
            final datagram = s.receive();
            if (datagram == null) break;
            _handlePacket(datagram.data, datagram.address, datagram.port);
          }
        }
      });
    }
  }

  Future<int> _writeDirect(Uint8List p, dynamic toAddr) async {
    if (socket is RawDatagramSocket) {
      final s = socket as RawDatagramSocket;
      if (toAddr is InternetAddress) {
        return s.send(p, toAddr, 0);
      } else if (toAddr is pion_transport.UdpAddr) {
        return s.send(p, toAddr.ip, toAddr.port.toInt());
      }
    }
    return p.length;
  }

  void _handlePacket(Uint8List data, InternetAddress fromIp, int fromPort) {
    final addrKey = '${fromIp.address}:$fromPort';
    final existing = _addrMap[addrKey];
    if (existing != null) {
      existing.push(data, fromIp);
      return;
    }

    // Check if it is a STUN packet
    if (pion_stun.isMessage(data)) {
      final msg = pion_stun.Message();
      try {
        msg.raw = data;
        msg.decode();

        // Extract USERNAME attribute
        final usernameAttr = msg.get(pion_stun.attrUsername);
        if (usernameAttr != null) {
          final username = String.fromCharCodes(usernameAttr.value);
          final parts = username.split(':');
          if (parts.isNotEmpty) {
            final localUfrag = parts[0];
            final remoteUfrag = parts.length > 1 ? parts[1] : localUfrag;
            String remotePwd = remoteUfrag;
            if (localUfrag.startsWith(ufragPrefixV2)) {
              remotePwd = localUfrag.substring(ufragPrefixV2.length);
            }

            final key = _UfragConnKey(
              localUfrag,
              fromIp.type == InternetAddressType.IPv6,
            );
            var conn = _ufragMap[key];
            if (conn == null) {
              conn = MuxedConnection(
                mux: this,
                ufrag: localUfrag,
                addr: fromIp,
              );
              _ufragMap[key] = conn;

              final cand = Candidate(
                localUfrag: localUfrag,
                remoteUfrag: remoteUfrag,
                remotePwd: remotePwd,
                addr: pion_transport.UdpAddr(fromIp, fromPort),
              );

              final waiter = _acceptWaiter;
              _acceptWaiter = null;
              if (waiter != null && !waiter.isCompleted) {
                waiter.complete(cand);
              } else {
                _acceptQueue.add(cand);
              }
            }

            _addrMap[addrKey] = conn;
            conn.push(data, fromIp);
          }
        }
      } catch (_) {}
    }
  }

  List<dynamic> getListenAddresses() {
    if (socket is RawDatagramSocket) {
      final s = socket as RawDatagramSocket;
      return [pion_transport.UdpAddr(s.address, s.port)];
    }
    return [];
  }

  MuxedConnection? getConn(String ufrag, dynamic addr) {
    final isIPv6 = addr is InternetAddress
        ? addr.type == InternetAddressType.IPv6
        : false;
    final key = _UfragConnKey(ufrag, isIPv6);
    return _ufragMap[key];
  }

  Future<Candidate> accept() async {
    if (_closed) throw StateError('UdpMux closed');
    if (_acceptQueue.isNotEmpty) {
      return _acceptQueue.removeAt(0);
    }
    _acceptWaiter = Completer<Candidate>();
    return _acceptWaiter!.future;
  }

  void removeConnByUfrag(String ufrag) {
    _ufragMap.removeWhere((k, _) => k.ufrag == ufrag);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _ufragMap.clear();
    _addrMap.clear();
    if (socket is RawDatagramSocket) {
      (socket as RawDatagramSocket).close();
    }
    final waiter = _acceptWaiter;
    _acceptWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(StateError('UdpMux closed'));
    }
  }
}
