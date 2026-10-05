part of '../../../net/netip.dart';

/// `IPv6LinkLocalAllNodes()`: ff02::1.
Addr iPv6LinkLocalAllNodes() =>
    _addrFrom16Bytes([0xff, 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]);

/// `IPv6LinkLocalAllRouters()`: ff02::2.
Addr iPv6LinkLocalAllRouters() =>
    _addrFrom16Bytes([0xff, 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]);

/// `IPv6Loopback()`: ::1.
Addr iPv6Loopback() =>
    _addrFrom16Bytes([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]);

/// `IPv6Unspecified()`: ::.
Addr iPv6Unspecified() => Addr._(_U128.zero, _z6noz);

/// `IPv4Unspecified()`: 0.0.0.0.
Addr iPv4Unspecified() => _addrFrom4Bytes(const [0, 0, 0, 0]);

Addr _addrFrom4Bytes(List<int> a) => Addr._(
  _U128(_zero64, (Golang.Uint64(0xffff) << 32) | Golang.Uint64(_be32(a, 0))),
  _z4,
);

Addr _addrFrom16Bytes(List<int> a) =>
    Addr._(_U128(_beUint64(a, 0), _beUint64(a, 8)), _z6noz);

List<int> _arrayBytes(GoArray<Golang.Uint8> a, int n) => [
  for (var i = 0; i < n; i++) a[i].toInt(),
];

/// `AddrFrom4(addr)`.
Addr addrFrom4(GoArray<Golang.Uint8> addr) =>
    _addrFrom4Bytes(_arrayBytes(addr, 4));

/// `AddrFrom16(addr)`: o IPv4 mapeado continua IPv6.
Addr addrFrom16(GoArray<Golang.Uint8> addr) =>
    _addrFrom16Bytes(_arrayBytes(addr, 16));

/// `AddrFromSlice(slice)`: 4 ou 16 bytes; senão `(Addr{}, false)`.
(Addr, bool) addrFromSlice(_Bytes slice) {
  switch (slice.length) {
    case 4:
      return (_addrFrom4Bytes(_bytesOf(slice)), true);
    case 16:
      return (_addrFrom16Bytes(_bytesOf(slice)), true);
  }
  return (Addr(), false);
}
