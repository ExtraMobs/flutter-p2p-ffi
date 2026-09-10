import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/src/protocols/dht/dht_message.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

void main() {
  test('GET_PROVIDERS and peer response preserve upstream wire fields', () {
    final cid = Cid.decode(
      'bafkreibs723667mosvbz3kzygkbpaxkkg6zld7qmxrbh3ky2mreeoyjlue',
    );
    final request = encodeGetProviders(cid);
    final (_, frameLength) = readVarint(request, 0);
    final payload = request.sublist(frameLength);
    expect(payload.sublist(0, 4), [0x08, 0x03, 0x12, 0x22]);
    expect(payload.sublist(payload.length - 2), [0x50, 0x01]);

    final peerId = PeerId.decode(
      '12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
    );
    final address = addrInfoFromString(
      '/ip4/127.0.0.1/tcp/4001/p2p/${peerId.toBase58()}',
    ).addrs.single;
    final peer = _message([
      _bytes(1, peerId.value),
      _bytes(2, address.toBytes()),
      _varint(3, 2),
    ]);
    final response = DhtResponse.fromBytes(_message([_bytes(9, peer)]));
    expect(response.closerPeers, isEmpty);
    expect(response.providerPeers, [
      AddrInfo(id: peerId, addrs: [address]),
    ]);
  });

  test('bounds peer record to 8 KiB (MaxPeerRecordSize)', () {
    final peerId = PeerId.decode(
      '12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
    );
    // Create 1000 distinct addresses that together exceed 8 KiB
    final addrs = [
      for (var i = 0; i < 1000; i++)
        Multiaddr.parse('/ip4/192.168.1.1/tcp/${1000 + i}'),
    ];

    final encoded = encodePeerRecord(id: peerId, addrs: addrs);
    expect(encoded.length, lessThanOrEqualTo(maxPeerRecordSize));

    final decoded = DhtResponse.fromBytes(_message([_bytes(9, encoded)]));
    expect(decoded.providerPeers, hasLength(1));
    final provider = decoded.providerPeers.single;
    expect(provider.id, peerId);
    expect(provider.addrs.length, lessThan(addrs.length));
    expect(provider.addrs.isNotEmpty, isTrue);
    // Preserves front prefix
    for (var i = 0; i < provider.addrs.length; i++) {
      expect(provider.addrs[i], addrs[i]);
    }
  });

  test('peer record with single oversized address retains peer ID', () {
    final peerId = PeerId.decode(
      '12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
    );
    final oversizedAddr = Uint8List(maxPeerRecordSize + 100);
    final peer = _message([
      _bytes(1, peerId.value),
      _bytes(2, oversizedAddr),
      _varint(3, 2),
    ]);
    final response = DhtResponse.fromBytes(_message([_bytes(9, peer)]));
    expect(response.providerPeers, hasLength(1));
    expect(response.providerPeers.single.id, peerId);
    expect(response.providerPeers.single.addrs, isEmpty);
  });

  test('rejects messages exceeding 4 MiB limit', () {
    final oversized = Uint8List(dhtMessageSizeMax + 1);
    expect(
      () => DhtResponse.fromBytes(oversized),
      throwsA(isA<FormatException>()),
    );
  });

  test('encodeDhtResponse encodes both closer peers and provider peers', () {
    final peer1 = AddrInfo(
      id: PeerId.decode('12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV'),
      addrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')],
    );
    final peer2 = AddrInfo(
      id: PeerId.decode('12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c'),
      addrs: [Multiaddr.parse('/ip4/10.0.0.2/tcp/4001')],
    );

    final bytes = encodeDhtResponse(
      closerPeers: [peer1],
      providerPeers: [peer2],
    );
    final decoded = DhtResponse.fromBytes(bytes);
    expect(decoded.closerPeers, [peer1]);
    expect(decoded.providerPeers, [peer2]);
  });
}

Uint8List _message(List<Uint8List> fields) =>
    Uint8List.fromList(fields.expand((field) => field).toList());

Uint8List _bytes(int field, Uint8List value) => Uint8List.fromList([
  ...encodeVarint((field << 3) | 2),
  ...encodeVarint(value.length),
  ...value,
]);

Uint8List _varint(int field, int value) =>
    Uint8List.fromList([...encodeVarint(field << 3), ...encodeVarint(value)]);
