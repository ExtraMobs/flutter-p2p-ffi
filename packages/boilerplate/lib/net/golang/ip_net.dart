// ignore_for_file: duplicate_ignore, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'ip.dart';

/// An IP network: an address plus its mask.
///
/// Go: `net.IPNet` (`net/ip.go`).
final class IpNet {
  /// An network with address [ip] and mask [mask].
  const IpNet({required this.ip, required this.mask});

  /// Parses CIDR notation such as `10.0.0.0/8` or `2001:db8::/32`, or returns
  /// null when [text] is not valid CIDR.
  ///
  /// Go: `net.ParseCIDR` (`net/ip.go`), which returns the address, the masked
  /// network and an error. Only the network is returned here, because Rule 8
  /// forbids Go-style error tuples in public APIs; the address that Go returns
  /// first is `Ip.tryParse` of the text before the slash, and this port keeps
  /// Go's behaviour of **masking** the address stored in the result.
  static IpNet? tryParseCidr(String text) {
    final slash = text.indexOf('/');
    if (slash < 0) return null;
    final addr = Ip.tryParse(text.substring(0, slash));
    if (addr == null) return null;
    final ones = int.tryParse(text.substring(slash + 1));
    if (ones == null || ones < 0) return null;

    // Go narrows a dotted-quad to its 4-byte form before building the mask,
    // so `10.0.0.0/8` yields a 4-byte address and a 4-byte mask.
    final v4 = addr.to4();
    final base = v4 ?? addr;
    final bits = base.length * 8;
    if (ones > bits) return null;

    final mask = _cidrMask(ones, bits);
    return IpNet(ip: _maskIp(base, mask), mask: mask);
  }

  /// The network address.
  final Ip ip;

  /// The mask, with the same byte length as [ip] for a network built by
  /// [IpNet.tryParseCidr].
  final Uint8List mask;

  /// Whether the network includes [candidate].
  ///
  /// Go: `IPNet.Contains` (`net/ip.go`). Both sides are narrowed to their
  /// 4-byte form when they have one, which is why an IPv4 network contains the
  /// IPv4-mapped form of one of its addresses -- the opposite of
  /// `netip.Prefix.contains`.
  bool contains(Ip candidate) {
    var (network, m) = _networkNumberAndMask();
    var probe = candidate.to4() ?? candidate;
    final bytes = probe.asBytes();
    final networkBytes = network.asBytes();
    if (bytes.length != networkBytes.length) return false;
    if (m.length != bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if ((networkBytes[i] & m[i]) != (bytes[i] & m[i])) return false;
    }
    return true;
  }

  /// The address and mask narrowed to 4 bytes when the address has an IPv4
  /// form, as Go's unexported `networkNumberAndMask` does.
  (Ip, Uint8List) _networkNumberAndMask() {
    final v4 = ip.to4();
    if (v4 == null) return (ip, mask);
    var m = mask;
    if (m.length == 16) m = Uint8List.fromList(m.sublist(12));
    return (v4, m);
  }

  /// The textual CIDR form.
  ///
  /// Go: `IPNet.String` (`net/ip.go`), which falls back to a hexadecimal mask
  /// when the mask is not a canonical prefix, and prints `<nil>` for a zero
  /// value.
  @override
  String toString() {
    if (ip.isNil && mask.isEmpty) return '<nil>';
    final ones = _maskOnes(mask);
    if (ones == null) {
      final hex = mask.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '$ip/$hex';
    }
    return '$ip/$ones';
  }

  @override
  bool operator ==(Object other) =>
      other is IpNet &&
      other.ip == ip &&
      other.mask.length == mask.length &&
      _sameBytes(other.mask, mask);

  @override
  int get hashCode => Object.hash(ip, Object.hashAll(mask));
}

bool _sameBytes(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A mask of [ones] leading one bits over [bits] total bits.
///
/// Go: `net.CIDRMask` (`net/ip.go`).
Uint8List _cidrMask(int ones, int bits) {
  final out = Uint8List(bits ~/ 8);
  var remaining = ones;
  for (var i = 0; i < out.length; i++) {
    if (remaining >= 8) {
      out[i] = 0xff;
      remaining -= 8;
    } else if (remaining > 0) {
      out[i] = (0xff << (8 - remaining)) & 0xff;
      remaining = 0;
    }
  }
  return out;
}

/// [source] with [mask] applied.
///
/// Go: `IP.Mask` (`net/ip.go`).
Ip _maskIp(Ip source, Uint8List mask) {
  final bytes = source.asBytes();
  for (var i = 0; i < bytes.length && i < mask.length; i++) {
    bytes[i] &= mask[i];
  }
  return Ip.fromBytes(bytes);
}

/// The number of leading one bits when [mask] is a canonical prefix, or null
/// when it is not.
///
/// Go: `IPMask.Size` (`net/ip.go`), which returns `0, 0` for a non-canonical
/// mask.
int? _maskOnes(Uint8List mask) {
  var ones = 0;
  var i = 0;
  for (; i < mask.length && mask[i] == 0xff; i++) {
    ones += 8;
  }
  if (i < mask.length) {
    final b = mask[i];
    var bit = 0x80;
    while (bit != 0 && (b & bit) != 0) {
      ones++;
      bit >>= 1;
    }
    if ((b & ((bit << 1) - 1)) != 0) return null;
    for (var j = i + 1; j < mask.length; j++) {
      if (mask[j] != 0) return null;
    }
  }
  return ones;
}
