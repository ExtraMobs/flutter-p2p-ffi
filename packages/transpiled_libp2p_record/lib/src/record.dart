// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/record.dart
//
// Port of go-libp2p-record's record.go and pb/record.proto: the DHT's own
// `Record{key, value, timeReceived}` message (field 5 is a placeholder for
// a per-record TTL that was never finished upstream -- fields 3/4 were
// removed from the real .proto and are intentionally absent here too).
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// A DHT record: an opaque [value] stored under [key], with an optional
/// [timeReceived] timestamp set by the receiver. Equivalent to
/// go-libp2p-record's `pb.Record`.
class Record {
  /// Creates a record. [timeReceived] is set by the receiver, not the
  /// writer -- leave it null when building a record to put.
  const Record({required this.key, required this.value, this.timeReceived});

  /// Builds a record for the given key/value pair, ready to be put into
  /// the DHT. Equivalent to go-libp2p-record's `MakePutRecord`.
  factory Record.makePutRecord(Uint8List key, Uint8List value) =>
      Record(key: key, value: value);

  /// Decodes a Record from its protobuf wire representation.
  factory Record.fromProtobuf(Uint8List bytes) {
    final decoded = _decodeRecordProto(bytes);
    return Record(
      key: decoded.key,
      value: decoded.value,
      timeReceived: decoded.timeReceived,
    );
  }

  /// The key that references this record.
  final Uint8List key;

  /// The actual value this record is storing.
  final Uint8List value;

  /// The time the record was received, set by the receiver (an RFC 3339
  /// timestamp string, matching the real DHT's convention -- not enforced
  /// here since this type only carries the field).
  final String? timeReceived;

  /// Encodes this record to its protobuf wire representation.
  Uint8List toProtobuf() =>
      _encodeRecordProto(key: key, value: value, timeReceived: timeReceived);
}

Uint8List _encodeRecordProto({
  required Uint8List key,
  required Uint8List value,
  required String? timeReceived,
}) {
  final out = BytesBuilder();
  void writeBytes(int fieldNumber, Uint8List bytes) {
    out.add(encodeProtoVarint((fieldNumber << 3) | 2));
    out.add(encodeProtoVarint(bytes.length));
    out.add(bytes);
  }

  writeBytes(1, key);
  writeBytes(2, value);
  if (timeReceived != null && timeReceived.isNotEmpty) {
    writeBytes(5, Uint8List.fromList(timeReceived.codeUnits));
  }
  return out.toBytes();
}

({Uint8List key, Uint8List value, String? timeReceived}) _decodeRecordProto(
  Uint8List bytes,
) {
  Uint8List? key;
  Uint8List? value;
  String? timeReceived;
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    if (wireType != 2) {
      throw FormatException('unsupported wire type in Record: $wireType');
    }
    final (length, lenLen) = readProtoVarint(bytes, offset);
    offset += lenLen;
    if (offset + length > bytes.length) {
      throw const FormatException('protobuf field runs past end of message');
    }
    final fieldBytes = bytes.sublist(offset, offset + length);
    offset += length;
    switch (fieldNumber) {
      case 1:
        key = fieldBytes;
      case 2:
        value = fieldBytes;
      case 5:
        timeReceived = String.fromCharCodes(fieldBytes);
    }
  }
  return (key: key ?? Uint8List(0), value: value ?? Uint8List(0), timeReceived: timeReceived);
}
