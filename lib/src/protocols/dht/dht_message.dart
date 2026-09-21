import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

/// Maximum decoded DHT message size, in bytes (4 MiB).
const int dhtMessageSizeMax = 1 << 22;

/// Canonical lowerCamelCase name of go-libp2p-kad-dht `MaxPeerRecordSize`.
const int maxPeerRecordSize = 8 << 10;

/// Maximum encoded peer record size, in bytes (8 KiB).
const int dhtPeerSizeMax = maxPeerRecordSize;

/// Encodes a DHT `GET_PROVIDERS` request for [cid].
Uint8List encodeGetProviders(Cid cid) {
  final payload = BytesBuilder()
    ..add(_varintField(1, 3))
    ..add(_bytesField(2, Uint8List.fromList(cid.multihash.toBytes())))
    ..add(_varintField(10, 1));
  return frameDhtMessage(payload.takeBytes());
}

/// Encodes a DHT `FIND_NODE` request for [key].
Uint8List encodeFindNode(Uint8List key) {
  final payload = BytesBuilder()
    ..add(_varintField(1, 4))
    ..add(_bytesField(2, key))
    ..add(_varintField(10, 1));
  return frameDhtMessage(payload.takeBytes());
}

/// Encodes a DHT `ADD_PROVIDER` request for [cid] advertising [provider].
Uint8List encodeAddProvider(Cid cid, AddrInfo provider) {
  final payload = BytesBuilder()
    ..add(_varintField(1, 2))
    ..add(_bytesField(2, Uint8List.fromList(cid.multihash.toBytes())))
    ..add(
      _bytesField(9, encodePeerRecord(id: provider.id, addrs: provider.addrs)),
    );
  return frameDhtMessage(payload.takeBytes());
}

/// Frames [body] with a varint length prefix, matching go-msgio's
/// `NewVarintWriter`, used by go-libp2p-kad-dht to delimit each protobuf
/// message on the wire (see `internal/net.WriteMsg`).
Uint8List frameDhtMessage(Uint8List body) =>
    Uint8List.fromList([...encodeVarint(body.length), ...body]);

/// Reads one varint-length-prefixed DHT protobuf frame from [stream],
/// bounded by [dhtMessageSizeMax]. Matches go-msgio's
/// `NewVarintReaderSize(s, network.MessageSizeMax)`, used by
/// go-libp2p-kad-dht's `handleNewMessage` to read each request/response off
/// the wire.
Future<Uint8List> readDhtFrame(NetworkStream stream) async {
  var length = 0;
  var shift = 0;
  for (var i = 0; i < 10; i++) {
    final byte = await stream.read(1);
    if (byte.isEmpty) {
      throw const FormatException('Unexpected EOF in DHT frame');
    }
    length |= (byte.first & 0x7f) << shift;
    if (byte.first & 0x80 == 0) {
      if (length > dhtMessageSizeMax) {
        throw const FormatException('DHT message exceeds 4 MiB');
      }
      final out = BytesBuilder(copy: false);
      while (out.length < length) {
        final chunk = await stream.read(length - out.length);
        if (chunk.isEmpty) {
          throw const FormatException('Unexpected EOF in DHT frame');
        }
        out.add(chunk);
      }
      return out.takeBytes();
    }
    shift += 7;
  }
  throw const FormatException('DHT frame varint is too long');
}

int _varintLength(int value) {
  if (value < 0) return 10;
  var length = 0;
  var v = value;
  do {
    length++;
    v >>= 7;
  } while (v > 0);
  return length;
}

/// Trims trailing addresses so the peer record fits within [maxSize] (8 KiB),
/// exactly matching go-libp2p-kad-dht's `boundPeerRecordAddrs`.
List<Uint8List> boundPeerRecordAddrs({
  required Uint8List id,
  required List<Uint8List> rawAddrs,
  int connection = 0,
  int maxSize = maxPeerRecordSize,
}) {
  final connectionFieldSize = 1 + _varintLength(connection);
  var size = 1 + _varintLength(id.length) + id.length + connectionFieldSize;
  final kept = <Uint8List>[];
  for (final addr in rawAddrs) {
    final entrySize = 1 + _varintLength(addr.length) + addr.length;
    if (size + entrySize > maxSize) {
      break;
    }
    size += entrySize;
    kept.add(addr);
  }
  return kept;
}

