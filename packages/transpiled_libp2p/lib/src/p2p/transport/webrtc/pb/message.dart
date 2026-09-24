// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

/// Message_Flag represents the flag field of the WebRTC framing Message.
enum Message_Flag {
  FIN(0),
  STOP_SENDING(1),
  RESET(2),
  FIN_ACK(3);

  const Message_Flag(this.value);
  final int value;

  Message_Flag enum_() => this;
  String string() => name;
  String descriptor() => name;
  String type() => 'Message_Flag';
  int number() => value;
  void unmarshalJson(Uint8List b) {}
  String enumDescriptor() => 'Message_Flag';
}

/// Message represents the WebRTC data channel framing message.
class Message {
  Message({this.flag, this.message, this.errorCode});

  Message_Flag? flag;
  Uint8List? message;
  int? errorCode;

  void reset() {
    flag = null;
    message = null;
    errorCode = null;
  }

  String string() {
    return 'Message(flag: $flag, messageLen: ${message?.length ?? 0}, errorCode: $errorCode)';
  }

  @override
  String toString() => string();

  void protoMessage() {}
  dynamic protoReflect() => this;
  String descriptor() => 'Message';

  Message_Flag? getFlag() => flag;
  Uint8List? getMessage() => message;
  int? getErrorCode() => errorCode;

  /// Marshals this Message into protobuf binary wire format.
  Uint8List marshal() {
    final bytes = <int>[];

    // Field 1: flag (varint, tag = 1 << 3 | 0 = 0x08)
    if (flag != null) {
      bytes.add(0x08);
      bytes.addAll(_encodeVarint(flag!.value));
    }

    // Field 2: message (bytes, tag = 2 << 3 | 2 = 0x12)
    if (message != null && message!.isNotEmpty) {
      bytes.add(0x12);
      bytes.addAll(_encodeVarint(message!.length));
      bytes.addAll(message!);
    }

    // Field 3: errorCode (varint, tag = 3 << 3 | 0 = 0x18)
    if (errorCode != null) {
      bytes.add(0x18);
      bytes.addAll(_encodeVarint(errorCode!));
    }

    return Uint8List.fromList(bytes);
  }

  /// Unmarshals this Message from protobuf binary wire format.
  void unmarshal(Uint8List data) {
    reset();
    var offset = 0;
    while (offset < data.length) {
      final (tag, newOffset) = _decodeVarint(data, offset);
      offset = newOffset;
      final wireType = tag & 0x07;
      final fieldNumber = tag >> 3;

      if (fieldNumber == 1 && wireType == 0) {
        final (val, nextOffset) = _decodeVarint(data, offset);
        offset = nextOffset;
        for (final f in Message_Flag.values) {
          if (f.value == val) {
            flag = f;
            break;
          }
        }
      } else if (fieldNumber == 2 && wireType == 2) {
        final (len, nextOffset) = _decodeVarint(data, offset);
        offset = nextOffset;
        if (offset + len <= data.length) {
          message = Uint8List.fromList(data.sublist(offset, offset + len));
          offset += len;
        } else {
          break;
        }
      } else if (fieldNumber == 3 && wireType == 0) {
        final (val, nextOffset) = _decodeVarint(data, offset);
        offset = nextOffset;
        errorCode = val;
      } else {
        // Skip unknown field
        if (wireType == 0) {
          final (_, nextOffset) = _decodeVarint(data, offset);
          offset = nextOffset;
        } else if (wireType == 2) {
          final (len, nextOffset) = _decodeVarint(data, offset);
          offset = nextOffset + len;
        } else {
          break;
        }
      }
    }
  }

  static List<int> _encodeVarint(int value) {
    final res = <int>[];
    var v = value;
    while (v >= 0x80) {
      res.add((v & 0x7f) | 0x80);
      v >>= 7;
    }
    res.add(v & 0x7f);
    return res;
  }

  static (int, int) _decodeVarint(Uint8List data, int offset) {
    var result = 0;
    var shift = 0;
    var pos = offset;
    while (pos < data.length) {
      final b = data[pos++];
      result |= (b & 0x7f) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return (result, pos);
  }
}
