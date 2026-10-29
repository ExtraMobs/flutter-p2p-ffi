// Package functions and value type methods without a node (0.25.0): CIDs,
// peer IDs, multiaddrs, paths, IPNS names, keys and dag-pb links. Needs
// `dart run tool/build.dart`.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

/// A sha2-256 multihash (code 0x12, 32 bytes); the digest is not checked.
final mhash = Uint8List.fromList([0x12, 0x20, ...List.filled(32, 7)]);

void main() {
  setUpAll(P2pService.start);
  tearDownAll(P2pService.stop);

  test('cid: from a string, from bytes, from a multihash', () {
    final v0 = goCid.newCidV0(mhash);
    expect(v0.value, startsWith('Qm'));
    expect(goCid.decode(v0.value), v0);
    expect(goCid.parse(v0.value), v0);
    // a CIDv0's bytes are its multihash
    expect(goCid.parse(mhash), v0);
    expect(goCid.cast(mhash), v0);
    expect(goCid.cidFromBytes(mhash), (34, v0));

    final v1 = goCid.newCidV1(goCid.raw, mhash);
    expect(v1.value, startsWith('bafk'));
    expect(goCid.decode(v1.value), v1);
    expect(goCid.extractEncoding(v1.value), 0x62); // multibase base32 'b'
    expect(() => goCid.decode('not a cid'), throwsA(isA<GolangException>()));

    final p = goCid.newPrefixV1(goCid.dagCbor, 0x12);
    final back = goCid.prefixFromBytes(p.bytes());
    expect((back.version, back.codec, back.mhType), (1, goCid.dagCbor, 0x12));
  });

  test('multihash and multibase: the hash and the text of a CID', () {
    final data = Uint8List.fromList([1, 2, 3]);
    final c = goCid.newPrefixV1(goCid.raw, goMultihash.sha2256).sum(data);
    final m = goMultihash.sum(data, goMultihash.sha2256, -1);
    expect(m, c.hash());

    final d = goMultihash.decode(m);
    expect((d.code, d.name, d.length), (0x12, 'sha2-256', 32));
    expect(d.digest!.length, 32);
    expect(goMultihash.encode(d.digest!, goMultihash.sha2256), m);
    expect(goMultihash.names['sha2-256'], goMultihash.sha2256);
    expect(goMultihash.codes[goMultihash.sha2256], 'sha2-256');
    expect(
        () => goMultihash.cast(Uint8List(3)), throwsA(isA<GolangException>()));

    final set = MultihashSet()..add(m);
    expect((set.has(m), set.len()), (true, 1));
    set.release();

    final text = goMultibase.encode(goMultibase.base36, data);
    expect(text, startsWith('k'));
    final (base, back) = goMultibase.decode(text);
    expect(base, goMultibase.base36);
    expect(back, data);
    expect(goCid.extractEncoding(c.value), goMultibase.base32);
  });

  test('peer: ID from a CID and from a /p2p multiaddr', () {
    final (sk, pk) =
        goLibp2p.core.crypto.generateKeyPair(goLibp2p.core.crypto.ed25519, -1);
    final id = goLibp2p.core.peer.idFromPublicKey(pk);
    expect(goLibp2p.core.peer.decode(id.value), id);
    expect(goLibp2p.core.peer.fromCid(goLibp2p.core.peer.toCid(id)), id);

    final tcp = goMultiaddr.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = goMultiaddr.newMultiaddr('$tcp/p2p/$id');
    expect(goLibp2p.core.peer.idFromP2pAddr(full), id);
    expect(goLibp2p.core.peer.splitAddr(full), (tcp, id));
    expect(goLibp2p.core.peer.addrInfosToIds([Libp2pCorePeerAddrInfo(id: id)]),
        [id]);
    sk.release();
    pk.release();
  });

  test('multiaddr: join, contains, unique', () {
    final a = goMultiaddr.newMultiaddr('/ip4/10.0.0.1');
    final b = goMultiaddr.newMultiaddr('/tcp/80');
    final j = goMultiaddr.join([
      MultiaddrMultiaddrer(multiaddr: a),
      MultiaddrMultiaddrer(multiaddr: b)
    ]);
    expect(j.value, '/ip4/10.0.0.1/tcp/80');
    expect(goMultiaddr.contains([a, j], j), isTrue);
    expect(goMultiaddr.unique([a, j, a]), [a, j]);
    expect(() => goMultiaddr.newMultiaddr('/nope'),
        throwsA(isA<GolangException>()));
  });

  test('path and IPNS name', () {
    final c = goCid.newCidV1(goCid.raw, mhash);
    final p = goBoxo.path.fromCid(c);
    expect(p.value, '/ipfs/$c');
    expect(goBoxo.path.newPath('/ipfs/$c').value, p.value);
    expect(goBoxo.path.join(p, ['a', 'b']).value, '/ipfs/$c/a/b');
    expect(goBoxo.path.stringToSegments('/ipfs/$c/a'), ['ipfs', '$c', 'a']);
    expect(goBoxo.path.segmentsToString(['ipns', 'x']), '/ipns/x');
    expect(goBoxo.path.newImmutablePath(goBoxo.path.newPath('/ipfs/$c')), p);

    final (sk, pk) =
        goLibp2p.core.crypto.generateKeyPair(goLibp2p.core.crypto.ed25519, -1);
    final id = goLibp2p.core.peer.idFromPublicKey(pk);
    final name = goBoxo.ipns.nameFromPeer(id);
    expect(goBoxo.ipns.nameFromString(name.value), name);
    sk.release();
    pk.release();
  });

  test('crypto: raw keys of a type, equality, config encoding', () {
    final (sk, pk) =
        goLibp2p.core.crypto.generateKeyPair(goLibp2p.core.crypto.ed25519, -1);
    expect(sk.type(), goLibp2p.core.crypto.ed25519);
    final sk2 = goLibp2p.core.crypto.unmarshalEd25519PrivateKey(sk.raw());
    final pk2 = goLibp2p.core.crypto.unmarshalEd25519PublicKey(pk.raw());
    expect(goLibp2p.core.crypto.keyEqual(sk, sk2), isTrue);
    expect(pk.equals(pk2), isTrue);
    final bytes = goLibp2p.core.crypto.marshalPrivateKey(sk);
    expect(
        goLibp2p.core.crypto
            .configDecodeKey(goLibp2p.core.crypto.configEncodeKey(bytes)),
        bytes);
    for (final k in [sk, pk, sk2, pk2]) {
      k.release();
    }
  });

  // 0.28.0: a constant whose value depends on the target is the host's (the
  // generator runs on one machine; os.DevNull is "NUL" only on Windows).
  test('os: constants of the platform that runs', () {
    final windows = Platform.isWindows;
    expect(goOs.devNull, windows ? 'NUL' : '/dev/null');
    expect(goOs.pathSeparator, (windows ? r'\' : '/').codeUnitAt(0));
    expect(goOs.pathListSeparator, (windows ? ';' : ':').codeUnitAt(0));
  });

  test('merkledag: links of a dag-pb node through its protobuf', () {
    final child = goBoxo.ipld.merkledag.nodeWithData(Uint8List.fromList([1]));
    final root = goBoxo.ipld.merkledag.nodeWithData(Uint8List.fromList([2]))
      ..addNodeLink('a', child)
      ..addNodeLink('b', child);
    final decoded =
        goBoxo.ipld.merkledag.decodeProtobuf(root.encodeProtobuf(false));
    expect(decoded.links().map((l) => l.name), ['a', 'b']);
    expect(decoded.getNodeLink('b').cid, child.cid());
    decoded.removeNodeLink('a');
    expect(decoded.links().map((l) => l.name), ['b']);
    expect(goBoxo.ipld.merkledag.v1CidPrefix().version, 1);
    for (final n in [child, root, decoded]) {
      n.release();
    }
  });

  test('value type methods: Cid', () {
    final v0 = goCid.newCidV0(mhash);
    final v1 = goCid.newCidV1(goCid.raw, mhash);
    expect((v0.version(), v0.type()), (0, goCid.dagProtobuf));
    expect((v1.version(), v1.type()), (1, goCid.raw));
    expect(v1.hash(), mhash);
    expect(v0.bytes(), mhash);
    expect(goCid.cast(v1.bytes()), v1);
    expect(v1.byteLen(), v1.bytes().length);
    expect(v1.prefix().codec, goCid.raw);
    expect(v1.equals(goCid.decode(v1.value)), isTrue);
    expect(v1.equals(v0), isFalse);
    expect(v1.defined(), isTrue);
    expect(v1.stringOfBase(0x7a), startsWith('z')); // base58btc
  });

  test('value type methods: peer ID, multiaddr, path, IPNS name', () {
    final (sk, pk) =
        goLibp2p.core.crypto.generateKeyPair(goLibp2p.core.crypto.ed25519, -1);
    final id = goLibp2p.core.peer.idFromPublicKey(pk);
    id.validate();
    expect(goLibp2p.core.peer.idFromBytes(id.marshal()), id);
    // an ed25519 ID inlines the key
    final pk2 = id.extractPublicKey();
    expect(pk2.equals(pk), isTrue);
    expect(id.matchesPrivateKey(sk), isTrue);
    expect(id.matchesPublicKey(pk), isTrue);
    expect(id.shortString(),
        '<peer.ID ${id.value.substring(0, 2)}*${id.value.substring(id.value.length - 6)}>');

    final ip = goMultiaddr.newMultiaddr('/ip4/10.0.0.1');
    final tcp = goMultiaddr.newMultiaddr('/tcp/80');
    final full = ip.encapsulate(MultiaddrMultiaddrer(multiaddr: tcp));
    expect(full.value, '/ip4/10.0.0.1/tcp/80');
    expect(full.decapsulate(MultiaddrMultiaddrer(multiaddr: tcp)), ip);
    expect(full.valueForProtocol(6), '80'); // P_TCP
    expect(goMultiaddr.newMultiaddrBytes(full.bytes()).equal(full), isTrue);
    expect(full.compare(full), 0);

    final c = goCid.newCidV1(goCid.raw, mhash);
    final p = goBoxo.path.fromCid(c);
    expect(p.namespace(), 'ipfs');
    expect(p.mutable(), isFalse);
    expect(goBoxo.path.join(p, ['a']).segments(), ['ipfs', '$c', 'a']);
    expect(p.rootCid(), c);

    final name = goBoxo.ipns.nameFromPeer(id);
    expect(name.peer(), id);
    expect(name.asPath().value, '/ipns/$name');
    expect(name.asPath().mutable(), isTrue);
    expect(name.equal(goBoxo.ipns.nameFromCid(name.cid())), isTrue);
    expect(goBoxo.ipns.nameFromRoutingKey(name.routingKey()), name);
    for (final k in [sk, pk, pk2]) {
      k.release();
    }
  });
}
