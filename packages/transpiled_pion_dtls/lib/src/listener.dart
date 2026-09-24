import 'dart:async';
import 'dart:io';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetAddr, NetConn, UdpAddr;

import 'config.dart';
import 'conn.dart';

/// Listener represents a DTLS listener.
class Listener {
  final dynamic _parent;
  final Config _config;
  bool _closed = false;

  Listener(dynamic inner, Config config) : _parent = inner, _config = config;

  factory Listener.withOptions(
    dynamic inner, [
    List<ServerOption> opts = const [],
  ]) {
    final config = Config();
    for (final opt in opts) {
      opt.apply(config);
    }
    return Listener(inner, config);
  }

  /// Accept waits for and returns the next connection to the listener.
  Future<NetConn> accept() async {
    if (_closed) throw StateError('listener closed');
    if (_parent != null) {
      final (c, raddr) = await _parent.accept();
      return server(c, raddr, _config);
    }
    throw StateError('parent listener is null');
  }

  /// Close closes the listener.
  Future<void> close() async {
    _closed = true;
    if (_parent != null) {
      await _parent.close();
    }
  }

  /// Addr returns the listener's network address.
  NetAddr addr() {
    if (_parent != null) {
      return _parent.addr();
    }
    return UdpAddr(InternetAddress.anyIPv4, 0);
  }
}

/// Listen creates a DTLS listener.
Future<Listener> listen(String network, dynamic laddr, Config config) async {
  return Listener(null, config);
}

/// ListenWithOptions creates a DTLS listener with options.
Future<Listener> listenWithOptions(
  String network,
  dynamic laddr, [
  List<ServerOption> opts = const [],
]) async {
  final config = Config();
  for (final opt in opts) {
    opt.apply(config);
  }
  return listen(network, laddr, config);
}

/// ListenerWithOptions creates a DTLS listener with options.
Listener listenerWithOptions(
  dynamic inner, [
  List<ServerOption> opts = const [],
]) {
  final config = Config();
  for (final opt in opts) {
    opt.apply(config);
  }
  return Listener(inner, config);
}
