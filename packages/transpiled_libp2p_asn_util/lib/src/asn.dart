part of '../transpiled_libp2p_asn_util.dart';

// Port of github.com/libp2p/go-libp2p-asn-util/asn.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// Go stdlib's `net.IP` is stood in for by
// `package:boilerplate/net/golang.dart`'s `Ip`, the same faithful port
// already used by `transpiled_multiaddr`'s `manet` and by
// `transpiled_libp2p`'s `conngater.dart` (see that file's header for why,
// not `dart:io`'s `InternetAddress`, is the correct stand-in).

/// Bytes per (start, end, asn) entry: two 8-byte unsigned integers plus a
/// 4-byte one. Equivalent to go-libp2p-asn-util's private `entrySize`.
const int _entrySize = 8 * 2 + 4;

final Uint8List _datasetBytes = base64Decode(sortedNetworkListBase64);

/// Reads the little-endian (start, end, asn) triple at [index] out of the
/// embedded dataset. Equivalent to go-libp2p-asn-util's private
/// `readEntry`.
///
/// Go's own on-disk layout stores these fields little-endian (each byte
/// shifted up, from `b[0]` unshifted to `b[7]` shifted by 56) even though
/// the *address itself* is read big-endian by [asnForIpv6] below -- both
/// sides are reproduced exactly as upstream wrote them, not unified.
(Golang.Uint64 start, Golang.Uint64 end, int asn) _readEntry(int index) {
  final base = _entrySize * index;
  final start = Golang.Uint64.fromBigInt(_readUint64Le(base));
  final end = Golang.Uint64.fromBigInt(_readUint64Le(base + 8));
  final asn = _readUint32Le(base + 16);
  return (start, end, asn);
}

BigInt _readUint64Le(int offset) {
  var value = BigInt.zero;
  for (var i = 7; i >= 0; i--) {
    value = (value << 8) | BigInt.from(_datasetBytes[offset + i]);
  }
  return value;
}

int _readUint32Le(int offset) {
  var value = 0;
  for (var i = 3; i >= 0; i--) {
    value = (value << 8) | _datasetBytes[offset + i];
  }
  return value;
}

/// The first 8 bytes of [addr] (a 16-byte IPv6 address) as a big-endian
/// unsigned integer -- the "network" key [asnForIpv6Network] looks up.
Golang.Uint64 _networkPrefix(Uint8List addr) {
  var value = BigInt.zero;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | BigInt.from(addr[i]);
  }
  return Golang.Uint64.fromBigInt(value);
}

/// The 16-byte IPv4-in-IPv6-mapped form of a 4-byte address
/// (`::ffff:a.b.c.d`), matching what Go's `net.IP.To16()` produces for an
/// IPv4 address.
/// The AS number for [ip], or `0` if no mapping exists for its network, or
/// if [ip] is neither IPv4- nor IPv6-capable (Go: `ip.To16()` is nil --
/// reachable here since [Ip] can hold a byte slice of any length, exactly
/// like Go's `net.IP`). [ip] may be IPv4 or IPv6 (an IPv4 address is
/// looked up by its IPv4-in-IPv6-mapped form, matching Go's
/// `net.IP.To16()` widening, though in practice no entry ever matches
/// one). Equivalent to go-libp2p-asn-util's `AsnForIPv6`.
int asnForIpv6(Ip ip) {
  final v6 = ip.to16();
  if (v6 == null) return 0;
  return asnForIpv6Network(_networkPrefix(v6.asBytes()));
}

/// The AS number for the given 64-bit IPv6 network prefix (the address's
/// first 64 bits, big-endian), or `0` if no mapping exists. Equivalent to
/// go-libp2p-asn-util's `AsnForIPv6Network`.
///
/// [network] is [Golang.Uint64] rather than a plain `int` because the
/// binary search below compares it against dataset boundaries using
/// *unsigned* 64-bit ordering (many real IPv6 allocations have their top
/// bit set) -- a plain Dart `int` compared with `<=` would silently
/// misorder those under native, signed 64-bit comparison.
int asnForIpv6Network(Golang.Uint64 network) {
  assert(
    _datasetBytes.length <= 1 << 62,
    'embedded ASN dataset too large for binary search',
  );
  final n = _datasetBytes.length ~/ _entrySize;
  var i = 0;
  var j = n;
  while (i < j) {
    final h = (i + j) ~/ 2;
    final (start, end, asn) = _readEntry(h);
    if (start <= network) {
      if (network <= end) return asn;
      i = h + 1;
    } else {
      j = h;
    }
  }
  if (i >= n) return 0;
  final (start, end, asn) = _readEntry(i);
  if (start <= network && network <= end) return asn;
  return 0;
}

// go-libp2p-asn-util's exported `Store` variable and its unexported
// `backwardCompat` type are ported in the sibling `asn_store.dart`, kept
// out of this barrel's part list -- see that file's header for why.
