part of '../../net.dart';

/// `IPv4(a, b, c, d)`: o IPv4 na forma de 16 bytes.
IP iPv4(Golang.Uint8 a, Golang.Uint8 b, Golang.Uint8 c, Golang.Uint8 d) =>
    _ipv4(a.toInt(), b.toInt(), c.toInt(), d.toInt());

IP _ipv4(int a, int b, int c, int d) =>
    IP(_bytes([..._v4InV6Prefix, a, b, c, d]));

const _v4InV6Prefix = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff];

/// `IPv4bcast`: 255.255.255.255.
final IP iPv4bcast = _ipv4(255, 255, 255, 255);

/// `IPv4allsys`: 224.0.0.1.
final IP iPv4allsys = _ipv4(224, 0, 0, 1);

/// `IPv4allrouter`: 224.0.0.2.
final IP iPv4allrouter = _ipv4(224, 0, 0, 2);

/// `IPv4zero`: 0.0.0.0.
final IP iPv4zero = _ipv4(0, 0, 0, 0);

/// `IPv6zero`: ::.
final IP iPv6zero = IP(_bytes(List.filled(16, 0)));

/// `IPv6unspecified`: ::.
final IP iPv6unspecified = IP(_bytes(List.filled(16, 0)));

/// `IPv6loopback`: ::1.
final IP iPv6loopback = IP(_bytes([...List.filled(15, 0), 1]));

/// `IPv6interfacelocalallnodes`: ff01::1.
final IP iPv6interfacelocalallnodes = IP(
  _bytes([0xff, 0x01, ...List.filled(13, 0), 0x01]),
);

/// `IPv6linklocalallnodes`: ff02::1.
final IP iPv6linklocalallnodes = IP(
  _bytes([0xff, 0x02, ...List.filled(13, 0), 0x01]),
);

/// `IPv6linklocalallrouters`: ff02::2.
final IP iPv6linklocalallrouters = IP(
  _bytes([0xff, 0x02, ...List.filled(13, 0), 0x02]),
);

bool _isZeros(_Bytes p, int from, int to) {
  for (var i = from; i < to; i++) {
    if (p[i].toInt() != 0) return false;
  }
  return true;
}

bool _allFF(_Bytes b, int from, int to) {
  for (var i = from; i < to; i++) {
    if (b[i].toInt() != 0xff) return false;
  }
  return true;
}

/// `bytealg.Equal(b[off:off+len(want)], want)` (b tem bytes suficientes).
bool _equalAt(_Bytes b, int off, List<int> want) {
  if (b.length - off < want.length) return false;
  for (var i = 0; i < want.length; i++) {
    if (b[off + i].toInt() != want[i]) return false;
  }
  return true;
}

/// `ParseIP(s)`: IPv4, IPv6 ou IPv4 mapeado (sem zona); nil se inválido. O
/// resultado tem sempre 16 bytes.
IP parseIP(Golang.String s) {
  final (addr, err) = netip.parseAddr(s);
  if (err != null || addr.zone().length != 0) return IP(Slice.nil(_byteElem));
  return IP(addr.as16().slice(0));
}

/// `ParseCIDR(s)`: o IP e a rede de `a.b.c.d/n` ou `x::/n`.
(IP, IPNet?, GoError?) parseCIDR(Golang.String s) {
  final nilIP = IP(Slice.nil(_byteElem));
  final i = _indexByte(s, 0x2f);
  if (i < 0) {
    return (nilIP, null, ParseError(type: _gs('CIDR address'), text: s));
  }
  final addr = s.slice(0, i), mask = s.slice(i + 1);
  final (ipAddr, err) = netip.parseAddr(addr);
  if (err != null || ipAddr.zone().length != 0) {
    return (nilIP, null, ParseError(type: _gs('CIDR address'), text: s));
  }
  final bitLen = ipAddr.bitLen().toInt();
  final (n, j, ok) = _dtoi(mask);
  if (!ok || j != mask.length || n < 0 || n > bitLen) {
    return (nilIP, null, ParseError(type: _gs('CIDR address'), text: s));
  }
  final m = _cidrMask(n, bitLen);
  final addr16 = ipAddr.as16();
  return (
    IP(addr16.slice(0)),
    IPNet(ip: IP(addr16.slice(0)).mask(m), mask: m),
    null,
  );
}
