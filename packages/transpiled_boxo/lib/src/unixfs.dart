// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:transpiled_varint/transpiled_varint.dart';

/// UnixFS Data.Type values from boxo/ipld/unixfs/pb/unixfs.proto.
enum UnixFsDataType { raw, directory, file, metadata, symlink, hamtShard }

extension on UnixFsDataType {
  int get wireValue => index;
}

UnixFsDataType _typeFromWire(int value) => UnixFsDataType.values[value];

List<int> _bytesField(int number, List<int> bytes) => <int>[
  (number << 3) | 2,
  ...encodeVarint(bytes.length),
  ...bytes,
];

List<int> _uvarint(int number, int value) => <int>[
  number << 3,
  ...encodeVarint(value),
];

/// The UnixFS protobuf Data message used inside DAG-PB nodes.
class UnixFsData {
  UnixFsData(
    this.type, {
    List<int> data = const <int>[],
    this.filesize = 0,
    Iterable<int> blocksizes = const [],
    this.hashType,
    this.fanout,
    this.mode,
    this.mtimeSeconds,
    this.mtimeNanos,
  }) : data = Uint8List.fromList(data),
       blocksizes = List.unmodifiable(blocksizes);

  factory UnixFsData.fromBytes(Uint8List bytes) {
    var offset = 0;
    UnixFsDataType? type;
    Uint8List data = Uint8List(0);
    var filesize = 0;
    final blocksizes = <int>[];
    int? hashType;
    int? fanout;
    int? mode;
    int? seconds;
    int? nanos;
    while (offset < bytes.length) {
      final (tag, tagLength) = readVarint(bytes, offset);
      offset += tagLength;
      final field = tag >> 3;
      final wire = tag & 7;
      if (wire == 2) {
        final (length, lengthLength) = readVarint(bytes, offset);
        offset += lengthLength;
        if (offset + length > bytes.length)
          throw const FormatException('truncated UnixFS bytes');
        final value = bytes.sublist(offset, offset + length);
        offset += length;
        if (field == 2) data = Uint8List.fromList(value);
        if (field == 8) {
          var timestampOffset = 0;
          while (timestampOffset < value.length) {
            final (timestampTag, tagLength) = readVarint(
              value,
              timestampOffset,
            );
            timestampOffset += tagLength;
            if ((timestampTag & 7) == 0) {
              final (timestampValue, valueLength) = readVarint(
                value,
                timestampOffset,
              );
              timestampOffset += valueLength;
              if (timestampTag >> 3 == 1) seconds = timestampValue;
            } else if ((timestampTag & 7) == 5) {
              if (timestampOffset + 4 > value.length)
                throw const FormatException('truncated UnixFS timestamp');
              final timestampValue =
                  value[timestampOffset] |
                  value[timestampOffset + 1] << 8 |
                  value[timestampOffset + 2] << 16 |
                  value[timestampOffset + 3] << 24;
              timestampOffset += 4;
              if (timestampTag >> 3 == 2) nanos = timestampValue;
            } else {
              throw const FormatException('invalid UnixFS timestamp');
            }
          }
        }
      } else if (wire == 0) {
        final (value, valueLength) = readVarint(bytes, offset);
        offset += valueLength;
        switch (field) {
          case 1:
            type = _typeFromWire(value);
            break;
          case 3:
            filesize = value;
            break;
          case 4:
            blocksizes.add(value);
            break;
          case 5:
            hashType = value;
            break;
          case 6:
            fanout = value;
            break;
          case 7:
            mode = value;
            break;
        }
      } else if (wire == 1 && field == 8) {
        if (offset + 8 > bytes.length)
          throw const FormatException('truncated UnixFS timestamp');
        offset += 8;
      } else if (wire == 2 && field == 8) {
        // IPFSTimestamp is an embedded message, handled below by the generic
        // length-delimited branch when this field is encountered.
      } else {
        throw FormatException('unsupported UnixFS protobuf wire type: $wire');
      }
    }
    if (type == null)
      throw const FormatException('UnixFS Data.Type is required');
    return UnixFsData(
      type,
      data: data,
      filesize: filesize,
      blocksizes: blocksizes,
      hashType: hashType,
      fanout: fanout,
      mode: mode,
      mtimeSeconds: seconds,
      mtimeNanos: nanos,
    );
  }

  final UnixFsDataType type;
  final Uint8List data;
  final int filesize;
  final List<int> blocksizes;
  final int? hashType;
  final int? fanout;
  final int? mode;
  final int? mtimeSeconds;
  final int? mtimeNanos;

  Uint8List toBytes() {
    final out = <int>[..._uvarint(1, type.wireValue)];
    if (data.isNotEmpty) out.addAll(_bytesField(2, data));
    // Boxo initializes Filesize even when it is zero; preserving that field is
    // important for Cid compatibility with empty and leaf File nodes.
    out.addAll(_uvarint(3, filesize));
    for (final size in blocksizes) out.addAll(_uvarint(4, size));
    if (hashType != null) out.addAll(_uvarint(5, hashType!));
    if (fanout != null) out.addAll(_uvarint(6, fanout!));
    if (mode != null) out.addAll(_uvarint(7, mode!));
    if (mtimeSeconds != null) {
      final timestamp = <int>[..._uvarint(1, mtimeSeconds!)];
      if (mtimeNanos != null)
        timestamp.addAll(<int>[0x15, ..._fixed32(mtimeNanos!)]);
      out.addAll(_bytesField(8, timestamp));
    }
    return Uint8List.fromList(out);
  }
}

List<int> _fixed32(int value) => <int>[
  value & 255,
  (value >> 8) & 255,
  (value >> 16) & 255,
  (value >> 24) & 255,
];

Uint8List wrapData(Uint8List data) =>
    UnixFsData(UnixFsDataType.raw, data: data, filesize: data.length).toBytes();
Uint8List filePbData(Uint8List data, int totalSize) =>
    UnixFsData(UnixFsDataType.file, data: data, filesize: totalSize).toBytes();
Uint8List folderPbData() => UnixFsData(UnixFsDataType.directory).toBytes();

Uint8List unwrapData(Uint8List bytes) => UnixFsData.fromBytes(bytes).data;

int dataSize(Uint8List bytes) {
  final node = UnixFsData.fromBytes(bytes);
  if (node.type == UnixFsDataType.directory ||
      node.type == UnixFsDataType.hamtShard) {
    throw StateError("can't get data size of directory");
  }
  return node.type == UnixFsDataType.symlink ? node.data.length : node.filesize;
}
