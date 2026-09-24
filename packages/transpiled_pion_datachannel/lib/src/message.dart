// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `message.go` (github.com/pion/datachannel).
library;

import 'dart:typed_data';

import 'errors.dart';
import 'message_channel_ack.dart';
import 'message_channel_open.dart';

enum MessageType {
  dataChannelAck(0x02),
  dataChannelOpen(0x03);

  const MessageType(this.value);
  final int value;

  String string() {
    switch (this) {
      case MessageType.dataChannelAck:
        return 'DataChannelAck';
      case MessageType.dataChannelOpen:
        return 'DataChannelOpen';
    }
  }

  @override
  String toString() => string();
}

Object parse(Uint8List raw) {
  if (raw.isEmpty) {
    throw const DataChannelMessageTooShortException();
  }

  final typ = raw[0];
  if (typ == MessageType.dataChannelOpen.value) {
    final msg = ChannelOpen();
    msg.unmarshal(raw);
    return msg;
  } else if (typ == MessageType.dataChannelAck.value) {
    final msg = ChannelAck();
    msg.unmarshal(raw);
    return msg;
  }
  throw InvalidMessageTypeException('$typ');
}

ChannelOpen parseExpectDataChannelOpen(Uint8List raw) {
  if (raw.isEmpty) {
    throw const DataChannelMessageTooShortException();
  }
  if (raw[0] != MessageType.dataChannelOpen.value) {
    throw UnexpectedDataChannelTypeException(
      'expected(${MessageType.dataChannelOpen.value}) actual(${raw[0]})',
    );
  }
  final msg = ChannelOpen();
  msg.unmarshal(raw);
  return msg;
}

int tryMarshalUnmarshal(Uint8List msg) {
  try {
    final parsed = parse(msg);
    if (parsed is ChannelOpen) {
      final raw = parsed.marshal();
      final re = ChannelOpen()..unmarshal(raw);
      if (re.channelType != parsed.channelType) return 0;
      return 1;
    } else if (parsed is ChannelAck) {
      final raw = parsed.marshal();
      ChannelAck().unmarshal(raw);
      return 1;
    }
    return 0;
  } catch (_) {
    return 0;
  }
}
