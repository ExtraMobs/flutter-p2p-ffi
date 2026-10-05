part of '../../net.dart';

/// `net.Addr`: endereço de rede (`Network()` e `String()`).
abstract interface class Addr implements Stringer {
  Golang.String network();
}

/// `JoinHostPort(host, port)`: `[host]:port` se host tem `:`.
Golang.String joinHostPort(Golang.String host, Golang.String port) {
  if (_indexByte(host, 0x3a) >= 0) {
    return _gs('[') + host + _gs(']:') + port;
  }
  return host + _gs(':') + port;
}

/// `SplitHostPort(hostport)`: separa `host:port`, `[host]:port` ou
/// `[host%zone]:port`.
(Golang.String, Golang.String, GoError?) splitHostPort(Golang.String hostport) {
  const missingPort = 'missing port in address';
  const tooManyColons = 'too many colons in address';
  (Golang.String, Golang.String, GoError?) addrErr(
    Golang.String addr,
    String why,
  ) => (Golang.String(), Golang.String(), AddrError(err: _gs(why), addr: addr));
  var j = 0, k = 0;
  final i = _lastIndexByte(hostport, 0x3a);
  if (i < 0) return addrErr(hostport, missingPort);
  Golang.String host;
  if (hostport[0] == 0x5b) {
    final end = _indexByte(hostport, 0x5d);
    if (end < 0) return addrErr(hostport, "missing ']' in address");
    if (end + 1 == hostport.length) {
      return addrErr(hostport, missingPort);
    } else if (end + 1 != i) {
      if (hostport[end + 1] == 0x3a) return addrErr(hostport, tooManyColons);
      return addrErr(hostport, missingPort);
    }
    host = hostport.slice(1, end);
    j = 1;
    k = end + 1;
  } else {
    host = hostport.slice(0, i);
    if (_indexByte(host, 0x3a) >= 0) return addrErr(hostport, tooManyColons);
  }
  if (_indexByte(hostport.slice(j), 0x5b) >= 0) {
    return addrErr(hostport, "unexpected '[' in address");
  }
  if (_indexByte(hostport.slice(k), 0x5d) >= 0) {
    return addrErr(hostport, "unexpected ']' in address");
  }
  return (host, hostport.slice(i + 1), null);
}

/// `String()` de TCPAddr/UDPAddr: `host:port`, com a zona.
Golang.String _hostPortString(IP ip, Golang.String zone, Golang.Int port) {
  final s = _ipEmptyString(ip);
  if (zone.length != 0) {
    return joinHostPort(s + _gs('%') + zone, strconv.itoa(port));
  }
  return joinHostPort(s, strconv.itoa(port));
}

/// `AddrPort()` de TCPAddr/UDPAddr.
netip.AddrPort _addrPortOf(IP ip, Golang.String zone, Golang.Int port) {
  var (na, _) = netip.addrFromSlice(ip);
  na = na.withZone(zone);
  return netip.addrPortFrom(na, Golang.Uint16.from(port));
}

/// `net.TCPAddr`: endereço de um ponto TCP.
final class TCPAddr extends GoStruct<TCPAddr> implements Addr {
  TCPAddr({IP? ip, Golang.Int? port, Golang.String? zone})
    : ip = ip ?? IP(Slice.nil(_byteElem)),
      port = port ?? Golang.Int(),
      zone = zone ?? Golang.String();

  /// `(*TCPAddr)(nil)` dentro de uma interface.
  static final TCPAddr $nil = TCPAddr()..$nilPtr = true;

  IP ip;
  Golang.Int port;

  /// `Zone`: zona IPv6.
  Golang.String zone;

  @override
  String get $goType => 'net.TCPAddr';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['AddrPort', 'Network', 'String'];
  @override
  TCPAddr $copy() => TCPAddr(ip: ip, port: port, zone: zone);
  @override
  void $set(TCPAddr o) {
    ip = o.ip;
    port = o.port;
    zone = o.zone;
  }

  @override
  List<Object?> get $fields => [ip, port, zone];
  @override
  List<String> get $fieldNames => const ['IP', 'Port', 'Zone'];
  @override
  List<String> get $fieldTypes => const ['net.IP', 'int', 'string'];

  /// `AddrPort()`: o zero para o ponteiro nil.
  netip.AddrPort addrPort() =>
      $nilPtr ? netip.AddrPort() : _addrPortOf(ip, zone, port);

  /// `Network()`: `tcp`.
  @override
  Golang.String network() => _gs('tcp');

  /// `String()`.
  @override
  Golang.String string() =>
      $nilPtr ? _gs('<nil>') : _hostPortString(ip, zone, port);
}

/// `TCPAddrFromAddrPort(addr)`.
TCPAddr tcpAddrFromAddrPort(netip.AddrPort addr) => TCPAddr(
  ip: IP(addr.addr$().asSlice()),
  zone: addr.addr$().zone(),
  port: Golang.Int.from(addr.port()),
);

