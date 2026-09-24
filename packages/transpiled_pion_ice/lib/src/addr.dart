// Package ice address parsing and errors.
library;

import 'dart:io';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';
import 'networktype.dart';

/// TcpAddr represents a TCP network end point address.
class TcpAddr implements NetAddr {
  final InternetAddress address;
  final int port;
  final String zone;

  const TcpAddr(this.address, this.port, [this.zone = '']);

  @override
  String get network => 'tcp';

  @override
  String toString() => zone.isEmpty
      ? '${address.address}:$port'
      : '${address.address}%$zone:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TcpAddr &&
          other.address == address &&
          other.port == port &&
          other.zone == zone);

  @override
  int get hashCode => Object.hash(address, port, zone);
}

/// addrParseError represents an error parsing an address.
class AddrParseException implements Exception {
  final NetAddr? addr;

  const AddrParseException([this.addr]);

  String error() => 'do not know how to parse address type ${addr.runtimeType}';

  @override
  String toString() => error();
}

/// ipConvertError represents an error converting an IP.
class IpConvertException implements Exception {
  final List<int> ip;

  const IpConvertException([this.ip = const []]);

  String error() => 'failed to convert IP $ip to InternetAddress';

  @override
  String toString() => error();
}

/// parseAddr extracts IP, port, and NetworkType from an NetAddr.
(InternetAddress ip, int port, NetworkType networkType) parseAddr(NetAddr in_) {
  if (in_ is UdpAddr) {
    final ip = in_.address;
    final nt = ip.type == InternetAddressType.IPv4
        ? NetworkType.udp4
        : NetworkType.udp6;
    return (ip, in_.port, nt);
  } else if (in_ is TcpAddr) {
    final ip = in_.address;
    final nt = ip.type == InternetAddressType.IPv4
        ? NetworkType.tcp4
        : NetworkType.tcp6;
    return (ip, in_.port, nt);
  }
  throw AddrParseException(in_);
}

/// addrEqual compares two NetAddrs for equality.
bool addrEqual(NetAddr a, NetAddr b) {
  try {
    final (aIp, aPort, aNt) = parseAddr(a);
    final (bIp, bPort, bNt) = parseAddr(b);
    return aNt == bNt && aIp.address == bIp.address && aPort == bPort;
  } catch (_) {
    return false;
  }
}
