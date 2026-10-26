// Package functions that build and convert without a node (0.25.0): CIDs,
// peer IDs, multiaddrs, paths, IPNS names, keys and dag-pb links. Needs
// `dart run tool/build.dart`.
import 'dart:typed_data';

import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipns.dart' as ipns;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/libp2p/core/crypto.dart' as crypto;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/go/multiaddr.dart' as ma;
import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

/// A sha2-256 multihash (code 0x12, 32 bytes); the digest is not checked.
final mhash = Uint8List.fromList([0x12, 0x20, ...List.filled(32, 7)]);

void main() {
  setUpAll(P2pService.start);
  tearDownAll(P2pService.stop);

  test('cid: from a string, from bytes, from a multihash', () {
    final v0 = cid.newCidV0(mhash);
    expect(v0.value, startsWith('Qm'));
    expect(cid.decode(v0.value), v0);
    expect(cid.parse(v0.value), v0);
    // a CIDv0's bytes are its multihash
    expect(cid.parse(mhash), v0);
    expect(cid.cast(mhash), v0);
    expect(cid.cidFromBytes(mhash), (34, v0));

    final v1 = cid.newCidV1(cid.raw, mhash);
    expect(v1.value, startsWith('bafk'));
    expect(cid.decode(v1.value), v1);
    expect(cid.extractEncoding(v1.value), 0x62); // multibase base32 'b'
    expect(() => cid.decode('not a cid'), throwsA(isA<GolangException>()));

    final p = cid.newPrefixV1(cid.dagCbor, 0x12);
    final back = cid.prefixFromBytes(p.bytes());
    expect((back.version, back.codec, back.mhType), (1, cid.dagCbor, 0x12));
  });

  test('peer: ID from a CID and from a /p2p multiaddr', () {
    final (sk, pk) = crypto.generateKeyPair(crypto.ed25519, -1);
    final id = peer.idFromPublicKey(pk);
    expect(peer.decode(id.value), id);
    expect(peer.fromCid(peer.toCid(id)), id);

    final tcp = ma.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = ma.newMultiaddr('$tcp/p2p/$id');
    expect(peer.idFromP2pAddr(full), id);
    expect(peer.splitAddr(full), (tcp, id));
    expect(peer.addrInfosToIds([peer.AddrInfo(id: id)]), [id]);
    sk.release();
    pk.release();
  });

  test('multiaddr: join, contains, unique', () {
    final a = ma.newMultiaddr('/ip4/10.0.0.1');
    final b = ma.newMultiaddr('/tcp/80');
    final j =
        ma.join([ma.Multiaddrer(multiaddr: a), ma.Multiaddrer(multiaddr: b)]);
    expect(j.value, '/ip4/10.0.0.1/tcp/80');
    expect(ma.contains([a, j], j), isTrue);
    expect(ma.unique([a, j, a]), [a, j]);
    expect(() => ma.newMultiaddr('/nope'), throwsA(isA<GolangException>()));
  });

  test('path and IPNS name', () {
    final c = cid.newCidV1(cid.raw, mhash);
    final p = path.fromCid(c);
    expect(p.value, '/ipfs/$c');
    expect(path.newPath('/ipfs/$c').value, p.value);
    expect(path.join(p, ['a', 'b']).value, '/ipfs/$c/a/b');
    expect(path.stringToSegments('/ipfs/$c/a'), ['ipfs', '$c', 'a']);
    expect(path.segmentsToString(['ipns', 'x']), '/ipns/x');
    expect(path.newImmutablePath(path.newPath('/ipfs/$c')), p);

    final (sk, pk) = crypto.generateKeyPair(crypto.ed25519, -1);
    final id = peer.idFromPublicKey(pk);
    final name = ipns.nameFromPeer(id);
    expect(ipns.nameFromString(name.value), name);
    sk.release();
    pk.release();
  });

  test('crypto: raw keys of a type, equality, config encoding', () {
    final (sk, pk) = crypto.generateKeyPair(crypto.ed25519, -1);
    expect(sk.type(), crypto.ed25519);
    final sk2 = crypto.unmarshalEd25519PrivateKey(sk.raw());
    final pk2 = crypto.unmarshalEd25519PublicKey(pk.raw());
    expect(crypto.keyEqual(sk, sk2), isTrue);
    expect(pk.equals(pk2), isTrue);
    final bytes = crypto.marshalPrivateKey(sk);
    expect(crypto.configDecodeKey(crypto.configEncodeKey(bytes)), bytes);
    for (final k in [sk, pk, sk2, pk2]) {
      k.release();
    }
  });

  test('merkledag: links of a dag-pb node through its protobuf', () {
    final child = merkledag.nodeWithData(Uint8List.fromList([1]));
    final root = merkledag.nodeWithData(Uint8List.fromList([2]))
      ..addNodeLink('a', child)
      ..addNodeLink('b', child);
    final decoded = merkledag.decodeProtobuf(root.encodeProtobuf(false));
    expect(decoded.links().map((l) => l.name), ['a', 'b']);
    expect(decoded.getNodeLink('b').cid, child.cid());
    decoded.removeNodeLink('a');
    expect(decoded.links().map((l) => l.name), ['b']);
    expect(merkledag.v1CidPrefix().version, 1);
    for (final n in [child, root, decoded]) {
      n.release();
    }
  });
}
