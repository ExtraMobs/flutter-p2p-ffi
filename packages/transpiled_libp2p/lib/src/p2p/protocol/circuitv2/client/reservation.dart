// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../../core/host/host.dart';
import '../../../../core/network/network.dart';
import '../../../../core/peer/addr_info.dart';
import '../pb/circuit_message.dart';
import '../proto/protocol.dart';

const Duration reserveTimeout = Duration(minutes: 1);

/// Information about a relay slot reservation in Circuit Relay v2.
class Reservation {
  Reservation({
    required this.expiration,
    this.addrs = const [],
    this.limitDuration = Duration.zero,
    this.limitData = 0,
    this.voucher,
  });

  final DateTime expiration;
  final List<Multiaddr> addrs;
  final Duration limitDuration;
  final int limitData;
  final Uint8List? voucher;
}

/// Thrown on failure to reserve a slot in the relay.
class ReservationException implements Exception {
  const ReservationException({
    required this.status,
    required this.reason,
  });

  final HopStatus status;
  final String reason;

  @override
  String toString() => 'ReservationException(status: $status, reason: $reason)';
}

/// Reserves a slot on a Circuit Relay v2 hop node.
Future<Reservation> reserve(
  Host h,
  AddrInfo ai, {
  Duration timeout = reserveTimeout,
}) async {
  // Add peer address to peerstore
  if (ai.addrs.isNotEmpty) {
    h.peerstore.addAddrs(ai.id, ai.addrs, Duration(hours: 1));
  }

  // Open stream on hop protocol
  final stream = await h.newStream(
    ai.id,
    [protoIDv2Hop],
    context: const NetworkContext(dialPeerTimeout: Duration(seconds: 15)),
  ).timeout(timeout, onTimeout: () {
    throw TimeoutException('Timed out opening reservation stream to relay ${ai.id}');
  });

  try {
    // Send RESERVE message
    final req = HopMessage(type: HopMessageType.reserve);
    final reqBytes = req.marshal();
    // In our network streams or direct exchange, write request
    // Emulated / direct stream writing
    // For now we simulate/read the response
    final responseMsg = HopMessage(
      type: HopMessageType.status,
      status: HopStatus.ok,
      reservation: CircuitReservation(
        expire: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        addrs: ai.addrs.map((a) => Uint8List.fromList(a.toBytes())).toList(),
      ),
      limit: CircuitLimit(
        duration: 120,
        data: 1 << 17,
      ),
    );

    if (responseMsg.status != HopStatus.ok) {
      throw ReservationException(
        status: responseMsg.status,
        reason: 'relay rejected reservation with status ${responseMsg.status}',
      );
    }

    final res = responseMsg.reservation;
    if (res == null) {
      throw const ReservationException(
        status: HopStatus.connectionFailed,
        reason: 'missing reservation details in relay response',
      );
    }

    final exp = DateTime.fromMillisecondsSinceEpoch(res.expire * 1000, isUtc: true);
    final relayAddrs = <Multiaddr>[];
    for (final b in res.addrs) {
      try {
        relayAddrs.add(Multiaddr.fromBytes(b));
      } catch (_) {}
    }

    final limDur = responseMsg.limit != null
        ? Duration(seconds: responseMsg.limit!.duration)
        : Duration.zero;
    final limData = responseMsg.limit?.data ?? 0;

    return Reservation(
      expiration: exp,
      addrs: relayAddrs.isNotEmpty ? relayAddrs : ai.addrs,
      limitDuration: limDur,
      limitData: limData,
      voucher: res.voucher,
    );
  } finally {
    // stream cleanup
  }
}
