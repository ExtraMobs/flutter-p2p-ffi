// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/utils/varint.dart
import 'dart:typed_data';

// The prefix implements the fixed_types.Golang logical schema.
// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// Go ErrOverflow: multiformats readers accept at most uint63.
const errOverflow = FormatException('varints larger than uint63 not supported');

/// Go ErrUnderflow: the input ended before a terminating byte.
const errUnderflow = FormatException(
  'varints malformed, could not reach the end',
);

/// Go ErrNotMinimal: a redundant zero terminates a multibyte encoding.
const errNotMinimal = FormatException('varint not minimally encoded');

const int maxLenUvarint63 = 9;
const int maxValueUvarint63 = 9223372036854775807; // 0x7FFFFFFFFFFFFFFF


/// Port of go-varint UvarintSize.
int uvarintSize(Golang.Uint64 value) {
  final bits = value.toBigInt().bitLength;
  return bits == 0 ? 1 : (bits + 6) ~/ 7;
}

/// Port of go-varint ToUvarint.
Uint8List toUvarint(Golang.Uint64 value) {
  final bytes = Uint8List(uvarintSize(value));
  final length = putUvarint(bytes, value);
  return Uint8List.sublistView(bytes, 0, length);
}

/// Port of go-varint PutUvarint, which forwards to Go's binary encoder.
/// Returns the number of bytes written; a short buffer is an invalid call.
int putUvarint(Uint8List buffer, Golang.Uint64 value) {
  var remaining = value.toBigInt();
  var index = 0;
  do {
    if (index >= buffer.length) {
      throw RangeError('buffer too short for uint64 varint');
    }
    final chunk = (remaining & BigInt.from(0x7f)).toInt();
    remaining >>= 7;
    buffer[index++] = remaining == BigInt.zero ? chunk : chunk | 0x80;
  } while (remaining != BigInt.zero);
  return index;
}

/// Port of go-varint FromUvarint, returning value and consumed bytes.
/// Go error returns become the corresponding sentinel exception.
(Golang.Uint64 value, int length) fromUvarint(Uint8List bytes) {
  var x = Golang.Uint64();
  var shift = 0;
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if ((i == 8 && b >= 128) || i >= 9) throw errOverflow;
    if (b < 128) {
      if (b == 0 && shift > 0) throw errNotMinimal;
      final value = x | (Golang.Uint64(b) << shift);
      return (value, i + 1);
    }
    x = x | (Golang.Uint64(b & 127) << shift);
    shift += 7;
  }
  throw errUnderflow;
}

/// Reads a varint from [bytes] starting at [offset].
///
/// Returns a record containing the decoded value and the number of bytes
/// consumed. Throws [FormatException] if the varint is malformed or exceeds
/// the maximum length of 9 bytes.
(int value, int length) readVarint(Uint8List bytes, int offset) {
  final result = fromUvarint(Uint8List.sublistView(bytes, offset));
  return (result.$1.toBigInt().toInt(), result.$2);
}

/// Encodes [value] as a varint into a [Uint8List].
Uint8List encodeVarint(int value) {
  if (value < 0) {
    throw ArgumentError('Value must be non-negative: $value');
  }
  return toUvarint(Golang.Uint64(value));
}
