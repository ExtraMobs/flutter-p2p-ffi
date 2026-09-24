import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetAddr;

/// AddrPacket is a packet payload and the associated remote address.
class AddrPacket {
  NetAddr addr;
  Uint8List data;

  AddrPacket({required this.addr, required this.data});
}

/// PacketBuffer is a circular/queued buffer for network packets.
class PacketBuffer {
  final List<AddrPacket> _packets = [];
  bool _closed = false;
  Completer<void>? _notify;
  DateTime? _readDeadline;

  PacketBuffer();

  /// WriteTo writes a single packet to the buffer.
  int writeTo(Uint8List pkt, NetAddr addr) {
    if (_closed) {
      throw StateError('closed pipe');
    }
    _packets.add(AddrPacket(addr: addr, data: Uint8List.fromList(pkt)));
    if (_notify != null && !_notify!.isCompleted) {
      _notify!.complete();
      _notify = null;
    }
    return pkt.length;
  }

  /// ReadFrom reads a single packet payload and its associated remote address.
  Future<(int, NetAddr)> readFrom(Uint8List buff) async {
    while (_packets.isEmpty) {
      if (_closed) {
        throw StateError('closed pipe');
      }
      if (_readDeadline != null && DateTime.now().isAfter(_readDeadline!)) {
        throw TimeoutException('read deadline reached');
      }
      _notify = Completer<void>();
      if (_readDeadline != null) {
        final timeout = _readDeadline!.difference(DateTime.now());
        if (timeout.isNegative) {
          throw TimeoutException('read deadline reached');
        }
        await _notify!.future.timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException('read deadline reached');
          },
        );
      } else {
        await _notify!.future;
      }
    }

    final pkt = _packets.removeAt(0);
    final toCopy = pkt.data.length > buff.length
        ? buff.length
        : pkt.data.length;
    buff.setRange(0, toCopy, pkt.data);
    return (toCopy, pkt.addr);
  }

  /// Close closes the buffer.
  void close() {
    _closed = true;
    if (_notify != null && !_notify!.isCompleted) {
      _notify!.complete();
    }
  }

  /// SetReadDeadline sets the read deadline.
  void setReadDeadline(DateTime? t) {
    _readDeadline = t;
  }
}
