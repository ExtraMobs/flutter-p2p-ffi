import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// Returns the value of a big endian uint24.
int bigEndianUint24(Uint8List raw) {
  if (raw.length < 3) {
    return 0;
  }
  return (raw[0] << 16) | (raw[1] << 8) | raw[2];
}

/// Encodes a uint24 and places into [out].
void putBigEndianUint24(Uint8List out, int inVal) {
  out[0] = (inVal >> 16) & 0xFF;
  out[1] = (inVal >> 8) & 0xFF;
  out[2] = inVal & 0xFF;
}

/// Encodes a uint48 and places into [out].
void putBigEndianUint48(Uint8List out, int inVal) {
  out[0] = (inVal >> 40) & 0xFF;
  out[1] = (inVal >> 32) & 0xFF;
  out[2] = (inVal >> 24) & 0xFF;
  out[3] = (inVal >> 16) & 0xFF;
  out[4] = (inVal >> 8) & 0xFF;
  out[5] = inVal & 0xFF;
}

/// Returns the larger value.
int max(int a, int b) {
  return a > b ? a : b;
}

/// Appends a big-endian, 48-bit value to the byte list.
List<int> addUint48(List<int> b, int v) {
  b.add((v >> 40) & 0xFF);
  b.add((v >> 32) & 0xFF);
  b.add((v >> 24) & 0xFF);
  b.add((v >> 16) & 0xFF);
  b.add((v >> 8) & 0xFF);
  b.add(v & 0xFF);
  return b;
}
