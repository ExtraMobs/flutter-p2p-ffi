// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import '../../../../core/crypto/proto_varint.dart';
import '../../../../core/peer/peer_id.dart';
import '../../../../core/protocol/protocol.dart';
import '../../../../core/record/record.dart';

const ProtocolId protoIDv2Hop = '/libp2p/circuit/relay/0.2.0/hop';
const ProtocolId protoIDv2Stop = '/libp2p/circuit/relay/0.2.0/stop';

const String recordDomain = 'libp2p-relay-rsvp';

/// The Envelope payload type identifying a [ReservationVoucher], from
/// go-libp2p's `proto.RecordCodec` (`p2p/protocol/circuitv2/proto/voucher.go:16`).
/// Upstream notes it is not yet registered in the multicodec table.
final Uint8List recordCodec = Uint8List.fromList([0x03, 0x02]);

// Go registers the voucher record type from the `proto` package's `init()`,
// which the Go runtime runs once, eagerly, on import. Dart has no equivalent,
// so registration happens idempotently from the constructor -- the same idiom
// `core/peer/peer_record.dart` uses for PeerRecord.
bool _reservationVoucherTypeRegistered = false;

void _ensureReservationVoucherTypeRegistered() {
  if (_reservationVoucherTypeRegistered) return;
  // Set before calling registerType, which invokes the factory once to read
  // its codec() -- avoids re-entering this same guard recursively.
  _reservationVoucherTypeRegistered = true;
  registerType(_blankReservationVoucher);
}

/// Builds the zero value of [ReservationVoucher], matching the
/// `&ReservationVoucher{}` that Go's `record.RegisterType` receives.
ReservationVoucher _blankReservationVoucher() => ReservationVoucher(
  relay: PeerId(value: Uint8List(0)),
  peer: PeerId(value: Uint8List(0)),
  expiration: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// A signed reservation voucher provided by the relay node.
class ReservationVoucher implements Record {
  ReservationVoucher({
    required this.relay,
    required this.peer,
    required this.expiration,
  }) {
    _ensureReservationVoucherTypeRegistered();
  }

  PeerId relay;
  PeerId peer;
  DateTime expiration;

  @override
  String domain() => recordDomain;

  @override
  Uint8List codec() => recordCodec;

  @override
  Uint8List marshalRecord() {
    // pb.ReservationVoucher: relay = 1 (bytes), peer = 2 (bytes),
    // expiration = 3 (uint64), from pb/voucher.proto.
    final builder = BytesBuilder();

    void writeBytes(int fieldNumber, Uint8List value) {
      builder.add(encodeProtoVarint((fieldNumber << 3) | 2));
      builder.add(encodeProtoVarint(value.length));
      builder.add(value);
    }

    writeBytes(1, relay.value);
    writeBytes(2, peer.value);
    builder.add(encodeProtoVarint((3 << 3) | 0));
    builder.add(encodeProtoVarint(expiration.millisecondsSinceEpoch ~/ 1000));
    return builder.toBytes();
  }

  @override
  void unmarshalRecord(Uint8List data) {
    final parsed = parseRecord(data);
    relay = parsed.relay;
    peer = parsed.peer;
    expiration = parsed.expiration;
  }

  static ReservationVoucher parseRecord(Uint8List bytes) {
    var relay = Uint8List(0);
    var peer = Uint8List(0);
    var expireSeconds = 0;

    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLength) = readProtoVarint(bytes, offset);
      offset += tagLength;
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x7;

      if (wireType == 0) {
        final (value, valueLength) = readProtoVarint(bytes, offset);
        offset += valueLength;
        if (fieldNumber == 3) expireSeconds = value;
      } else if (wireType == 2) {
        final (length, lengthBytes) = readProtoVarint(bytes, offset);
        offset += lengthBytes;
        if (offset + length > bytes.length) {
          throw const FormatException(
            'voucher record field runs past end of message',
          );
        }
        final value = bytes.sublist(offset, offset + length);
        offset += length;
        if (fieldNumber == 1) relay = value;
        if (fieldNumber == 2) peer = value;
      } else {
        throw FormatException(
          'unsupported wire type $wireType in voucher record',
        );
      }
    }

    // Go resolves both IDs through peer.IDFromBytes, which rejects bytes that
    // are not a valid multihash.
    final relayId = PeerId(value: relay)..validate();
    final peerId = PeerId(value: peer)..validate();

    return ReservationVoucher(
      relay: relayId,
      peer: peerId,
      expiration: DateTime.fromMillisecondsSinceEpoch(
        expireSeconds * 1000,
        isUtc: true,
      ),
    );
  }
}
