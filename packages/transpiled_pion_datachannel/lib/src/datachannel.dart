// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

/// Port of `datachannel.go` (github.com/pion/datachannel).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_pion_sctp/transpiled_pion_sctp.dart' as pion_sctp;

import 'channeltype.dart';
import 'config.dart';
import 'errors.dart';
import 'interfaces.dart';
import 'message.dart';
import 'message_channel_ack.dart';
import 'message_channel_open.dart';

const int defaultReceiveMtu = 8192;

class DataChannel implements ReadWriteCloserDeadliner {
  DataChannel({required this.stream, required this.config});

  final pion_sctp.Stream stream;
  final Config config;

  int _messagesSent = 0;
  int _messagesReceived = 0;
  int _bytesSent = 0;
  int _bytesReceived = 0;

  void Function()? _onOpenHandler;
  bool _openHandlerCalled = false;

  @override
  Future<int> read(Uint8List p) async {
    final (n, _) = await readDataChannel(p);
    return n;
  }

  @override
  Future<(int, bool)> readDataChannel(Uint8List p) async {
    while (true) {
      final (n, ppi) = await stream.readSctp(p);
      if (ppi == pion_sctp.PayloadProtocolIdentifier.webRtcDcep) {
        final raw = Uint8List.sublistView(p, 0, n);
        final msg = parse(raw);
        if (msg is ChannelAck) {
          _commitReliabilityParams();
          _onOpenComplete();
        }
        continue;
      }

      var bytesRead = n;
      if (ppi == pion_sctp.PayloadProtocolIdentifier.webRtcBinaryEmpty ||
          ppi == pion_sctp.PayloadProtocolIdentifier.webRtcStringEmpty) {
        bytesRead = 0;
      }

      _messagesReceived++;
      _bytesReceived += bytesRead;

      final isString =
          ppi == pion_sctp.PayloadProtocolIdentifier.webRtcString ||
          ppi == pion_sctp.PayloadProtocolIdentifier.webRtcStringEmpty;
      return (bytesRead, isString);
    }
  }

  @override
  Future<void> setReadDeadline(DateTime? t) async {
    stream.setReadDeadline(t);
  }

  @override
  Future<void> setWriteDeadline(DateTime? t) async {
    stream.setWriteDeadline(t);
  }

  int messagesSent() => _messagesSent;
  int messagesReceived() => _messagesReceived;

  void onOpen(void Function() f) {
    _onOpenHandler = f;
  }

  void _onOpenComplete() {
    if (!_openHandlerCalled) {
      _openHandlerCalled = true;
      _onOpenHandler?.call();
    }
  }

  int bytesSent() => _bytesSent;
  int bytesReceived() => _bytesReceived;

  int streamIdentifier() => stream.streamIdentifier();

  @override
  Future<int> write(Uint8List p) => writeDataChannel(p, false);

  @override
  Future<int> writeDataChannel(Uint8List p, bool isString) async {
    final pion_sctp.PayloadProtocolIdentifier ppi;
    if (!isString && p.isNotEmpty) {
      ppi = pion_sctp.PayloadProtocolIdentifier.webRtcBinary;
    } else if (!isString && p.isEmpty) {
      ppi = pion_sctp.PayloadProtocolIdentifier.webRtcBinaryEmpty;
    } else if (isString && p.isNotEmpty) {
      ppi = pion_sctp.PayloadProtocolIdentifier.webRtcString;
    } else {
      ppi = pion_sctp.PayloadProtocolIdentifier.webRtcStringEmpty;
    }

    _messagesSent++;
    _bytesSent += p.length;

    if (p.isEmpty) {
      await stream.writeSctp(Uint8List.fromList([0]), ppi);
      return 0;
    }
    return stream.writeSctp(p, ppi);
  }

  @override
  Future<void> close() async {
    await stream.close();
  }

