// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `errors.go` (github.com/pion/datachannel).
library;

class DataChannelMessageTooShortException implements Exception {
  const DataChannelMessageTooShortException();
  @override
  String toString() =>
      'DataChannel message is not long enough to determine type';
}

class InvalidPayloadProtocolIdentifierException implements Exception {
  const InvalidPayloadProtocolIdentifierException([this.info = '']);
  final String info;
  @override
  String toString() =>
      'DataChannel message Payload Protocol Identifier is value we cannot handle: $info';
}

class InvalidChannelTypeException implements Exception {
  const InvalidChannelTypeException([this.info = '']);
  final String info;
  @override
  String toString() => 'invalid Channel Type: $info';
}

class InvalidMessageTypeException implements Exception {
  const InvalidMessageTypeException([this.info = '']);
  final String info;
  @override
  String toString() => 'invalid Message Type: $info';
}

class ExpectedAndActualLengthMismatchException implements Exception {
  const ExpectedAndActualLengthMismatchException();
  @override
  String toString() => 'expected and actual length do not match';
}

class UnexpectedDataChannelTypeException implements Exception {
  const UnexpectedDataChannelTypeException([this.info = '']);
  final String info;
  @override
  String toString() => 'expected and actual message type does not match: $info';
}