/// Encodes a single `Message_Peer` record, bounded to 8 KiB.
Uint8List encodePeerRecord({
  required PeerId id,
  required List<Multiaddr> addrs,
  int connection = 2,
}) {
  final rawAddrs = addrs.map((a) => a.toBytes()).toList();
  final bounded = boundPeerRecordAddrs(
    id: id.value,
    rawAddrs: rawAddrs,
    connection: connection,
  );
  final payload = BytesBuilder()..add(_bytesField(1, id.value));
  for (final addr in bounded) {
    payload.add(_bytesField(2, addr));
  }
  payload.add(_varintField(3, connection));
  return payload.takeBytes();
}

/// Encodes a complete protobuf DHT response body (unframed -- callers that
/// write this to a stream must frame it with [frameDhtMessage] first).
///
/// [type], [key] and [clusterLevelRaw] mirror proto3's implicit field
/// presence: each is only serialized when it differs from its zero value,
/// exactly like go-libp2p-kad-dht's own protobuf marshalling. Omitting them
/// (the default) reproduces this function's original, narrower shape.
Uint8List encodeDhtResponse({
  int type = 0,
  Uint8List? key,
  int clusterLevelRaw = 0,
  List<AddrInfo> closerPeers = const [],
  List<AddrInfo> providerPeers = const [],
}) {
  final payload = BytesBuilder();
  if (type != 0) payload.add(_varintField(1, type));
  if (key != null && key.isNotEmpty) payload.add(_bytesField(2, key));
  for (final peer in closerPeers) {
    payload.add(
      _bytesField(8, encodePeerRecord(id: peer.id, addrs: peer.addrs)),
    );
  }
  for (final peer in providerPeers) {
    payload.add(
      _bytesField(9, encodePeerRecord(id: peer.id, addrs: peer.addrs)),
    );
  }
  if (clusterLevelRaw != 0) payload.add(_varintField(10, clusterLevelRaw));
  return payload.takeBytes();
}

/// A decoded DHT request message (`FIND_NODE`, `GET_PROVIDERS`,
/// `ADD_PROVIDER` or `PING`). Equivalent to the request-side fields of
/// go-libp2p-kad-dht's `pb.Message`.
final class DhtRequest {
  /// Creates a request with the given decoded fields.
  const DhtRequest({
    required this.type,
    required this.key,
    required this.clusterLevelRaw,
    required this.providerPeers,
  });

  /// Decodes a protobuf DHT request from [bytes].
  factory DhtRequest.fromBytes(Uint8List bytes) {
    if (bytes.length > dhtMessageSizeMax) {
      throw const FormatException('DHT message exceeds 4 MiB');
    }
    var type = 0;
    var key = Uint8List(0);
    var clusterLevelRaw = 0;
    final providers = <AddrInfo>[];
    final reader = _ProtoReader(bytes);
    while (!reader.isDone) {
      final (field, wire) = reader.tag();
      if (field == 1 && wire == 0) {
        type = reader.varint();
      } else if (field == 2 && wire == 2) {
        key = Uint8List.fromList(reader.bytes());
      } else if (field == 9 && wire == 2) {
        final peer = _decodePeer(reader.bytes());
        if (peer != null) providers.add(peer);
      } else if (field == 10 && wire == 0) {
        clusterLevelRaw = reader.varint();
      } else {
        reader.skip(wire);
      }
    }
    return DhtRequest(
      type: type,
      key: key,
      clusterLevelRaw: clusterLevelRaw,
      providerPeers: providers,
    );
  }

  /// The message type: `PUT_VALUE`=0, `GET_VALUE`=1, `ADD_PROVIDER`=2,
  /// `GET_PROVIDERS`=3, `FIND_NODE`=4, `PING`=5.
  final int type;

