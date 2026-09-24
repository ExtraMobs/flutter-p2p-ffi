// Package ice activeTCPConn implementation.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';
import 'addr.dart';

/// activeTCPConn wraps an active TCP connection conforming to PacketConn.
class ActiveTcpConn implements PacketConn {
  Socket? _socket;
  NetAddr? _localAddr;
  NetAddr? _remoteAddr;
  bool _closed = false;

  final List<int> _readBuffer = <int>[];

  ActiveTcpConn({Socket? socket, NetAddr? localAddr, NetAddr? remoteAddr})
    : _socket = socket,
      _localAddr = localAddr,
      _remoteAddr = remoteAddr {
    if (socket != null) {
      _localAddr ??= TcpAddr(socket.address, socket.port);
      _remoteAddr ??= TcpAddr(socket.remoteAddress, socket.remotePort);
      socket.listen(
        (data) => _readBuffer.addAll(data),
        onDone: () => close(),
        onError: (_) => close(),
      );
    }
  }

  @override
  NetAddr get localAddr => _localAddr ?? TcpAddr(InternetAddress.anyIPv4, 0);

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
    final n = b.length < _readBuffer.length ? b.length : _readBuffer.length;
    for (var i = 0; i < n; i++) {
      b[i] = _readBuffer.removeAt(0);
    }
    return (n, _remoteAddr ?? TcpAddr(InternetAddress.anyIPv4, 0));
  }

  Future<int> writeTo(Uint8List b, NetAddr addr) async {
    if (_closed) throw const SocketException('Connection closed');
    if (_socket != null) {
      _socket!.add(b);
      await _socket!.flush();
    }
    return b.length;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _socket?.close();
  }

  void setDeadline(DateTime? t) {}
  void setReadDeadline(DateTime? t) {}
  void setWriteDeadline(DateTime? t) {}
}
