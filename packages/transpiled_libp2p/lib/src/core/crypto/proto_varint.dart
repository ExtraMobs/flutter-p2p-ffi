// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/crypto/proto_varint.dart
//
// Minimal protobuf varint helpers shared by every hand-rolled protobuf
// codec in this package (crypto.pb's PublicKey/PrivateKey, record.pb's
// Envelope, peer.pb's PeerRecord) -- none of these messages are complex
// enough to justify pulling in full protobuf codegen.
import 'dart:typed_data';

/// Encodes [value] as an unsigned LEB128 varint (protobuf's `varint` wire
/// type).
Uint8List encodeProtoVarint(int value) {
  final bytes = <int>[];
  var v = value;
  while (v >= 0x80) {
    bytes.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  bytes.add(v);
  return Uint8List.fromList(bytes);
}

/// Decodes an unsigned LEB128 varint starting at [offset], returning the
/// value and the number of bytes consumed.
(int value, int length) readProtoVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  var index = offset;
  while (true) {
    if (index >= bytes.length) {
      throw const FormatException('protobuf varint runs past end of message');
    }
    final byte = bytes[index];
    value |= (byte & 0x7f) << shift;
    index++;
    if ((byte & 0x80) == 0) return (value, index - offset);
    shift += 7;
    if (shift > 63) throw const FormatException('protobuf varint too long');
  }
}