  int bufferedAmount() => stream.bufferedAmount();
  int bufferedAmountLowThreshold() => stream.bufferedAmountLowThreshold();

  void setBufferedAmountLowThreshold(int th) {
    stream.setBufferedAmountLowThreshold(th);
  }

  void onBufferedAmountLow(void Function() f) {
    stream.onBufferedAmountLow(f);
  }

  void _commitReliabilityParams() {
    switch (config.channelType) {
      case ChannelType.reliable:
        stream.setReliabilityParams(false, 0, config.reliabilityParameter);
      case ChannelType.reliableUnordered:
        stream.setReliabilityParams(true, 0, config.reliabilityParameter);
      case ChannelType.partialReliableRexmit:
        stream.setReliabilityParams(false, 1, config.reliabilityParameter);
      case ChannelType.partialReliableRexmitUnordered:
        stream.setReliabilityParams(true, 1, config.reliabilityParameter);
      case ChannelType.partialReliableTimed:
        stream.setReliabilityParams(false, 2, config.reliabilityParameter);
      case ChannelType.partialReliableTimedUnordered:
        stream.setReliabilityParams(true, 2, config.reliabilityParameter);
    }
  }
}

Future<DataChannel> dial(pion_sctp.Association a, int id, Config config) async {
  final stream = await a.openStream(
    id,
    pion_sctp.PayloadProtocolIdentifier.webRtcBinary,
  );
  return client(stream, config);
}

Future<DataChannel> client(pion_sctp.Stream stream, Config config) async {
  final msg = ChannelOpen(
    channelType: config.channelType,
    priority: config.priority,
    reliabilityParameter: config.reliabilityParameter,
    label: Uint8List.fromList(utf8.encode(config.label)),
    protocol: Uint8List.fromList(utf8.encode(config.protocol)),
  );

  if (!config.negotiated) {
    final rawMsg = msg.marshal();
    await stream.writeSctp(
      rawMsg,
      pion_sctp.PayloadProtocolIdentifier.webRtcDcep,
    );
  }

  final dc = DataChannel(stream: stream, config: config);
  dc._commitReliabilityParams();
  return dc;
}

Future<DataChannel> accept(
  pion_sctp.Association a,
  Config config, [
  List<DataChannel> existingChannels = const [],
]) async {
  final stream = await a.acceptStream();
  for (final ch in existingChannels) {
    if (ch.streamIdentifier() == stream.streamIdentifier()) {
      ch.stream.setDefaultPayloadType(
        pion_sctp.PayloadProtocolIdentifier.webRtcBinary,
      );
      return ch;
    }
  }
  stream.setDefaultPayloadType(
    pion_sctp.PayloadProtocolIdentifier.webRtcBinary,
  );
  return server(stream, config);
}

Future<DataChannel> server(pion_sctp.Stream stream, Config config) async {
  final buffer = Uint8List(defaultReceiveMtu);
  final (n, ppi) = await stream.readSctp(buffer);

  if (ppi != pion_sctp.PayloadProtocolIdentifier.webRtcDcep) {
    throw InvalidPayloadProtocolIdentifierException('$ppi');
  }

  final openMsg = parseExpectDataChannelOpen(
    Uint8List.sublistView(buffer, 0, n),
  );
  config.channelType = openMsg.channelType;
  config.priority = openMsg.priority;
  config.reliabilityParameter = openMsg.reliabilityParameter;
  config.label = utf8.decode(openMsg.label, allowMalformed: true);
  config.protocol = utf8.decode(openMsg.protocol, allowMalformed: true);

  final dataChannel = DataChannel(stream: stream, config: config);

  // Write ACK
  final ack = ChannelAck();
  final ackMsg = ack.marshal();
  await stream.writeSctp(
    ackMsg,
    pion_sctp.PayloadProtocolIdentifier.webRtcDcep,
  );

  dataChannel._commitReliabilityParams();
  return dataChannel;
}
