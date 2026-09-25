// ignore_for_file: duplicate_ignore, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';
import 'dart:typed_data';

/// An IP address as Go's `net` package models it: a byte slice of length 4 or
/// 16, with no family discriminator of its own.
///
/// This is **not** the same model as `net/netip`, and the difference is
/// load-bearing rather than cosmetic. `net.IP` folds an IPv4-mapped IPv6
/// address into its IPv4 form before printing and before comparing, so
/// `10.0.0.0/8` contains `::ffff:10.1.2.3`; `netip.Prefix.contains` rejects the
/// same pair because the bit lengths differ. `conngater.go` relies on the
/// `net` behaviour, `conn_limiter.go` on the `netip` one, which is why both
/// live here.
final class Ip {
  const Ip._(this._bytes);

  /// The nil address, which Go prints as `<nil>`.
  const Ip.nil() : _bytes = const <int>[];

  /// Wraps [bytes] as an address. Any length is accepted, as in Go, where
  /// `net.IP` is a plain byte slice; only 4 and 16 behave as addresses.
  ///
  /// Go: the conversion `net.IP(b)` (`conngater.go:95`).
  factory Ip.fromBytes(List<int> bytes) => Ip._(List<int>.unmodifiable(bytes));

  /// Parses a textual IPv4 or IPv6 address, or returns null.
  ///
  /// Go: `net.ParseIP` (`net/ip.go`), which returns nil on failure. Note that
  /// Go yields a **16-byte** slice for a dotted-quad address, and this port
  /// does the same so that [toString] and [Ip.to4] behave identically.
  static Ip? tryParse(String text) {
    if (text.contains('%') || text.contains('/')) return null;
    final parsed = InternetAddress.tryParse(text);
    if (parsed == null) return null;
    if (parsed.type == InternetAddressType.IPv4) {
      return Ip._(
        List<int>.unmodifiable(<int>[..._v4InV6Prefix, ...parsed.rawAddress]),
      );
    }
    return Ip._(List<int>.unmodifiable(parsed.rawAddress));
  }

  static const List<int> _v4InV6Prefix = <int>[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, //
  ];

  final List<int> _bytes;

  /// The raw bytes, 4 or 16 for a usable address and empty for nil.
  Uint8List asBytes() => Uint8List.fromList(_bytes);

  /// The number of bytes, as `len(ip)` would give in Go.
  int get length => _bytes.length;

  /// Whether this is the nil address.
  bool get isNil => _bytes.isEmpty;

  /// The 4-byte form when this is an IPv4 address or an IPv4-mapped IPv6
  /// address, and null otherwise.
  ///
  /// Go: `IP.To4` (`net/ip.go`).
  Ip? to4() {
    if (_bytes.length == 4) return this;
    if (_bytes.length == 16 && _isV4Mapped) {
      return Ip._(List<int>.unmodifiable(_bytes.sublist(12)));
    }
    return null;
  }

  /// The 16-byte form, or null when this is neither 4 nor 16 bytes.
  ///
  /// Go: `IP.To16` (`net/ip.go`).
  Ip? to16() {
    if (_bytes.length == 16) return this;
    if (_bytes.length == 4) {
      return Ip._(List<int>.unmodifiable(<int>[..._v4InV6Prefix, ..._bytes]));
    }
    return null;
  }

  bool get _isV4Mapped {
    for (var i = 0; i < 10; i++) {
      if (_bytes[i] != 0) return false;
    }
    return _bytes[10] == 0xff && _bytes[11] == 0xff;
  }

  /// Whether this address equals [other], comparing an IPv4 address and its
  /// IPv4-mapped form as equal.
  ///
  /// Go: `IP.Equal` (`net/ip.go`).
  bool equal(Ip other) {
    final a = to4() ?? this;
    final b = other.to4() ?? other;
    if (a._bytes.length != b._bytes.length) return false;
    for (var i = 0; i < a._bytes.length; i++) {
      if (a._bytes[i] != b._bytes[i]) return false;
    }
    return true;
  }

  /// The textual form, dotted-quad whenever the address has an IPv4 form.
  ///
  /// Go: `IP.String` (`net/ip.go`), which prints `<nil>` for a nil address and
  /// `?` followed by hex for a slice that is neither 4 nor 16 bytes long. The
  /// dotted-quad folding is why `net.ParseIP("::ffff:127.0.0.1").String()` is
  /// `127.0.0.1` and not `::ffff:127.0.0.1`.
  @override
  String toString() {
    if (isNil) return '<nil>';
    final v4 = to4();
    if (v4 != null) return v4._bytes.join('.');
    if (_bytes.length != 16) {
      return '?${_bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    }
    return InternetAddress.fromRawAddress(
      Uint8List.fromList(_bytes),
      type: InternetAddressType.IPv6,
    ).address;
  }

  @override
  bool operator ==(Object other) => other is Ip && equal(other);

  @override
  int get hashCode => Object.hashAll((to4() ?? this)._bytes);
}
