import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    as pion_transport_v4;

import '../buffer.dart';

/// ListenConfig configures a DTLS UDP listener.
class ListenConfig {
  int backlog;
  bool Function(Uint8List)? acceptFilter;
  (String, bool) Function(Uint8List)? datagramRouter;
  (String, bool) Function(Uint8List)? connectionIdentifier;

  ListenConfig({
    this.backlog = 128,
    this.acceptFilter,
    this.datagramRouter,
    this.connectionIdentifier,
  });

  /// Listen creates a new PacketListener on the specified network and local address.
  Future<dynamic> listen(String network, dynamic laddr) async {
    return null;
  }
}

/// PacketConn implements UDP PacketConn for DTLS.
class PacketConn {
  final PacketBuffer _buffer = PacketBuffer();
  final pion_transport_v4.NetAddr _localAddr;
  pion_transport_v4.NetAddr? _remoteAddr;
  bool _closed = false;

  PacketConn({
    required pion_transport_v4.NetAddr localAddr,
    pion_transport_v4.NetAddr? remoteAddr,
  }) : _localAddr = localAddr,
       _remoteAddr = remoteAddr;

  Future<(int, pion_transport_v4.NetAddr)> readFrom(Uint8List buff) =>
      _buffer.readFrom(buff);

  Future<int> writeTo(Uint8List payload, pion_transport_v4.NetAddr addr) async {
    if (_closed) throw StateError('PacketConn closed');
    return payload.length;
  }

  Future<void> close() async {
    _closed = true;
    _buffer.close();
  }

  pion_transport_v4.NetAddr localAddr() => _localAddr;

  void setDeadline(DateTime? t) {
    setReadDeadline(t);
    setWriteDeadline(t);
  }

  void setReadDeadline(DateTime? t) {
    _buffer.setReadDeadline(t);
  }

  void setWriteDeadline(DateTime? t) {}
}