  /// The key this request concerns.
  final Uint8List key;

  /// The raw (unused) Coral cluster level, echoed back verbatim by servers.
  final int clusterLevelRaw;

  /// Provider records attached to an `ADD_PROVIDER` request.
  final List<AddrInfo> providerPeers;
}

/// Decoded response returned by a DHT provider query.
final class DhtResponse {
  /// Creates a response containing closer peers and providers.
  const DhtResponse({required this.closerPeers, required this.providerPeers});

  /// Decodes a protobuf DHT response from [bytes].
  factory DhtResponse.fromBytes(Uint8List bytes) {
    if (bytes.length > dhtMessageSizeMax) {
      throw const FormatException('DHT message exceeds 4 MiB');
    }
    final closer = <AddrInfo>[];
    final providers = <AddrInfo>[];
    final reader = _ProtoReader(bytes);
    while (!reader.isDone) {
      final (field, wire) = reader.tag();
      if ((field == 8 || field == 9) && wire == 2) {
        final peerBytes = reader.bytes();
        final peer = _decodePeer(peerBytes);
        if (peer != null) (field == 8 ? closer : providers).add(peer);
      } else {
        reader.skip(wire);
      }
    }
    return DhtResponse(closerPeers: closer, providerPeers: providers);
  }

  /// Peers closer to the requested key.
  final List<AddrInfo> closerPeers;

  /// Peers advertising themselves as providers.
  final List<AddrInfo> providerPeers;
}

AddrInfo? _decodePeer(Uint8List bytes) {
  Uint8List? id;
  final rawAddrs = <Uint8List>[];
  var connection = 0;
  final reader = _ProtoReader(bytes);
  while (!reader.isDone) {
    final (field, wire) = reader.tag();
    if (field == 1 && wire == 2) {
      id = Uint8List.fromList(reader.bytes());
    } else if (field == 2 && wire == 2) {
      rawAddrs.add(Uint8List.fromList(reader.bytes()));
    } else if (field == 3 && wire == 0) {
      connection = reader.varint();
    } else {
      reader.skip(wire);
    }
  }
  if (id == null || id.isEmpty) return null;

  final boundedAddrs = boundPeerRecordAddrs(
    id: id,
    rawAddrs: rawAddrs,
    connection: connection,
  );

  final addrs = <Multiaddr>[];
  for (final rawAddr in boundedAddrs) {
    try {
      addrs.add(Multiaddr.fromBytes(rawAddr));
    } on FormatException {
      // go-libp2p drops malformed addresses but retains the peer.
    }
  }
  try {
    return AddrInfo(id: PeerId.fromBytes(id), addrs: addrs);
  } on FormatException {
    return null;
  }
}

Uint8List _bytesField(int field, Uint8List value) => Uint8List.fromList([
  ...encodeVarint((field << 3) | 2),
  ...encodeVarint(value.length),
  ...value,
]);

Uint8List _varintField(int field, int value) =>
    Uint8List.fromList([...encodeVarint(field << 3), ...encodeVarint(value)]);

final class _ProtoReader {
  _ProtoReader(this.data);
  final Uint8List data;
  int offset = 0;
  bool get isDone => offset == data.length;

  (int, int) tag() {
    final value = varint();
    if (value >> 3 == 0) throw const FormatException('Invalid protobuf field');
    return (value >> 3, value & 7);
  }

  int varint() {
    final (value, length) = readVarint(data, offset);
    offset += length;
    return value;
  }

  Uint8List bytes() {
    final length = varint();
    final end = offset + length;
    if (end > data.length) throw const FormatException('Truncated protobuf');
    final result = Uint8List.sublistView(data, offset, end);
    offset = end;
    return result;
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        varint();
        return;
      case 1:
        _advance(8);
        return;
      case 2:
        _advance(varint());
        return;
      case 5:
        _advance(4);
        return;
      default:
        throw FormatException('Unsupported protobuf wire type $wire');
    }
  }

  void _advance(int count) {
    offset += count;
    if (offset > data.length) throw const FormatException('Truncated protobuf');
  }
}
