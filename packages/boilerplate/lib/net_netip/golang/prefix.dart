// ignore_for_file: duplicate_ignore, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'addr.dart';

/// An IP network prefix: an address plus a leading bit count.
///
/// Go: `netip.Prefix` (`netip.go:1290`). Instances are value types with
/// equality and a hash code, because upstream uses them as map keys
/// (`conn_limiter.go:120-121`, `x/rate/limiter.go:254`).
final class Prefix {
  const Prefix._(this._addr, this._bits);

  /// The zero prefix, for which [isValid] is false.
  const Prefix.zero() : _addr = const Addr.zero(), _bits = -1;

  /// A prefix of [bits] leading bits of [addr].
  ///
  /// Go: `PrefixFrom` (`netip.go:1310-1320`), which yields an invalid prefix
  /// -- rather than an error -- when [bits] does not fit the address.
  factory Prefix.from(Addr addr, int bits) {
    if (!addr.isValid || bits < 0 || bits > addr.bitLen) {
      return const Prefix.zero();
    }
    return Prefix._(addr, bits);
  }

  /// Parses `address/bits`, or returns null when [text] is not one.
  ///
  /// Go: `ParsePrefix` (`netip.go:1334-1367`). Like Go, an address with a zone
  /// is rejected, and the bit count must fit the address family.
  static Prefix? tryParse(String text) {
    final slash = text.lastIndexOf('/');
    if (slash < 0) return null;
    final addr = Addr.tryParse(text.substring(0, slash));
    if (addr == null) return null;
    final bits = int.tryParse(text.substring(slash + 1));
    if (bits == null || bits < 0 || bits > addr.bitLen) return null;
    return Prefix._(addr, bits);
  }

  /// Parses `address/bits`, throwing when [text] is not one.
  ///
  /// Go: `MustParsePrefix` (`netip.go:1370-1376`), which panics instead.
  factory Prefix.mustParse(String text) {
    final parsed = tryParse(text);
    if (parsed == null) {
      throw FormatException('netip.Prefix.mustParse($text): invalid prefix');
    }
    return parsed;
  }

  final Addr _addr;
  final int _bits;

  /// The address this prefix was built from, not necessarily masked.
  ///
  /// Go: `Prefix.Addr` (`netip.go:1322`).
  Addr get addr => _addr;

  /// The leading bit count, or -1 when this prefix is invalid.
  ///
  /// Go: `Prefix.Bits` (`netip.go:1324`).
  int get bits => _bits;

  /// Whether this prefix is usable.
  ///
  /// Go: `Prefix.IsValid` (`netip.go:1326`).
  bool get isValid => _bits >= 0;

  /// Whether this prefix holds exactly one address.
  ///
  /// Go: `IsSingleIP` (`netip.go:1331`).
  bool get isSingleIp => isValid && _bits == _addr.bitLen;

  /// This prefix with the address masked down to [bits].
  ///
  /// Go: `Masked` (`netip.go:1416-1419`).
  Prefix masked() => isValid ? _addr.prefix(_bits) : const Prefix.zero();

  /// Whether this network includes [ip].
  ///
  /// Go: `Contains` (`netip.go:1428-1451`). An IPv4 address never matches an
  /// IPv6 prefix and vice versa, because the bit lengths differ.
  bool contains(Addr ip) {
    if (!isValid || !ip.isValid) return false;
    if (_addr.bitLen != ip.bitLen) return false;
    return _addr.sharesPrefixWith(ip, _bits);
  }

  /// The textual form `address/bits`.
  ///
  /// Go: `Prefix.String` (`netip.go:1497`).
  @override
  String toString() => isValid ? '$_addr/$_bits' : 'invalid Prefix';

  @override
  bool operator ==(Object other) =>
      other is Prefix && other._bits == _bits && other._addr == _addr;

  @override
  int get hashCode => Object.hash(_addr, _bits);
}
