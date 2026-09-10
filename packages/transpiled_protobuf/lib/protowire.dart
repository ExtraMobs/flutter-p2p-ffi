// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of google.golang.org/protobuf/encoding/protowire v1.36.11.
import 'dart:typed_data';

// The prefix expresses the requested fixed_types.Golang schema.
// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// Converts a negative consumed-length code to its parse error.
FormatException? parseError(int n) => n >= 0
    ? null
    : switch (n) {
        -1 => const FormatException('unexpected EOF'),
        -2 => const FormatException('invalid field number'),
        -3 => const FormatException('variable length integer overflow'),
        -4 => const FormatException('cannot parse reserved wire type'),
        -5 => const FormatException('mismatching end group marker'),
        _ => const FormatException('parse error'),
      };

/// Returns the exact uint64 value and consumed length (negative on error).
(Golang.Uint64, int) consumeVarint(Uint8List b) {
  var v = Golang.Uint64();
  for (var i = 0; i < 10; i++) {
    if (i >= b.length) return (Golang.Uint64(), -1);
    final y = b[i];
    if (i == 9 && y > 1) return (Golang.Uint64(), -3);
    v = v | (Golang.Uint64(y & 127) << (7 * i));
    if (y < 128) return (v, i + 1);
  }
  return (Golang.Uint64(), -3);
}

/// Decodes a tag, permitting MessageSet numbers up to int32 maximum.
(int, int) decodeTag(Golang.Uint64 x) {
  final number = x >> 3;
  return number > Golang.Uint64(0x7fffffff)
      ? (-1, 0)
      : (number.toBigInt().toInt(), (x & Golang.Uint64(7)).toBigInt().toInt());
}

/// Encodes a Go int32 field number and wire type.
Golang.Uint64 encodeTag(int number, int type) =>
    (Golang.Uint64.fromBigInt(Golang.Int32(number).toBigInt()) << 3) |
    Golang.Uint64(type & 7);

/// Returns field number, wire type and consumed length (negative on error).
(int, int, int) consumeTag(Uint8List b) {
  final (v, n) = consumeVarint(b);
  if (n < 0) return (0, 0, n);
  final (number, type) = decodeTag(v);
  if (number < 1) return (0, 0, -2);
  return (number, type, n);
}

/// Returns a view of length-prefixed bytes and total consumed length.
(Uint8List?, int) consumeBytes(Uint8List b) {
  final (length, n) = consumeVarint(b);
  if (n < 0) return (null, n);
  if (length > Golang.Uint64(b.length - n)) return (null, -1);
  final size = length.toBigInt().toInt(); // Bounded by the input buffer above.
  return (Uint8List.sublistView(b, n, n + size), n + size);
}

/// Appends a uint64 bit pattern to a growable byte list and returns that list.
List<int> appendVarint(List<int> b, Golang.Uint64 v) {
  while (v >= Golang.Uint64(128)) {
    b.add((v & Golang.Uint64(127)).toBigInt().toInt() | 128);
    v = v >> 7;
  }
  b.add(v.toBigInt().toInt());
  return b;
}

/// Appends an encoded tag.
List<int> appendTag(List<int> b, int number, int type) =>
    appendVarint(b, encodeTag(number, type));

/// Appends length-prefixed bytes.
List<int> appendBytes(List<int> b, List<int> value) {
  appendVarint(b, Golang.Uint64(value.length));
  b.addAll(value);
  return b;
}

/// Returns the encoded size over the full unsigned 64-bit domain.
int sizeVarint(Golang.Uint64 v) =>
    ((v.toBigInt() | BigInt.one).bitLength + 6) ~/ 7;

/// Returns the tag size.
int sizeTag(int number) => sizeVarint(encodeTag(number, 0));

/// Returns length prefix plus payload size.
int sizeBytes(int n) => sizeVarint(Golang.Uint64(n)) + n;

/// Go AppendFixed32 writes little-endian uint32 bytes.
List<int> appendFixed32(List<int> b, Golang.Uint32 v) {
  b.addAll(v.toLittleEndianBytes());
  return b;
}

/// Go ConsumeFixed32 returns zero and -1 for a truncated input.
(Golang.Uint32, int) consumeFixed32(Uint8List b) {
  if (b.length < 4) return (Golang.Uint32(), -1);
  var v = Golang.Uint32();
  for (var i = 0; i < 4; i++) {
    v = v | (Golang.Uint32(b[i]) << (8 * i));
  }
  return (v, 4);
}

/// Go SizeFixed32 is always four bytes.
int sizeFixed32() => 4;

/// Go AppendFixed64 writes little-endian uint64 bytes.
List<int> appendFixed64(List<int> b, Golang.Uint64 v) {
  b.addAll(v.toLittleEndianBytes());
  return b;
}

/// Go ConsumeFixed64 returns zero and -1 for a truncated input.
(Golang.Uint64, int) consumeFixed64(Uint8List b) {
  if (b.length < 8) return (Golang.Uint64(), -1);
  var v = Golang.Uint64();
  for (var i = 0; i < 8; i++) {
    v = v | (Golang.Uint64(b[i]) << (8 * i));
  }
  return (v, 8);
}

/// Go SizeFixed64 is always eight bytes.
int sizeFixed64() => 8;

/// Go AppendString preserves string bytes, including malformed UTF-8.
List<int> appendString(List<int> b, Golang.String value) {
  appendVarint(b, Golang.Uint64(value.length));
  b.addAll(value.toBytes());
  return b;
}

/// Go ConsumeString delegates byte parsing and preserves the error length.
/// On failure its value is the empty string, as string(nil) in Go.
(Golang.String, int) consumeString(Uint8List b) {
  final (bytes, n) = consumeBytes(b);
  return (bytes == null ? Golang.String() : Golang.String.fromBytes(bytes), n);
}
