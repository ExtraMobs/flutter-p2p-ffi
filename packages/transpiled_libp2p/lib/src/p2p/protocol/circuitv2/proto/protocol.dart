// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/peer/peer_id.dart';
import '../../../../core/protocol/protocol.dart';
import '../../../../core/record/record.dart';

const ProtocolId protoIDv2Hop = '/libp2p/circuit/relay/0.2.0/hop';
const ProtocolId protoIDv2Stop = '/libp2p/circuit/relay/0.2.0/stop';

const String recordDomain = 'libp2p-relay-rsvp';
final Uint8List recordCodec = Uint8List.fromList(utf8.encode('/libp2p/circuit/relay/0.2.0/rsvp'));

/// A signed reservation voucher provided by the relay node.
class ReservationVoucher implements Record {
  ReservationVoucher({
    required this.relay,
    required this.peer,
    required this.expiration,
  });

  PeerId relay;
  PeerId peer;
  DateTime expiration;

  @override
  String domain() => recordDomain;

  @override
  Uint8List codec() => recordCodec;

  @override
  Uint8List marshalRecord() {
    final builder = BytesBuilder();
    // relay peer id (length prefixed)
    final rBytes = relay.value;
    builder.add([rBytes.length]);
    builder.add(rBytes);
    // client peer id (length prefixed)
    final pBytes = peer.value;
    builder.add([pBytes.length]);
    builder.add(pBytes);
    // expiration unix timestamp in seconds (64-bit big-endian)
    final expSec = expiration.millisecondsSinceEpoch ~/ 1000;
    final b = ByteData(8)..setInt64(0, expSec, Endian.big);
    builder.add(b.buffer.asUint8List());
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
    if (bytes.length < 10) {
      throw const FormatException('voucher record too short');
    }
    var offset = 0;
    final rLen = bytes[offset++];
    final rBytes = bytes.sublist(offset, offset + rLen);
    offset += rLen;

    final pLen = bytes[offset++];
    final pBytes = bytes.sublist(offset, offset + pLen);
    offset += pLen;

    final view = ByteData.sublistView(bytes, offset);
    final expSec = view.getInt64(0, Endian.big);
    final exp = DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true);

    return ReservationVoucher(
      relay: PeerId(value: rBytes),
      peer: PeerId(value: pBytes),
      expiration: exp,
    );
  }
}
