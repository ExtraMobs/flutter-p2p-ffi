// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../../core/crypto/proto_varint.dart';
import '../../../../core/host/host.dart';
import '../../../../core/network/network.dart';
import '../../../../core/peer/addr_info.dart';
import '../../../../core/peer/peer_id.dart';
import '../../../../core/record/envelope.dart';
import '../../../../core/record/record.dart';
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
  final ReservationVoucher? voucher;
}

/// Thrown on failure to reserve a slot in the relay.
class ReservationException implements Exception {
  const ReservationException({required this.status, required this.reason});

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
    h.peerstore.addAddrs(ai.id, ai.addrs, const Duration(hours: 1));
  }

  // Open stream on hop protocol
  final stream = await h
      .newStream(ai.id, [
        protoIDv2Hop,
      ], context: const NetworkContext(dialPeerTimeout: Duration(seconds: 15)))
      .timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Timed out opening reservation stream to relay ${ai.id}',
          );
        },
      );

  try {
    // Go bounds the whole exchange with ReserveTimeout, not just the dial.
    await stream.setDeadline(DateTime.now().add(timeout));

    // Send RESERVE message
    final req = HopMessage(type: HopMessageType.reserve);
    try {
      await _writeDelimited(stream, req.marshal());
    } catch (_) {
      await _reset(stream);
      throw const ReservationException(
        status: HopStatus.connectionFailed,
        reason: 'error writing reservation message',
      );
    }

    // Read HopMessage response from relay
    final Uint8List rawResp;
    try {
      rawResp = await _readDelimited(stream);
    } catch (_) {
      await _reset(stream);
      throw const ReservationException(
        status: HopStatus.connectionFailed,
        reason: 'error reading reservation response message',
      );
    }

    final responseMsg = HopMessage.unmarshal(rawResp);

    if (responseMsg.type != HopMessageType.status) {
      throw ReservationException(
        status: HopStatus.malformedMessage,
        reason:
            'unexpected relay response: not a status message '
            '(${responseMsg.type.index})',
      );
    }

    if (responseMsg.status != HopStatus.ok) {
      throw ReservationException(
        status: responseMsg.status,
        reason: 'reservation failed',
      );
    }

    final res = responseMsg.reservation;
    if (res == null) {
      throw const ReservationException(
        status: HopStatus.malformedMessage,
        reason: 'missing reservation info',
      );
    }

    final expiration = DateTime.fromMillisecondsSinceEpoch(
      res.expire * 1000,
      isUtc: true,
    );
    if (expiration.isBefore(DateTime.now().toUtc())) {
      throw ReservationException(
        status: HopStatus.malformedMessage,
        reason:
            'received reservation with expiration date in the past: '
            '$expiration',
      );
    }

    // Unparsable relay addresses are skipped, as upstream does.
    final relayAddrs = <Multiaddr>[];
    for (final b in res.addrs) {
      try {
        relayAddrs.add(Multiaddr.fromBytes(b));
      } catch (_) {
        continue;
      }
    }

    final voucher = await _consumeVoucher(h, res.voucher);
    final limit = responseMsg.limit;

    return Reservation(
      expiration: expiration,
      addrs: relayAddrs,
      limitDuration: limit != null
          ? Duration(seconds: limit.duration)
          : Duration.zero,
      limitData: limit?.data ?? 0,
      voucher: voucher,
    );
  } finally {
    try {
      await stream.close();
    } catch (_) {}
  }
}

/// Validates the relay's signed reservation voucher, per the second half of
/// go-libp2p's `Reserve`: the envelope must carry a [ReservationVoucher]
/// signed by the relay itself, vouching for this host.
Future<ReservationVoucher?> _consumeVoucher(
  Host h,
  Uint8List? voucherBytes,
) async {
  if (voucherBytes == null) return null;

  final Envelope envelope;
  final Record record;
  try {
    (envelope, record) = await Envelope.consumeEnvelope(
      voucherBytes,
      recordDomain,
    );
  } catch (e) {
    throw ReservationException(
      status: HopStatus.malformedMessage,
      reason: 'error consuming voucher envelope: $e',
    );
  }

  if (record is! ReservationVoucher) {
    throw ReservationException(
      status: HopStatus.malformedMessage,
      reason: 'unexpected voucher record type: ${record.runtimeType}',
    );
  }

  final PeerId signerPeerId;
  try {
    signerPeerId = PeerId.fromPubKey(envelope.publicKey);
  } catch (e) {
    throw ReservationException(
      status: HopStatus.malformedMessage,
      reason: 'invalid voucher signing public key: $e',
    );
  }

  if (signerPeerId != record.relay) {
    throw ReservationException(
      status: HopStatus.malformedMessage,
      reason:
          'invalid voucher relay id: expected '
          '${signerPeerId.toBase58()}, got ${record.relay.toBase58()}',
    );
  }

  if (h.id != record.peer) {
    throw ReservationException(
      status: HopStatus.malformedMessage,
      reason:
          'invalid voucher peer id: expected '
          '${h.id.toBase58()}, got ${record.peer.toBase58()}',
    );
  }

  return record;
}

Future<void> _reset(NetworkStream stream) async {
  try {
    await stream.reset();
  } catch (_) {}
}

Future<Uint8List> _readDelimited(NetworkStream stream) async {
  final firstByte = await stream.read(1);
  if (firstByte.isEmpty) {
    throw const FormatException('relay closed the stream before responding');
  }
  var len = firstByte[0] & 0x7f;
  var shift = 7;
  if ((firstByte[0] & 0x80) != 0) {
    while (true) {
      final b = await stream.read(1);
      if (b.isEmpty) {
        throw const FormatException(
          'relay closed the stream mid-length-prefix',
        );
      }
      len |= (b[0] & 0x7f) << shift;
      if ((b[0] & 0x80) == 0) break;
      shift += 7;
    }
  }
  if (len == 0) return Uint8List(0);
  final buf = <int>[];
  while (buf.length < len) {
    final chunk = await stream.read(len - buf.length);
    if (chunk.isEmpty) {
      throw const FormatException('relay closed the stream mid-message');
    }
    buf.addAll(chunk);
  }
  return Uint8List.fromList(buf);
}

Future<void> _writeDelimited(NetworkStream stream, Uint8List data) async {
  final prefix = encodeProtoVarint(data.length);
  final packet = Uint8List(prefix.length + data.length);
  packet.setRange(0, prefix.length, prefix);
  packet.setRange(prefix.length, packet.length, data);
  await stream.write(packet);
}
