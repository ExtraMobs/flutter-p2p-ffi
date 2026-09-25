part of '../../transpiled_go_cidranger.dart';

// Port of github.com/libp2p/go-cidranger/net/ip.go's `Network`,
// `NetworkNumberMask`, `NextIP` and `PreviousIP` (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md). See network_number.dart's header for
// this subpackage's place in the module.
//
// Go stdlib's `net.IPNet` is stood in for by
// `package:boilerplate/net/golang.dart`'s `IpNet` (see
// transpiled_go_cidranger.dart's header for why).

/// Clamped uint8 subtraction (`a - b`, floored at zero on underflow),
/// exactly mirroring go-cidranger/net's private `sub` helper, which
/// exploits Go's uint8 wraparound (`res > a` after underflow) to the same
/// end. [Golang.Uint8] centralizes that wraparound per AGENTS.md's "tipos
/// primitivos Go compartilhados", so the clamp check below reads directly
/// off it rather than reimplementing modulo-256 arithmetic by hand.
Golang.Uint8 _subUint8(Golang.Uint8 a, Golang.Uint8 b) {
  final res = a - b;
  return res > a ? Golang.Uint8(0) : res;
}

/// The four word-masks (for word positions 1-4 of a `NetworkNumber`) for a
/// mask of [ones] leading one-bits, each `0xFFFFFFFF` shifted left by
/// however many bits of that word fall outside the mask (zero once a word
/// is fully within it). Equivalent to go-cidranger/net's private `mask`
/// function.
List<int> _maskWords(NetworkNumberMask m) {
  final ones = Golang.Uint8(m.ones);
  final allOnes = Golang.Uint32(0xFFFFFFFF);
  int wordMask(int bitPosition) {
    final shift = _subUint8(Golang.Uint8(bitPosition), ones).toBigInt().toInt();
    return (allOnes << shift).toBigInt().toInt();
  }

  return [
    wordMask(1 * 32),
    wordMask(2 * 32),
    wordMask(3 * 32),
    wordMask(4 * 32),
  ];
}

/// A network prefix length ("CIDR mask"), counted as leading one-bits.
/// Equivalent to go-cidranger/net's `NetworkNumberMask` (a bare `int`
/// type upstream with its own `Mask` method).
class NetworkNumberMask implements Comparable<NetworkNumberMask> {
  /// Creates a mask of [ones] leading one-bits.
  const NetworkNumberMask(this.ones);

  /// The number of leading one-bits.
  final int ones;

  /// The [n] masked by this many leading one-bits. Equivalent to
  /// go-cidranger/net's `NetworkNumberMask.Mask`.
  NetworkNumber mask(NetworkNumber n) {
    final words = _maskWords(this);
    switch (n.length) {
      case ipv4Uint32Count:
        return NetworkNumber([n[0] & words[0]]);
      case ipv6Uint32Count:
        return NetworkNumber([
          n[0] & words[0],
          n[1] & words[1],
          n[2] & words[2],
          n[3] & words[3],
        ]);
      default:
        return const NetworkNumber([]);
    }
  }

  @override
  int compareTo(NetworkNumberMask other) => ones.compareTo(other.ones);

  /// Fewer leading one-bits (a broader mask) than [other].
  bool operator <(NetworkNumberMask other) => compareTo(other) < 0;

  /// No more leading one-bits (as broad a mask, or broader) than [other].
  bool operator <=(NetworkNumberMask other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is NetworkNumberMask && ones == other.ones;
  @override
  int get hashCode => ones.hashCode;
  @override
  String toString() => ones.toString();
}

/// A block of network numbers (a CIDR block), represented by its byte-level
/// [NetworkNumber] rather than the outer `Ip`/[IpNet] pair (this port's
/// stand-in for Go stdlib's `net.IP`/`net.IPNet`) -- go-cidranger's internal
/// working representation, converted from/to [IpNet] at the outer
/// [Ranger]/[RangerEntry] API boundary. Equivalent to go-cidranger/net's
/// `Network`.
class Network {
  /// Wraps an already-computed [number]/[mask] pair.
  const Network({required this.number, required this.mask});

  /// Builds the [Network] for [ipNet]. Equivalent to go-cidranger/net's
  /// `NewNetwork`, which recovers the prefix length from [ipNet]'s raw
  /// mask bytes via stdlib `net.IPMask.Size()` -- reproduced locally as
  /// [_maskOnes] since `IpNet` doesn't expose that Go method publicly.
  factory Network.fromIpNetwork(IpNet ipNet) => Network(
    number: NetworkNumber.fromIp(ipNet.ip)!,
    mask: NetworkNumberMask(_maskOnes(ipNet.mask)),
  );

