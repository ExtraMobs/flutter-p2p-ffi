// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `datachannel.go` Config struct (github.com/pion/datachannel).
library;

import 'channeltype.dart';

class Config {
  Config({
    this.channelType = ChannelType.reliable,
    this.negotiated = false,
    this.priority = 0,
    this.reliabilityParameter = 0,
    this.label = '',
    this.protocol = '',
    this.loggerFactory,
  });

  ChannelType channelType;
  bool negotiated;
  int priority;
  int reliabilityParameter;
  String label;
  String protocol;
  dynamic loggerFactory;
}
