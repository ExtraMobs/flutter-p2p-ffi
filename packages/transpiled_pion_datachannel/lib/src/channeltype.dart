// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `message_channel_open.go` ChannelType (github.com/pion/datachannel).
library;

enum ChannelType {
  reliable(0x00),
  reliableUnordered(0x80),
  partialReliableRexmit(0x01),
  partialReliableRexmitUnordered(0x81),
  partialReliableTimed(0x02),
  partialReliableTimedUnordered(0x82);

  const ChannelType(this.value);
  final int value;

  static ChannelType fromValue(int v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return reliable;
  }

  String string() {
    switch (this) {
      case ChannelType.reliable:
        return 'Unknown';
      case ChannelType.reliableUnordered:
        return 'ReliableUnordered';
      case ChannelType.partialReliableRexmit:
        return 'PartialReliableRexmit';
      case ChannelType.partialReliableRexmitUnordered:
        return 'PartialReliableRexmitUnordered';
      case ChannelType.partialReliableTimed:
        return 'PartialReliableTimed';
      case ChannelType.partialReliableTimedUnordered:
        return 'PartialReliableTimedUnordered';
    }
  }

  @override
  String toString() => string();
}
