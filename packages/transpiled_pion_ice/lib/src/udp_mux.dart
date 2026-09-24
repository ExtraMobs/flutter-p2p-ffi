// Package ice UdpMux and UdpMuxDefault implementation.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:transpiled_pion_logging/transpiled_pion_logging.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';

/// UdpMux allows multiple ICE connections to go over a single UDP port.
abstract class UdpMux {
  Future<void> close();
  PacketConn getConn(String ufrag, NetAddr addr);
  void removeConnByUfrag(String ufrag);
  List<NetAddr> getListenAddresses();
}

/// UdpMuxParams contains parameters for UdpMuxDefault.
class UdpMuxParams {
  final LeveledLogger? logger;
  final PacketConn? udpConn;
  final String udpConnString;
  final dynamic net;

  const UdpMuxParams({
    this.logger,
    this.udpConn,
    this.udpConnString = '',
    this.net,
  });
}

/// UdpMuxDefault is the default implementation of UdpMux.
class UdpMuxDefault implements UdpMux {
  final UdpMuxParams _params;
  final Map<String, _UdpMuxedConn> _connsByUfrag = {};
  final Map<String, _UdpMuxedConn> _connsByAddr = {};
  bool _closed = false;

  UdpMuxDefault(this._params);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final conn in _connsByUfrag.values) {
      await conn.close();
    }
    _connsByUfrag.clear();
    _connsByAddr.clear();
    await _params.udpConn?.close();
  }

  @override
  PacketConn getConn(String ufrag, NetAddr addr) {
    if (_closed) throw const SocketException('UdpMux is closed');
    final key = '$ufrag:${addr.toString()}';
    if (_connsByAddr.containsKey(key)) {
      return _connsByAddr[key]!;
    }
    final conn = _UdpMuxedConn(
      mux: this,
      ufrag: ufrag,
      remoteAddr: addr,
      parentConn: _params.udpConn,
    );
    _connsByUfrag[ufrag] = conn;
    _connsByAddr[key] = conn;
    return conn;
  }

  @override
  void removeConnByUfrag(String ufrag) {
    final conn = _connsByUfrag.remove(ufrag);
    if (conn != null) {
      _connsByAddr.removeWhere((k, v) => v == conn);
    }
  }

  @override
  List<NetAddr> getListenAddresses() {
    final laddr = _params.udpConn?.localAddr;
    if (laddr != null) return [laddr];
    return [UdpAddr(InternetAddress.anyIPv4, 0)];
  }

  void handlePacket(Uint8List data, NetAddr raddr) {
    for (final conn in _connsByAddr.values) {
      if (conn.remoteAddr() == raddr) {
        conn.enqueuePacket(data, raddr);
        return;
      }
    }
  }
}

class _UdpMuxedConn implements PacketConn {
  final UdpMuxDefault mux;
  final String ufrag;
  final NetAddr _remoteAddr;
  final PacketConn? parentConn;
  final StreamController<(Uint8List, NetAddr)> _incoming =
      StreamController<(Uint8List, NetAddr)>.broadcast();
  bool _closed = false;

  _UdpMuxedConn({
    required this.mux,
    required this.ufrag,
    required NetAddr remoteAddr,
    this.parentConn,
  }) : _remoteAddr = remoteAddr;

  void enqueuePacket(Uint8List data, NetAddr raddr) {
    if (!_closed) {
      _incoming.add((data, raddr));
    }
  }

  @override
  NetAddr get localAddr =>
      parentConn?.localAddr ?? UdpAddr(InternetAddress.anyIPv4, 0);

  NetAddr? remoteAddr() => _remoteAddr;

  @override
  Future<(int, NetAddr)> readFromContext(
    Future<void> cancellation,
    Uint8List buffer,
  ) async {
    return readFrom(buffer);
  }

  @override
  Future<int> writeToContext(
    Future<void> cancellation,
    Uint8List buffer,
    NetAddr addr,
  ) async {
    return writeTo(buffer, addr);
  }

  Future<(int, NetAddr)> readFrom(Uint8List b) async {
    if (_closed) throw const SocketException('Connection closed');
    final (pkt, raddr) = await _incoming.stream.first;
    final n = b.length < pkt.length ? b.length : pkt.length;
    b.setRange(0, n, pkt.sublist(0, n));
    return (n, raddr);
  }

  Future<int> writeTo(Uint8List b, NetAddr addr) async {
    if (_closed) throw const SocketException('Connection closed');
    if (parentConn != null) {
      return parentConn!.writeToContext(Completer<void>().future, b, addr);
    }
    return b.length;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _incoming.close();
    mux.removeConnByUfrag(ufrag);
  }
}
