// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `message_channel_ack.go` (github.com/pion/datachannel).
library;

import 'dart:typed_data';

const int channelOpenAckLength = 4;
const int dataChannelAck = 0x02;

class ChannelAck {
  Uint8List marshal() {
    final raw = Uint8List(channelOpenAckLength);
    raw[0] = dataChannelAck;
    return raw;
  }

  void unmarshal(Uint8List raw) {
    // Message type already checked and there is no further data
  }

  String string() => 'ACK';

  @override
  String toString() => string();
}