  /// The network's address, as a byte-level [NetworkNumber].
  final NetworkNumber number;

  /// The network's prefix length.
  final NetworkNumberMask mask;

  /// This network re-masked to [ones] leading one-bits. Equivalent to
  /// go-cidranger/net's `Network.Masked`.
  Network masked(int ones) {
    final m = NetworkNumberMask(ones);
    return Network(number: m.mask(number), mask: m);
  }

  /// Whether [nn] falls within this network. Equivalent to
  /// go-cidranger/net's `Network.Contains`.
  bool contains(NetworkNumber nn) {
    if (number.length != nn.length) return false;
    final words = _maskWords(mask);
    switch (number.length) {
      case ipv4Uint32Count:
        return (nn[0] & words[0]) == number[0];
      case ipv6Uint32Count:
        return (nn[0] & words[0]) == number[0] &&
            (nn[1] & words[1]) == number[1] &&
            (nn[2] & words[2]) == number[2] &&
            (nn[3] & words[3]) == number[3];
      default:
        return false;
    }
  }

  /// Whether this network fully subsumes [other] (contains its address and
  /// is at least as broad). Equivalent to go-cidranger/net's
  /// `Network.Covers`.
  bool covers(Network other) => contains(other.number) && mask <= other.mask;

  /// The smallest position of the preceding common bits shared with
  /// [other]'s address, floored at the narrower of the two masks. Throws
  /// [NoGreatestCommonBitException] if the addresses diverge at the very
  /// first bit, or [VersionMismatchException] on an IPv4/IPv6 mismatch.
  /// Equivalent to go-cidranger/net's `Network.LeastCommonBitPosition`.
  int leastCommonBitPosition(Network other) {
    final maskSize = mask <= other.mask ? mask : other.mask;
    final maskPosition = other.number.length * bitsPerUint32 - maskSize.ones;
    final lcb = number.leastCommonBitPosition(other.number);
    return maskPosition > lcb ? maskPosition : lcb;
  }

  @override
  bool operator ==(Object other) =>
      other is Network && number == other.number && mask == other.mask;
  @override
  int get hashCode => Object.hash(number, mask);

  @override
  String toString() => '${number.toIp()}/${mask.ones}';

  /// The [IpNet] equivalent (Go stdlib `net.IPNet` stand-in). Equivalent
  /// to go-cidranger/net's `Network.IPNet`, which builds the mask via
  /// stdlib `net.CIDRMask` -- reproduced locally as [_cidrMaskBytes].
  IpNet toIpNetwork() => IpNet(
    ip: number.toIp(),
    mask: _cidrMaskBytes(mask.ones, number.length * bitsPerUint32),
  );
}

/// The next sequential IP address. Equivalent to go-cidranger/net's
/// `NextIP`. Go calls `NewNetworkNumber(ip).Next()` unconditionally (a nil
/// `NetworkNumber` slice still responds to `.Next()`, yielding another nil
/// slice), so a malformed [ip] falls through to the empty [NetworkNumber]
/// rather than throwing.
Ip nextIp(Ip ip) =>
    (NetworkNumber.fromIp(ip) ?? const NetworkNumber([])).next().toIp();

/// The previous sequential IP address. Equivalent to go-cidranger/net's
/// `PreviousIP`. See [nextIp] for why a malformed [ip] doesn't throw.
Ip previousIp(Ip ip) =>
    (NetworkNumber.fromIp(ip) ?? const NetworkNumber([])).previous().toIp();

/// [source] with [mask] applied ([mask] a Go `net.CIDRMask`-style byte
/// mask, one bit per address bit). Equivalent to Go stdlib `net.IPMask`'s
/// use in `Network.IPNet` -- not the outer `IpNet.contains`'s
/// `_networkNumberAndMask`, which already lives on [IpNet] itself.
Uint8List _cidrMaskBytes(int ones, int bits) {
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

/// The number of leading one bits when [mask] is a canonical prefix, or `0`
/// when it is not (Go: `ones, _ := mask.Size()` discards the bit-count
/// return and keeps `ones == 0` on failure). Equivalent to Go stdlib
/// `net.IPMask.Size`, the exact call go-cidranger/net's `NewNetwork` makes
/// -- reproduced locally since `IpNet` doesn't expose that Go method
/// publicly.
int _maskOnes(Uint8List mask) {
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
    if ((b & ((bit << 1) - 1)) != 0) return 0;
    for (var j = i + 1; j < mask.length; j++) {
      if (mask[j] != 0) return 0;
    }
  }
  return ones;
}
