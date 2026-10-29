// Package functions and value type methods without a node (0.25.0): CIDs,
// peer IDs, multiaddrs, paths, IPNS names, keys and dag-pb links. Needs
// `dart run tool/build.dart`.
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

/// A sha2-256 multihash (code 0x12, 32 bytes); the digest is not checked.
final mhash = Uint8List.fromList([0x12, 0x20, ...List.filled(32, 7)]);

void main() {
  setUpAll(P2pService.start);
  tearDownAll(P2pService.stop);

  test('cid: from a string, from bytes, from a multihash', () {
    final v0 = Go.cid.newCidV0(mhash);
    expect(v0.value, startsWith('Qm'));
    expect(Go.cid.decode(v0.value), v0);
    expect(Go.cid.parse(v0.value), v0);
    // a CIDv0's bytes are its multihash
    expect(Go.cid.parse(mhash), v0);
    expect(Go.cid.cast(mhash), v0);
    expect(Go.cid.cidFromBytes(mhash), (34, v0));

    final v1 = Go.cid.newCidV1(Go.cid.raw, mhash);
    expect(v1.value, startsWith('bafk'));
    expect(Go.cid.decode(v1.value), v1);
    expect(Go.cid.extractEncoding(v1.value), 0x62); // multibase base32 'b'
    expect(() => Go.cid.decode('not a cid'), throwsA(isA<GolangException>()));

    final p = Go.cid.newPrefixV1(Go.cid.dagCbor, 0x12);
    final back = Go.cid.prefixFromBytes(p.bytes());
    expect((back.version, back.codec, back.mhType), (1, Go.cid.dagCbor, 0x12));
  });

  test('multihash and multibase: the hash and the text of a CID', () {
    final data = Uint8List.fromList([1, 2, 3]);
    final c = Go.cid.newPrefixV1(Go.cid.raw, Go.multihash.sha2256).sum(data);
    final m = Go.multihash.sum(data, Go.multihash.sha2256, -1);
    expect(m, c.hash());

    final d = Go.multihash.decode(m);
    expect((d.code, d.name, d.length), (0x12, 'sha2-256', 32));
    expect(d.digest!.length, 32);
    expect(Go.multihash.encode(d.digest!, Go.multihash.sha2256), m);
    expect(Go.multihash.names['sha2-256'], Go.multihash.sha2256);
    expect(Go.multihash.codes[Go.multihash.sha2256], 'sha2-256');
    expect(
        () => Go.multihash.cast(Uint8List(3)), throwsA(isA<GolangException>()));

    final set = MultihashSet()..add(m);
    expect((set.has(m), set.len()), (true, 1));
    set.release();

    final text = Go.multibase.encode(Go.multibase.base36, data);
    expect(text, startsWith('k'));
    final (base, back) = Go.multibase.decode(text);
    expect(base, Go.multibase.base36);
    expect(back, data);
    expect(Go.cid.extractEncoding(c.value), Go.multibase.base32);
  });

  test('peer: ID from a CID and from a /p2p multiaddr', () {
    final (sk, pk) = Go.libp2p.core.crypto
        .generateKeyPair(Go.libp2p.core.crypto.ed25519, -1);
    final id = Go.libp2p.core.peer.idFromPublicKey(pk);
    expect(Go.libp2p.core.peer.decode(id.value), id);
    expect(Go.libp2p.core.peer.fromCid(Go.libp2p.core.peer.toCid(id)), id);

    final tcp = Go.multiaddr.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = Go.multiaddr.newMultiaddr('$tcp/p2p/$id');
    expect(Go.libp2p.core.peer.idFromP2pAddr(full), id);
    expect(Go.libp2p.core.peer.splitAddr(full), (tcp, id));
    expect(Go.libp2p.core.peer.addrInfosToIds([Libp2pCorePeerAddrInfo(id: id)]),
        [id]);
    sk.release();
    pk.release();
  });

  test('multiaddr: join, contains, unique', () {
    final a = Go.multiaddr.newMultiaddr('/ip4/10.0.0.1');
    final b = Go.multiaddr.newMultiaddr('/tcp/80');
    final j = Go.multiaddr.join([
      MultiaddrMultiaddrer(multiaddr: a),
      MultiaddrMultiaddrer(multiaddr: b)
    ]);
    expect(j.value, '/ip4/10.0.0.1/tcp/80');
    expect(Go.multiaddr.contains([a, j], j), isTrue);
    expect(Go.multiaddr.unique([a, j, a]), [a, j]);
    expect(() => Go.multiaddr.newMultiaddr('/nope'),
        throwsA(isA<GolangException>()));
  });

  test('path and IPNS name', () {
    final c = Go.cid.newCidV1(Go.cid.raw, mhash);
    final p = Go.boxo.path.fromCid(c);
    expect(p.value, '/ipfs/$c');
    expect(Go.boxo.path.newPath('/ipfs/$c').value, p.value);
    expect(Go.boxo.path.join(p, ['a', 'b']).value, '/ipfs/$c/a/b');
    expect(Go.boxo.path.stringToSegments('/ipfs/$c/a'), ['ipfs', '$c', 'a']);
    expect(Go.boxo.path.segmentsToString(['ipns', 'x']), '/ipns/x');
    expect(Go.boxo.path.newImmutablePath(Go.boxo.path.newPath('/ipfs/$c')), p);

    final (sk, pk) = Go.libp2p.core.crypto
        .generateKeyPair(Go.libp2p.core.crypto.ed25519, -1);
    final id = Go.libp2p.core.peer.idFromPublicKey(pk);
    final name = Go.boxo.ipns.nameFromPeer(id);
    expect(Go.boxo.ipns.nameFromString(name.value), name);
    sk.release();
    pk.release();
  });

  test('crypto: raw keys of a type, equality, config encoding', () {
    final (sk, pk) = Go.libp2p.core.crypto
        .generateKeyPair(Go.libp2p.core.crypto.ed25519, -1);
    expect(sk.type(), Go.libp2p.core.crypto.ed25519);
    final sk2 = Go.libp2p.core.crypto.unmarshalEd25519PrivateKey(sk.raw());
    final pk2 = Go.libp2p.core.crypto.unmarshalEd25519PublicKey(pk.raw());
    expect(Go.libp2p.core.crypto.keyEqual(sk, sk2), isTrue);
    expect(pk.equals(pk2), isTrue);
    final bytes = Go.libp2p.core.crypto.marshalPrivateKey(sk);
    expect(
        Go.libp2p.core.crypto
            .configDecodeKey(Go.libp2p.core.crypto.configEncodeKey(bytes)),
        bytes);
    for (final k in [sk, pk, sk2, pk2]) {
      k.release();
    }
  });

  test('merkledag: links of a dag-pb node through its protobuf', () {
    final child = Go.boxo.ipld.merkledag.nodeWithData(Uint8List.fromList([1]));
    final root = Go.boxo.ipld.merkledag.nodeWithData(Uint8List.fromList([2]))
      ..addNodeLink('a', child)
      ..addNodeLink('b', child);
    final decoded =
        Go.boxo.ipld.merkledag.decodeProtobuf(root.encodeProtobuf(false));
    expect(decoded.links().map((l) => l.name), ['a', 'b']);
    expect(decoded.getNodeLink('b').cid, child.cid());
    decoded.removeNodeLink('a');
    expect(decoded.links().map((l) => l.name), ['b']);
    expect(Go.boxo.ipld.merkledag.v1CidPrefix().version, 1);
    for (final n in [child, root, decoded]) {
      n.release();
    }
  });

  test('value type methods: Cid', () {
    final v0 = Go.cid.newCidV0(mhash);
    final v1 = Go.cid.newCidV1(Go.cid.raw, mhash);
    expect((v0.version(), v0.type()), (0, Go.cid.dagProtobuf));
    expect((v1.version(), v1.type()), (1, Go.cid.raw));
    expect(v1.hash(), mhash);
    expect(v0.bytes(), mhash);
    expect(Go.cid.cast(v1.bytes()), v1);
    expect(v1.byteLen(), v1.bytes().length);
    expect(v1.prefix().codec, Go.cid.raw);
    expect(v1.equals(Go.cid.decode(v1.value)), isTrue);
    expect(v1.equals(v0), isFalse);
    expect(v1.defined(), isTrue);
    expect(v1.stringOfBase(0x7a), startsWith('z')); // base58btc
  });

  test('value type methods: peer ID, multiaddr, path, IPNS name', () {
    final (sk, pk) = Go.libp2p.core.crypto
        .generateKeyPair(Go.libp2p.core.crypto.ed25519, -1);
    final id = Go.libp2p.core.peer.idFromPublicKey(pk);
    id.validate();
    expect(Go.libp2p.core.peer.idFromBytes(id.marshal()), id);
    // an ed25519 ID inlines the key
    final pk2 = id.extractPublicKey();
    expect(pk2.equals(pk), isTrue);
    expect(id.matchesPrivateKey(sk), isTrue);
    expect(id.matchesPublicKey(pk), isTrue);
    expect(id.shortString(),
        '<peer.ID ${id.value.substring(0, 2)}*${id.value.substring(id.value.length - 6)}>');

    final ip = Go.multiaddr.newMultiaddr('/ip4/10.0.0.1');
    final tcp = Go.multiaddr.newMultiaddr('/tcp/80');
    final full = ip.encapsulate(MultiaddrMultiaddrer(multiaddr: tcp));
    expect(full.value, '/ip4/10.0.0.1/tcp/80');
    expect(full.decapsulate(MultiaddrMultiaddrer(multiaddr: tcp)), ip);
    expect(full.valueForProtocol(6), '80'); // P_TCP
    expect(Go.multiaddr.newMultiaddrBytes(full.bytes()).equal(full), isTrue);
    expect(full.compare(full), 0);

    final c = Go.cid.newCidV1(Go.cid.raw, mhash);
    final p = Go.boxo.path.fromCid(c);
    expect(p.namespace(), 'ipfs');
    expect(p.mutable(), isFalse);
    expect(Go.boxo.path.join(p, ['a']).segments(), ['ipfs', '$c', 'a']);
    expect(p.rootCid(), c);

    final name = Go.boxo.ipns.nameFromPeer(id);
    expect(name.peer(), id);
    expect(name.asPath().value, '/ipns/$name');
    expect(name.asPath().mutable(), isTrue);
    expect(name.equal(Go.boxo.ipns.nameFromCid(name.cid())), isTrue);
    expect(Go.boxo.ipns.nameFromRoutingKey(name.routingKey()), name);
    for (final k in [sk, pk, pk2]) {
      k.release();
    }
  });
}
