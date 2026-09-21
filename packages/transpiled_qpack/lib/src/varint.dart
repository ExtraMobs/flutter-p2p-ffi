part of 'qpack_impl.dart';

// Port of qpack/varint.go (github.com/quic-go/qpack, commit
// c415cad59091662a20b7b1c4505fbb177dbda0e3). That file is itself a copy of
// the variable-length integer representation from the Go standard library's
// HPACK implementation (RFC 7541 section 5.1), which QPACK reuses unchanged.
//
// Both `appendVarInt` and `readVarInt` are unexported in the Go source, so
// they stay private here. `readVarInt` returns `(i uint64, remain []byte,
// err error)` in Go; the slice-of-remaining-bytes idiom is replaced with a
// consumed-byte count, matching the sibling `parseVarInt` helper in
// package:transpiled_quic_go/src/varint.dart (same RFC 7541 integer family,
// same repository, same house style of plain `int` for this bounded,
// non-wraparound bit-twiddling). Overflow and truncation both surface as
// [FormatException], since Go doesn't expose either as a typed error a
// caller could distinguish from any other decode failure.

/// Appends [i], encoded as a variable-length integer using an [n]-bit
/// prefix, to [dst] and returns the extended buffer.
///
/// See http://http2.github.io/http2-spec/compression.html#integer.representation
List<int> _appendVarInt(List<int> dst, int n, int i) {
  final k = (1 << n) - 1;
  if (i < k) {
    dst.add(i);
    return dst;
  }
  dst.add(k);
  i -= k;
  while (i >= 128) {
    dst.add(0x80 | (i & 0x7f));
    i >>= 7;
  }
  dst.add(i);
  return dst;
}

/// Reads an unsigned variable-length integer with an [n]-bit prefix off the
/// beginning of [data] starting at [offset].
///
/// [n] must be between 1 and 8. Returns the decoded value together with the
/// number of bytes consumed. Throws [FormatException] if [data] does not
/// contain a complete integer starting at [offset], or if the integer
/// overflows.
(int value, int bytesRead) _readVarInt(int n, List<int> data, int offset) {
  if (n < 1 || n > 8) {
    throw ArgumentError.value(n, 'n', 'must be between 1 and 8');
  }
  if (offset >= data.length) {
    throw const FormatException('unexpected EOF while reading QPACK varint');
  }
  final prefixMax = (1 << n) - 1;
  var i = data[offset];
  if (n < 8) {
    i &= prefixMax;
  }
  if (i < prefixMax) {
    return (i, 1);
  }
  var pos = offset + 1;
  var m = 0;
  while (pos < data.length) {
    final b = data[pos];
    pos++;
    i += (b & 127) << m;
    if (b & 128 == 0) {
      return (i, pos - offset);
    }
    m += 7;
    if (m >= 63) {
      // Go's own comment on this bound: "TODO: proper overflow check.
      // making this up." Kept as-is since the bound is part of the wire
      // contract every implementation of this HPACK-derived varint shares.
      throw const FormatException('varint integer overflow');
    }
  }
  throw const FormatException('unexpected EOF while reading QPACK varint');
}
