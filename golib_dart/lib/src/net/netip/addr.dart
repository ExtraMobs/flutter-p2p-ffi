// ignore_for_file: duplicate_ignore, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';
import 'dart:typed_data';

import 'prefix.dart';

/// An IPv4 or IPv6 address, mirroring Go's `netip.Addr`.
///
/// Go stores the address as a `uint128` plus a zone discriminator, keeping
/// IPv4 in 4-in-6 form and telling the two apart with `z4`. This port keeps
/// the 4- or 16-byte slice it was built from instead: the discriminator is the
/// length, which is the same distinction `AddrFromSlice` already switches on
/// (`netip.go:349-356`), and it makes the masked comparisons byte-wise instead
/// of requiring 128-bit arithmetic. Observable behaviour is unchanged.
///
/// Zones (`%eth0`) are **not** represented. No caller in this repository parses
/// a zoned address, and `Prefix.contains` rejects zoned addresses outright
/// (`netip.go:1429`), so the only observable effect of their absence is that a
/// zoned address cannot be built in the first place.
final class Addr implements Comparable<Addr> {
  const Addr._(this._bytes);

  /// The zero address, for which [isValid] is false.
  ///
  /// Go: `netip.Addr{}`, whose zone is `z0` (`netip.go:391`).
  const Addr.zero() : _bytes = const <int>[];

  /// Builds an address from 4 or 16 bytes, or returns null for any other
  /// length.
  ///
  /// Go: `AddrFromSlice` (`netip.go:349-357`), which reports the same failure
  /// through its `ok` result.
  static Addr? tryFromSlice(List<int> slice) {
    if (slice.length != 4 && slice.length != 16) return null;
    return Addr._(List<int>.unmodifiable(slice));
  }

  /// Parses a textual IPv4 or IPv6 address, or returns null when [text] is not
  /// one.
  ///
  /// Go: `ParseAddr` (`netip.go:66`). Parsing is delegated to
  /// `InternetAddress.tryParse`, which accepts the same dotted-quad and
  /// RFC 4291 forms.
  static Addr? tryParse(String text) {
    if (text.contains('%')) return null;
    final parsed = InternetAddress.tryParse(text);
    if (parsed == null) return null;
    return Addr._(List<int>.unmodifiable(parsed.rawAddress));
  }

  final List<int> _bytes;

  /// Whether this is anything other than the zero address.
  ///
  /// Go: `IsValid` (`netip.go:391`).
  bool get isValid => _bytes.isNotEmpty;

  /// Number of bits in the address: 128 for IPv6, 32 for IPv4, 0 for the zero
  /// address.
  ///
  /// Go: `BitLen` (`netip.go:398-406`). Note that an IPv4-mapped IPv6 address
  /// counts as IPv6 and therefore has bit length 128.
  int get bitLen => _bytes.length * 8;

  /// Whether this is an IPv4 address. False for an IPv4-mapped IPv6 address.
  ///
  /// Go: `Is4` (`netip.go:461-463`).
  bool get is4 => _bytes.length == 4;

  /// Whether this is an IPv6 address, including IPv4-mapped ones.
  ///
  /// Go: `Is6` (`netip.go:474-476`).
  bool get is6 => _bytes.length == 16;

  /// Whether this is an IPv4-mapped IPv6 address, that is, one in
  /// `::ffff:0:0/96`.
  ///
  /// Go: `Is4In6` (`netip.go:468-470`).
  bool get is4In6 {
    if (!is6) return false;
    for (var i = 0; i < 10; i++) {
      if (_bytes[i] != 0) return false;
    }
    return _bytes[10] == 0xff && _bytes[11] == 0xff;
  }

  /// The address as bytes: 4 for IPv4, 16 for IPv6, empty for the zero address.
  ///
  /// Go: `AsSlice` (`netip.go:724`).
  Uint8List asSlice() => Uint8List.fromList(_bytes);

  /// This address with any IPv4-mapped IPv6 prefix removed.
  ///
  /// Go: `Unmap` (`netip.go:483-488`).
  Addr unmap() =>
      is4In6 ? Addr._(List<int>.unmodifiable(_bytes.sublist(12))) : this;

  /// The prefix of [bits] leading bits of this address, with the remaining
  /// bits zeroed.
  ///
  /// Go: `Addr.Prefix` (`netip.go:677-697`). Like Go, a negative [bits]
  /// throws, a [bits] wider than the address throws, and the zero address
  /// yields the zero [Prefix] rather than an error.
  Prefix prefix(int bits) {
    if (bits < 0)
      throw ArgumentError.value(bits, 'bits', 'negative Prefix bits');
    if (!isValid) return const Prefix.zero();
    if (bits > bitLen) {
      throw ArgumentError.value(
        bits,
        'bits',
        'prefix length $bits too large for ${is4 ? 'IPv4' : 'IPv6'}',
      );
    }
    return Prefix.from(Addr._(_maskedBytes(bits)), bits);
  }

  /// This address with everything past [bits] leading bits cleared.
  List<int> _maskedBytes(int bits) {
    final out = List<int>.from(_bytes);
    for (var i = 0; i < out.length; i++) {
      final keep = bits - i * 8;
      if (keep >= 8) continue;
      out[i] = keep <= 0 ? 0 : out[i] & (0xff << (8 - keep)) & 0xff;
    }
    return List<int>.unmodifiable(out);
  }

  /// Whether the first [bits] bits of this address and [other] are equal.
  ///
  /// Backs `Prefix.contains` (`netip.go:1428-1451`); callers must have already
  /// checked that both addresses have the same bit length.
  bool sharesPrefixWith(Addr other, int bits) {
    for (var i = 0; i < _bytes.length; i++) {
      final keep = bits - i * 8;
      if (keep <= 0) return true;
      if (keep >= 8) {
        if (_bytes[i] != other._bytes[i]) return false;
        continue;
      }
      final mask = (0xff << (8 - keep)) & 0xff;
      return (_bytes[i] & mask) == (other._bytes[i] & mask);
    }
    return true;
  }

  /// The textual form: dotted-quad for IPv4, RFC 5952 for IPv6.
  ///
  /// Go: `Addr.String` (`netip.go:1042`). Formatting is delegated to
  /// `InternetAddress`, whose IPv6 output is also zero-compressed; it is used
  /// here for display and for map keys, never parsed back by wire code.
  @override
  String toString() {
    if (!isValid) return 'invalid IP';
    return InternetAddress.fromRawAddress(
      Uint8List.fromList(_bytes),
      type: is4 ? InternetAddressType.IPv4 : InternetAddressType.IPv6,
    ).address;
  }

  /// Orders by bit length first and then by bytes, as Go does.
  ///
  /// Go: `Compare` (`netip.go:766-783`).
  @override
  int compareTo(Addr other) {
    if (_bytes.length != other._bytes.length) {
      return _bytes.length < other._bytes.length ? -1 : 1;
    }
    for (var i = 0; i < _bytes.length; i++) {
      if (_bytes[i] != other._bytes[i]) {
        return _bytes[i] < other._bytes[i] ? -1 : 1;
      }
    }
    return 0;
  }

  @override
  bool operator ==(Object other) => other is Addr && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll(_bytes);
}
