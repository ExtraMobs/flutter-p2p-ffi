// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `message_channel_open.go` (github.com/pion/datachannel).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'channeltype.dart';
import 'errors.dart';

const int channelOpenHeaderLength = 12;
const int dataChannelOpen = 0x03;

class ChannelOpen {
  ChannelOpen({
    this.channelType = ChannelType.reliable,
    this.priority = 0,
    this.reliabilityParameter = 0,
    Uint8List? label,
    Uint8List? protocol,
  }) : label = label ?? Uint8List(0),
       protocol = protocol ?? Uint8List(0);

  ChannelType channelType;
  int priority;
  int reliabilityParameter;
  Uint8List label;
  Uint8List protocol;

  Uint8List marshal() {
    final raw = Uint8List(
      channelOpenHeaderLength + label.length + protocol.length,
    );
    final view = ByteData.sublistView(raw);
    view.setUint8(0, dataChannelOpen);
    view.setUint8(1, channelType.value);
    view.setUint16(2, priority & 0xFFFF, Endian.big);
    view.setUint32(4, reliabilityParameter & 0xFFFFFFFF, Endian.big);
    view.setUint16(8, label.length & 0xFFFF, Endian.big);
    view.setUint16(10, protocol.length & 0xFFFF, Endian.big);

    var offset = channelOpenHeaderLength;
    raw.setRange(offset, offset + label.length, label);
    offset += label.length;
    raw.setRange(offset, offset + protocol.length, protocol);

    return raw;
  }

  void unmarshal(Uint8List raw) {
    if (raw.length < channelOpenHeaderLength) {
      throw const DataChannelMessageTooShortException();
    }
    final view = ByteData.sublistView(raw);
    if (view.getUint8(0) != dataChannelOpen) {
      throw UnexpectedDataChannelTypeException(
        'expected($dataChannelOpen) actual(${view.getUint8(0)})',
      );
    }
    channelType = ChannelType.fromValue(view.getUint8(1));
    priority = view.getUint16(2, Endian.big);
    reliabilityParameter = view.getUint32(4, Endian.big);
    final labelLen = view.getUint16(8, Endian.big);
    final protoLen = view.getUint16(10, Endian.big);

    if (raw.length < channelOpenHeaderLength + labelLen + protoLen) {
      throw const ExpectedAndActualLengthMismatchException();
    }

    var offset = channelOpenHeaderLength;
    label = Uint8List.fromList(raw.sublist(offset, offset + labelLen));
    offset += labelLen;
    protocol = Uint8List.fromList(raw.sublist(offset, offset + protoLen));
  }

  String string() =>
      'Open ChannelType(${channelType.string()}) Priority($priority) ReliabilityParameter($reliabilityParameter) Label(${utf8.decode(label, allowMalformed: true)}) Protocol(${utf8.decode(protocol, allowMalformed: true)})';

  @override
  String toString() => string();
}
