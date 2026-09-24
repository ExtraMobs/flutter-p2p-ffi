// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';

import 'package:boilerplate/net/golang.dart' as net;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    as pion_transport;

import '../../../core/network/network.dart';
import '../../../core/transport/transport.dart';
import 'udpmux/mux.dart';

/// ConnMultiaddrs holds the local and remote multiaddresses for a connection.
class ConnMultiaddrs {
  ConnMultiaddrs({required this.local, required this.remote});
  final Multiaddr local;
  final Multiaddr remote;

  Multiaddr localMultiaddr() => local;
  Multiaddr remoteMultiaddr() => remote;
}

/// WebRtcListener listens for incoming WebRTC Direct connections.
class WebRtcListener implements Listener {
  WebRtcListener({
    required this.transportInstance,
    required this.mux,
    required this.boundAddr,
    required this.socket,
  });

  final Transport transportInstance;
  final UdpMux mux;
  final Multiaddr boundAddr;
  final dynamic socket;

  bool _closed = false;
  final List<CapableConn> _acceptQueue = [];
  Completer<CapableConn>? _acceptWaiter;

  @override
  Future<CapableConn> accept() async {
    if (_closed) throw StateError('Listener closed');
    if (_acceptQueue.isNotEmpty) {
      return _acceptQueue.removeAt(0);
    }
    _acceptWaiter = Completer<CapableConn>();
    return _acceptWaiter!.future;
  }

  void pushAccepted(CapableConn conn) {
    if (_closed) return;
    final waiter = _acceptWaiter;
    _acceptWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(conn);
    } else {
      _acceptQueue.add(conn);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await mux.close();
    final waiter = _acceptWaiter;
    _acceptWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(StateError('Listener closed'));
    }
  }

  @override
  dynamic addr() {
    if (socket is RawDatagramSocket) {
      final s = socket as RawDatagramSocket;
      return pion_transport.UdpAddr(s.address, s.port);
    }
    return null;
  }

  @override
  Multiaddr multiaddr() => boundAddr;
}