/// `net.UDPAddr`: endereço de um ponto UDP.
final class UDPAddr extends GoStruct<UDPAddr> implements Addr {
  UDPAddr({IP? ip, Golang.Int? port, Golang.String? zone})
    : ip = ip ?? IP(Slice.nil(_byteElem)),
      port = port ?? Golang.Int(),
      zone = zone ?? Golang.String();

  /// `(*UDPAddr)(nil)` dentro de uma interface.
  static final UDPAddr $nil = UDPAddr()..$nilPtr = true;

  IP ip;
  Golang.Int port;

  /// `Zone`: zona IPv6.
  Golang.String zone;

  @override
  String get $goType => 'net.UDPAddr';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['AddrPort', 'Network', 'String'];
  @override
  UDPAddr $copy() => UDPAddr(ip: ip, port: port, zone: zone);
  @override
  void $set(UDPAddr o) {
    ip = o.ip;
    port = o.port;
    zone = o.zone;
  }

  @override
  List<Object?> get $fields => [ip, port, zone];
  @override
  List<String> get $fieldNames => const ['IP', 'Port', 'Zone'];
  @override
  List<String> get $fieldTypes => const ['net.IP', 'int', 'string'];

  /// `AddrPort()`: o zero para o ponteiro nil.
  netip.AddrPort addrPort() =>
      $nilPtr ? netip.AddrPort() : _addrPortOf(ip, zone, port);

  /// `Network()`: `udp`.
  @override
  Golang.String network() => _gs('udp');

  /// `String()`.
  @override
  Golang.String string() =>
      $nilPtr ? _gs('<nil>') : _hostPortString(ip, zone, port);
}

/// `UDPAddrFromAddrPort(addr)`.
UDPAddr udpAddrFromAddrPort(netip.AddrPort addr) => UDPAddr(
  ip: IP(addr.addr$().asSlice()),
  zone: addr.addr$().zone(),
  port: Golang.Int.from(addr.port()),
);

/// `net.IPAddr`: endereço IP (sem porta).
final class IPAddr extends GoStruct<IPAddr> implements Addr {
  IPAddr({IP? ip, Golang.String? zone})
    : ip = ip ?? IP(Slice.nil(_byteElem)),
      zone = zone ?? Golang.String();

  /// `(*IPAddr)(nil)` dentro de uma interface.
  static final IPAddr $nil = IPAddr()..$nilPtr = true;

  IP ip;

  /// `Zone`: zona IPv6.
  Golang.String zone;

  @override
  String get $goType => 'net.IPAddr';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Network', 'String'];
  @override
  IPAddr $copy() => IPAddr(ip: ip, zone: zone);
  @override
  void $set(IPAddr o) {
    ip = o.ip;
    zone = o.zone;
  }

  @override
  List<Object?> get $fields => [ip, zone];
  @override
  List<String> get $fieldNames => const ['IP', 'Zone'];
  @override
  List<String> get $fieldTypes => const ['net.IP', 'string'];

  /// `Network()`: `ip`.
  @override
  Golang.String network() => _gs('ip');

  /// `String()`: `ip` ou `ip%zona`.
  @override
  Golang.String string() {
    if ($nilPtr) return _gs('<nil>');
    final s = _ipEmptyString(ip);
    if (zone.length != 0) return s + _gs('%') + zone;
    return s;
  }
}

/// `net.UnixAddr`: endereço de socket Unix.
final class UnixAddr extends GoStruct<UnixAddr> implements Addr {
  UnixAddr({Golang.String? name, Golang.String? net})
    : name = name ?? Golang.String(),
      net = net ?? Golang.String();

  /// `(*UnixAddr)(nil)` dentro de uma interface.
  static final UnixAddr $nil = UnixAddr()..$nilPtr = true;

  Golang.String name;
  Golang.String net;

  @override
  String get $goType => 'net.UnixAddr';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Network', 'String'];
  @override
  UnixAddr $copy() => UnixAddr(name: name, net: net);
  @override
  void $set(UnixAddr o) {
    name = o.name;
    net = o.net;
  }

  @override
  List<Object?> get $fields => [name, net];
  @override
  List<String> get $fieldNames => const ['Name', 'Net'];
  @override
  List<String> get $fieldTypes => const ['string', 'string'];

  /// `Network()`: o campo `Net`.
  @override
  Golang.String network() {
    final UnixAddr? a = $nilPtr ? null : this;
    return a!.net;
  }

  /// `String()`: o campo `Name`.
  @override
  Golang.String string() => $nilPtr ? _gs('<nil>') : name;
}

/// `ResolveUnixAddr(network, address)`.
(UnixAddr?, GoError?) resolveUnixAddr(
  Golang.String network,
  Golang.String address,
) {
  if (network == _gs('unix') ||
      network == _gs('unixgram') ||
      network == _gs('unixpacket')) {
    return (UnixAddr(name: address, net: network), null);
  }
  return (null, UnknownNetworkError(network));
}
