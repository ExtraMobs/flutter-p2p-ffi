// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_pion_datachannel/transpiled_pion_datachannel.dart'
    as pion_datachannel;

import '../../../core/network/network.dart';
import 'pb/message.dart';

const int maxSendMessageSize = 16384;
const int maxReceiveMessageSize = 256 * 1024 + 1024;

/// Stream implements a libp2p MuxedStream over a Pion DataChannel.
class Stream implements MuxedStream {
  Stream({
    required this.channel,
    this.maxMessageSize = maxSendMessageSize,
    this.onDone,
  });

  final pion_datachannel.DataChannel channel;
  final int maxMessageSize;
  final void Function()? onDone;

  bool _closed = false;
  bool _readClosed = false;
  bool _writeClosed = false;

  final List<int> _readBuffer = [];
  Completer<void>? _readWaiter;

  DateTime? _readDeadline;
  DateTime? _writeDeadline;

  int? _resetErrorCode;

  bool get isClosed => _closed;

  @override
  Future<int> read(Uint8List b) async {
    if (_readClosed) return 0;
    while (_readBuffer.isEmpty) {
      if (_closed) return 0;
      if (_readDeadline != null && DateTime.now().isAfter(_readDeadline!)) {
        throw TimeoutException('read deadline reached');
      }

      // Read raw chunk from data channel
      final rawBuf = Uint8List(maxReceiveMessageSize);
      final (n, isString) = await channel.readDataChannel(rawBuf);
      if (n <= 0) return 0;

      final slice = Uint8List.sublistView(rawBuf, 0, n);
      _processInbound(slice);
    }

    final toCopy = b.length < _readBuffer.length
        ? b.length
        : _readBuffer.length;
    for (var i = 0; i < toCopy; i++) {
      b[i] = _readBuffer.removeAt(0);
    }
    return toCopy;
  }

  void _processInbound(Uint8List raw) {
    var offset = 0;
    while (offset < raw.length) {
      // Decode varint length
      var len = 0;
      var shift = 0;
      while (offset < raw.length) {
        final b = raw[offset++];
        len |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }

      if (len <= 0 || offset + len > raw.length) {
        // Fallback: direct payload
        _readBuffer.addAll(raw.sublist(offset));
        break;
      }

      final msgBytes = Uint8List.sublistView(raw, offset, offset + len);
      offset += len;

      final msg = Message();
      msg.unmarshal(msgBytes);

      if (msg.flag != null) {
        switch (msg.flag!) {
          case Message_Flag.FIN:
            _readClosed = true;
          case Message_Flag.STOP_SENDING:
            _writeClosed = true;
          case Message_Flag.RESET:
            _closed = true;
            _readClosed = true;
            _writeClosed = true;
            _resetErrorCode = msg.errorCode;
          case Message_Flag.FIN_ACK:
            break;
        }
      }

      if (msg.message != null && msg.message!.isNotEmpty) {
        _readBuffer.addAll(msg.message!);
      }
    }

    final waiter = _readWaiter;
    _readWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  @override
  Future<int> write(Uint8List b) async {
    if (_closed || _writeClosed) throw StateError('stream write closed');
    if (_writeDeadline != null && DateTime.now().isAfter(_writeDeadline!)) {
      throw TimeoutException('write deadline reached');
    }

    var total = 0;
    while (total < b.length) {
      final chunkLen = (b.length - total) > maxMessageSize
          ? maxMessageSize
          : (b.length - total);
      final chunk = Uint8List.sublistView(b, total, total + chunkLen);

      final msg = Message(message: chunk);
      final rawMsg = msg.marshal();

      // Write with varint length prefix
      final framed = BytesBuilder(copy: false);
      _encodeVarint(framed, rawMsg.length);
      framed.add(rawMsg);

      await channel.write(framed.toBytes());
      total += chunkLen;
    }
    return total;
  }

  static void _encodeVarint(BytesBuilder b, int val) {
    var v = val;
    while (v >= 0x80) {
      b.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    b.addByte(v & 0x7f);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    await closeWrite();
    await closeRead();
    await channel.close();
    _closed = true;
    onDone?.call();
  }

  @override
  Future<void> closeRead() async {
    if (_readClosed) return;
    _readClosed = true;
    try {
      final msg = Message(flag: Message_Flag.STOP_SENDING);
      final raw = msg.marshal();
      final framed = BytesBuilder(copy: false);
      _encodeVarint(framed, raw.length);
      framed.add(raw);
      await channel.write(framed.toBytes());
    } catch (_) {}
  }

  @override
  Future<void> closeWrite() async {
    if (_writeClosed) return;
    _writeClosed = true;
    try {
      final msg = Message(flag: Message_Flag.FIN);
      final raw = msg.marshal();
      final framed = BytesBuilder(copy: false);
      _encodeVarint(framed, raw.length);
      framed.add(raw);
      await channel.write(framed.toBytes());
    } catch (_) {}
  }

  @override
  Future<void> reset() => resetWithError(0);

  Future<void> resetWithError(int err) async {
    if (_closed) return;
    _closed = true;
    _readClosed = true;
    _writeClosed = true;
    _resetErrorCode = err;
    try {
      final msg = Message(flag: Message_Flag.RESET, errorCode: err);
      final raw = msg.marshal();
      final framed = BytesBuilder(copy: false);
      _encodeVarint(framed, raw.length);
      framed.add(raw);
      await channel.write(framed.toBytes());
    } catch (_) {}
    await channel.close();
    onDone?.call();
  }

  @override
  void setDeadline(DateTime? t) {
    setReadDeadline(t);
    setWriteDeadline(t);
  }

  @override
  void setReadDeadline(DateTime? t) {
    _readDeadline = t;
  }

  @override
  void setWriteDeadline(DateTime? t) {
    _writeDeadline = t;
  }
}
