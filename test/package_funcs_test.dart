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
    final v0 = go.ipfs.cid.newCidV0(mhash);
    expect(v0.value, startsWith('Qm'));
    expect(go.ipfs.cid.decode(v0.value), v0);
    expect(go.ipfs.cid.parse(v0.value), v0);
    // a CIDv0's bytes are its multihash
    expect(go.ipfs.cid.parse(mhash), v0);
    expect(go.ipfs.cid.cast(mhash), v0);
    expect(go.ipfs.cid.cidFromBytes(mhash), (34, v0));

    final v1 = go.ipfs.cid.newCidV1(go.ipfs.cid.raw, mhash);
    expect(v1.value, startsWith('bafk'));
    expect(go.ipfs.cid.decode(v1.value), v1);
    expect(go.ipfs.cid.extractEncoding(v1.value), 0x62); // multibase base32 'b'
    expect(
        () => go.ipfs.cid.decode('not a cid'), throwsA(isA<GolangException>()));

    final p = go.ipfs.cid.newPrefixV1(go.ipfs.cid.dagCbor, 0x12);
    final back = go.ipfs.cid.prefixFromBytes(p.bytes());
    expect((back.version, back.codec, back.mhType),
        (1, go.ipfs.cid.dagCbor, 0x12));
  });

  test('multihash and multibase: the hash and the text of a CID', () {
    final data = Uint8List.fromList([1, 2, 3]);
    final c = go.ipfs.cid
        .newPrefixV1(go.ipfs.cid.raw, go.multiformats.multihash.sha2256)
        .sum(data);
    final m = go.multiformats.multihash
        .sum(data, go.multiformats.multihash.sha2256, -1);
    expect(m, c.hash());

    final d = go.multiformats.multihash.decode(m);
    expect((d.code, d.name, d.length), (0x12, 'sha2-256', 32));
    expect(d.digest!.length, 32);
    expect(
        go.multiformats.multihash
            .encode(d.digest!, go.multiformats.multihash.sha2256),
        m);
    expect(go.multiformats.multihash.names['sha2-256'],
        go.multiformats.multihash.sha2256);
    expect(go.multiformats.multihash.codes[go.multiformats.multihash.sha2256],
        'sha2-256');
    expect(() => go.multiformats.multihash.cast(Uint8List(3)),
        throwsA(isA<GolangException>()));

    final set = MultihashSet()..add(m);
    expect((set.has(m), set.len()), (true, 1));
    set.release();

    final text = go.multiformats.multibase
        .encode(go.multiformats.multibase.base36, data);
    expect(text, startsWith('k'));
    final (base, back) = go.multiformats.multibase.decode(text);
    expect(base, go.multiformats.multibase.base36);
    expect(back, data);
    expect(
        go.ipfs.cid.extractEncoding(c.value), go.multiformats.multibase.base32);
  });

  test('peer: ID from a CID and from a /p2p multiaddr', () {
    final (sk, pk) = go.libp2p.libp2p.core.crypto
        .generateKeyPair(go.libp2p.libp2p.core.crypto.ed25519, -1);
    final id = go.libp2p.libp2p.core.peer.idFromPublicKey(pk);
    expect(go.libp2p.libp2p.core.peer.decode(id.value), id);
    expect(
        go.libp2p.libp2p.core.peer
            .fromCid(go.libp2p.libp2p.core.peer.toCid(id)),
        id);

    final tcp =
        go.multiformats.multiaddr.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = go.multiformats.multiaddr.newMultiaddr('$tcp/p2p/$id');
    expect(go.libp2p.libp2p.core.peer.idFromP2pAddr(full), id);
    expect(go.libp2p.libp2p.core.peer.splitAddr(full), (tcp, id));
    expect(
        go.libp2p.libp2p.core.peer
            .addrInfosToIds([Libp2pCorePeerAddrInfo(id: id)]),
        [id]);
    sk.release();
    pk.release();
  });

  test('multiaddr: join, contains, unique', () {
    final a = go.multiformats.multiaddr.newMultiaddr('/ip4/10.0.0.1');
    final b = go.multiformats.multiaddr.newMultiaddr('/tcp/80');
    final j = go.multiformats.multiaddr.join([
      MultiaddrMultiaddrer(multiaddr: a),
      MultiaddrMultiaddrer(multiaddr: b)
    ]);
    expect(j.value, '/ip4/10.0.0.1/tcp/80');
    expect(go.multiformats.multiaddr.contains([a, j], j), isTrue);
    expect(go.multiformats.multiaddr.unique([a, j, a]), [a, j]);
    expect(() => go.multiformats.multiaddr.newMultiaddr('/nope'),
        throwsA(isA<GolangException>()));
  });

  test('path and IPNS name', () {
    final c = go.ipfs.cid.newCidV1(go.ipfs.cid.raw, mhash);
    final p = go.ipfs.boxo.path.fromCid(c);
    expect(p.value, '/ipfs/$c');
    expect(go.ipfs.boxo.path.newPath('/ipfs/$c').value, p.value);
    expect(go.ipfs.boxo.path.join(p, ['a', 'b']).value, '/ipfs/$c/a/b');
    expect(
        go.ipfs.boxo.path.stringToSegments('/ipfs/$c/a'), ['ipfs', '$c', 'a']);
    expect(go.ipfs.boxo.path.segmentsToString(['ipns', 'x']), '/ipns/x');
    expect(
        go.ipfs.boxo.path
            .newImmutablePath(go.ipfs.boxo.path.newPath('/ipfs/$c')),
        p);

    final (sk, pk) = go.libp2p.libp2p.core.crypto
        .generateKeyPair(go.libp2p.libp2p.core.crypto.ed25519, -1);
    final id = go.libp2p.libp2p.core.peer.idFromPublicKey(pk);
    final name = go.ipfs.boxo.ipns.nameFromPeer(id);
    expect(go.ipfs.boxo.ipns.nameFromString(name.value), name);
    sk.release();
    pk.release();
  });

  test('crypto: raw keys of a type, equality, config encoding', () {
    final (sk, pk) = go.libp2p.libp2p.core.crypto
        .generateKeyPair(go.libp2p.libp2p.core.crypto.ed25519, -1);
    expect(sk.type(), go.libp2p.libp2p.core.crypto.ed25519);
    final sk2 =
        go.libp2p.libp2p.core.crypto.unmarshalEd25519PrivateKey(sk.raw());
    final pk2 =
        go.libp2p.libp2p.core.crypto.unmarshalEd25519PublicKey(pk.raw());
    expect(go.libp2p.libp2p.core.crypto.keyEqual(sk, sk2), isTrue);
    expect(pk.equals(pk2), isTrue);
    final bytes = go.libp2p.libp2p.core.crypto.marshalPrivateKey(sk);
    expect(
        go.libp2p.libp2p.core.crypto.configDecodeKey(
            go.libp2p.libp2p.core.crypto.configEncodeKey(bytes)),
        bytes);
    for (final k in [sk, pk, sk2, pk2]) {
      k.release();
    }
  });

  // 0.28.0: a constant whose value depends on the target is the host's (the
  // generator runs on one machine; os.DevNull is "NUL" only on Windows).
  test('os: constants of the platform that runs', () {
    final windows = Platform.isWindows;
    expect(go.os.devNull, windows ? 'NUL' : '/dev/null');
    expect(go.os.pathSeparator, (windows ? r'\' : '/').codeUnitAt(0));
    expect(go.os.pathListSeparator, (windows ? ';' : ':').codeUnitAt(0));
  });

  test('merkledag: links of a dag-pb node through its protobuf', () {
    final child =
        go.ipfs.boxo.ipld.merkledag.nodeWithData(Uint8List.fromList([1]));
    final root =
        go.ipfs.boxo.ipld.merkledag.nodeWithData(Uint8List.fromList([2]))
          ..addNodeLink('a', child)
          ..addNodeLink('b', child);
    final decoded =
        go.ipfs.boxo.ipld.merkledag.decodeProtobuf(root.encodeProtobuf(false));
    expect(decoded.links().map((l) => l.name), ['a', 'b']);
    expect(decoded.getNodeLink('b').cid, child.cid());
    decoded.removeNodeLink('a');
    expect(decoded.links().map((l) => l.name), ['b']);
    expect(go.ipfs.boxo.ipld.merkledag.v1CidPrefix().version, 1);
    for (final n in [child, root, decoded]) {
      n.release();
    }
  });

  test('value type methods: Cid', () {
    final v0 = go.ipfs.cid.newCidV0(mhash);
    final v1 = go.ipfs.cid.newCidV1(go.ipfs.cid.raw, mhash);
    expect((v0.version(), v0.type()), (0, go.ipfs.cid.dagProtobuf));
    expect((v1.version(), v1.type()), (1, go.ipfs.cid.raw));
    expect(v1.hash(), mhash);
    expect(v0.bytes(), mhash);
    expect(go.ipfs.cid.cast(v1.bytes()), v1);
    expect(v1.byteLen(), v1.bytes().length);
    expect(v1.prefix().codec, go.ipfs.cid.raw);
    expect(v1.equals(go.ipfs.cid.decode(v1.value)), isTrue);
    expect(v1.equals(v0), isFalse);
    expect(v1.defined(), isTrue);
    expect(v1.stringOfBase(0x7a), startsWith('z')); // base58btc
  });

  test('value type methods: peer ID, multiaddr, path, IPNS name', () {
    final (sk, pk) = go.libp2p.libp2p.core.crypto
        .generateKeyPair(go.libp2p.libp2p.core.crypto.ed25519, -1);
    final id = go.libp2p.libp2p.core.peer.idFromPublicKey(pk);
    id.validate();
    expect(go.libp2p.libp2p.core.peer.idFromBytes(id.marshal()), id);
    // an ed25519 ID inlines the key
    final pk2 = id.extractPublicKey();
    expect(pk2.equals(pk), isTrue);
    expect(id.matchesPrivateKey(sk), isTrue);
    expect(id.matchesPublicKey(pk), isTrue);
    expect(id.shortString(),
        '<peer.ID ${id.value.substring(0, 2)}*${id.value.substring(id.value.length - 6)}>');

    final ip = go.multiformats.multiaddr.newMultiaddr('/ip4/10.0.0.1');
    final tcp = go.multiformats.multiaddr.newMultiaddr('/tcp/80');
    final full = ip.encapsulate(MultiaddrMultiaddrer(multiaddr: tcp));
    expect(full.value, '/ip4/10.0.0.1/tcp/80');
    expect(full.decapsulate(MultiaddrMultiaddrer(multiaddr: tcp)), ip);
    expect(full.valueForProtocol(6), '80'); // P_TCP
    expect(
        go.multiformats.multiaddr.newMultiaddrBytes(full.bytes()).equal(full),
        isTrue);
    expect(full.compare(full), 0);

    final c = go.ipfs.cid.newCidV1(go.ipfs.cid.raw, mhash);
    final p = go.ipfs.boxo.path.fromCid(c);
    expect(p.namespace(), 'ipfs');
    expect(p.mutable(), isFalse);
    expect(go.ipfs.boxo.path.join(p, ['a']).segments(), ['ipfs', '$c', 'a']);
    expect(p.rootCid(), c);

    final name = go.ipfs.boxo.ipns.nameFromPeer(id);
    expect(name.peer(), id);
    expect(name.asPath().value, '/ipns/$name');
    expect(name.asPath().mutable(), isTrue);
    expect(name.equal(go.ipfs.boxo.ipns.nameFromCid(name.cid())), isTrue);
    expect(go.ipfs.boxo.ipns.nameFromRoutingKey(name.routingKey()), name);
    for (final k in [sk, pk, pk2]) {
      k.release();
    }
  });
}
