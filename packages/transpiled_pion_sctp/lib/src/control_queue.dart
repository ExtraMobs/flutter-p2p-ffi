// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `control_queue.go` (github.com/pion/sctp): [ControlQueue], the
/// plain FIFO of outbound control [Packet]s (INIT, INIT-ACK, COOKIE-ECHO,
/// COOKIE-ACK, SACK, ...) an `Association` drains every time its write loop
/// gathers outbound packets.
///
/// `controlQueue` is unexported in Go; [ControlQueue] stays public within
/// `lib/src` (see util.dart's file-level doc comment) but is not exported
/// from `transpiled_pion_sctp.dart`.
library;

import 'packet.dart';

/// Port of `controlQueue` (control_queue.go:8-10).
final class ControlQueue {
  /// Port of `newControlQueue` (control_queue.go:12-14).
  ControlQueue() : _queue = <Packet>[];

  List<Packet> _queue;

  /// Port of `controlQueue.push` (control_queue.go:16-18).
  void push(Packet c) => _queue.add(c);

  /// Port of `controlQueue.pushAll` (control_queue.go:20-22).
  void pushAll(List<Packet> packets) => _queue.addAll(packets);

  /// Port of `controlQueue.popAll` (control_queue.go:24-29).
  List<Packet> popAll() {
    final packets = _queue;
    _queue = <Packet>[];
    return packets;
  }

  /// Port of `controlQueue.size` (control_queue.go:31-33).
  int size() => _queue.length;
}
