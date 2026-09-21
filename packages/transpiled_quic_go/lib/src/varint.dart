// ignore_for_file: public_member_api_docs
import 'dart:typed_data';

const maxVarInt = (1 << 62) - 1;

int varIntLength(int value) {
  RangeError.checkValueInInterval(value, 0, maxVarInt, 'value');
  if (value < 1 << 6) return 1;
  if (value < 1 << 14) return 2;
  if (value < 1 << 30) return 4;
  return 8;
}

Uint8List appendVarInt(List<int> prefix, int value) {
  final length = varIntLength(value);
  final out = Uint8List(prefix.length + length)..setAll(0, prefix);
  var remaining = value;
  for (var i = out.length - 1; i >= prefix.length; i--) {
    out[i] = remaining & 0xff;
    remaining >>= 8;
  }
  out[prefix.length] |= switch (length) {
    1 => 0,
    2 => 0x40,
    4 => 0x80,
    _ => 0xc0,
  };
  return out;
}

(int value, int bytesRead) parseVarInt(Uint8List bytes, [int offset = 0]) {
  if (offset < 0 || offset >= bytes.length)
    throw const FormatException('empty QUIC varint');
  final length = 1 << (bytes[offset] >> 6);
  if (bytes.length - offset < length)
    throw const FormatException('truncated QUIC varint');
  var value = bytes[offset] & 0x3f;
  for (var i = 1; i < length; i++) value = (value << 8) | bytes[offset + i];
  return (value, length);
}
