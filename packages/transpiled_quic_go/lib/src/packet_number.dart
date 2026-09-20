import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// Reconstructs a packet number according to RFC 9000, appendix A.3.
///
/// Mirrors quic-go internal/protocol.DecodePacketNumber. Inputs cross the
/// Dart boundary as integers; arithmetic retains Go uint8/int64 semantics.
int decodePacketNumber(int wireLength, int largestPacketNumber, int truncated) {
  final one = Golang.Int64(1);
  final expected = Golang.Int64(largestPacketNumber) + one;
  final shift = (Golang.Uint8(wireLength) * Golang.Uint8(8)).toBigInt().toInt();
  final window = one << shift;
  final halfWindow = window ~/ Golang.Int64(2);
  final mask = window - one;
  final candidate = (expected & ~mask) | Golang.Int64(truncated);
  if (candidate <= expected - halfWindow && candidate < (one << 62) - window) {
    return (candidate + window).toIntExact();
  }
  if (candidate > expected + halfWindow && candidate >= window) {
    return (candidate - window).toIntExact();
  }
  return candidate.toIntExact();
}
