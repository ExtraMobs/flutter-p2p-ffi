import 'dart:typed_data';

import '../../../../core/crypto/proto_varint.dart';

enum HolePunchMessageType {
  connect(100),
  sync(300);

  const HolePunchMessageType(this.code);
  final int code;

  static HolePunchMessageType fromCode(int code) {
    for (final t in HolePunchMessageType.values) {
      if (t.code == code) return t;
    }
    return HolePunchMessageType.connect;
  }
}

class HolePunchMessage {
  HolePunchMessage({
    required this.type,
    this.obsAddrs = const [],
  });

  final HolePunchMessageType type;
  final List<Uint8List> obsAddrs;

  Uint8List marshal() {
    final bytes = <int>[];

    // Field 1: type (varint) tag (1 << 3) | 0 = 8
    bytes.add(8);
    bytes.addAll(encodeProtoVarint(type.code));

    // Field 2: ObsAddrs repeated bytes tag (2 << 3) | 2 = 18
    for (final addr in obsAddrs) {
      bytes.add(18);
      bytes.addAll(encodeProtoVarint(addr.length));
      bytes.addAll(addr);
    }

    return Uint8List.fromList(bytes);
  }

  static HolePunchMessage unmarshal(Uint8List data) {
    var offset = 0;
    var type = HolePunchMessageType.connect;
    final obsAddrs = <Uint8List>[];

    while (offset < data.length) {
      final tagByte = data[offset++];
      final fieldNumber = tagByte >> 3;
      final wireType = tagByte & 0x07;

      if (wireType == 0) {
        // Varint
        var res = 0;
        var shift = 0;
        while (offset < data.length) {
          final b = data[offset++];
          res |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        if (fieldNumber == 1) {
          type = HolePunchMessageType.fromCode(res);
        }
      } else if (wireType == 2) {
        // Length-delimited
        var len = 0;
        var shift = 0;
        while (offset < data.length) {
          final b = data[offset++];
          len |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        final bytes = data.sublist(offset, offset + len);
        offset += len;

        if (fieldNumber == 2) {
          obsAddrs.add(bytes);
        }
      } else {
        // Skip unknown wire types safely
        break;
      }
    }

    return HolePunchMessage(
      type: type,
      obsAddrs: obsAddrs,
    );
  }
}
