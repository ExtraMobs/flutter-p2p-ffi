// Lesson 13 · Who am I on the network?
//
// Question: so far everything was local. To talk to other machines, my
// program needs a name and an address on the network. What are they, and
// what decides them?
//
// Answer: libp2p, the networking layer under IPFS. Three ideas:
//   - the peer ID: the hash of a public key (`12D3KooW...`). It is who you
//     are, wherever you connect from; keeping the private key keeps the ID.
//     Every connection proves it with a signature, so it cannot be faked.
//   - the multiaddr: how to reach you, as a path of protocols
//     (`/ip4/127.0.0.1/tcp/4001/p2p/12D3KooW...`): an IP, a transport, a
//     port and, at the end, the peer ID expected there. One peer has many.
//   - the host: the object that holds the key, listens on the addresses and
//     speaks a stack of protocols for each connection: a transport (TCP,
//     QUIC, WebSocket...), a security layer (Noise or TLS: encrypts and
//     checks the peer ID) and a muxer (yamux: many streams in one
//     connection).
// A kubo node (lesson 08) builds its host from the identity and the
// Addresses of its config; here we build hosts directly, without kubo.
//
// Needs: lesson 01 (the service). Technically, a host needs a key pair
// (generated or loaded), listen addresses the system lets it bind, and at
// least one transport, security and muxer (libp2p's defaults if not given).
//
//   dart run example/en_us/13_who_am_i.dart
//
// Next question: "I have an address; how do two hosts actually talk?" →
// lesson 14.
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/crypto.dart' as crypto;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/go/libp2p/p2p/muxer/yamux.dart' as yamux;
import 'package:p2p_ffi/go/libp2p/p2p/security/noise.dart' as noise;
import 'package:p2p_ffi/go/libp2p/p2p/transport/tcp.dart' as tcp;
import 'package:p2p_ffi/go/multiaddr.dart' as multiaddr;
import 'package:p2p_ffi/go/multibase.dart' as multibase;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    // 1. A key pair, and the peer ID that comes from it.
    //    Go:  sk, pk, _ := crypto.GenerateKeyPair(crypto.Ed25519, -1)
    //         id, _ := peer.IDFromPrivateKey(sk)
    final (sk, pk) = crypto.generateKeyPair(crypto.ed25519, -1);
    final id = peer.idFromPrivateKey(sk);
    say('peer ID: $id');
    say('  from the public key too: ${peer.idFromPublicKey(pk) == id}; '
        'matches the private key: ${id.matchesPrivateKey(sk)}');
    // The same ID as a CID (codec libp2p-key): what an IPNS name is
    // (lesson 11).
    final asCid = peer.toCid(id);
    say('  as a CID: ${asCid.stringOfBase(multibase.base36)} (codec 0x'
        '${asCid.type().toRadixString(16)}, libp2p-key: '
        '${asCid.type() == multicodec.libp2pKey})');

    // 2. Keep the key, keep the ID: marshal it (to a file, to secure
    //    storage), unmarshal it on the next start.
    //    Go:  b, _ := crypto.MarshalPrivateKey(sk); sk2, _ := crypto.UnmarshalPrivateKey(b)
    final saved = crypto.marshalPrivateKey(sk);
    final loaded = crypto.unmarshalPrivateKey(saved);
    say('\nthe key saved as ${saved.length} bytes and loaded back: same ID '
        '${peer.idFromPrivateKey(loaded) == id}');

    // 3. Multiaddrs: parse, take apart, put together.
    //    Go:  ma, _ := multiaddr.NewMultiaddr("/ip4/127.0.0.1/tcp/4001")
    final addr = multiaddr.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = multiaddr.newMultiaddr('$addr/p2p/$id');
    say('\nmultiaddr $addr');
    say('  with the peer: $full');
    say('  the TCP port: ${addr.valueForProtocol(6)}; the peer at the end: '
        '${peer.splitAddr(full).$2 == id}');

    // 4. A host with this key, listening on two transports, ports chosen by
    //    the system (0).
    //    Go:  h, _ := libp2p.New(libp2p.Identity(sk), libp2p.ListenAddrStrings(...))
    final h = await libp2p.new$([
      libp2p.identity(loaded),
      libp2p.listenAddrStrings(
          ['/ip4/127.0.0.1/tcp/0', '/ip4/127.0.0.1/udp/0/quic-v1']),
    ]);
    say('\na host: ${h.id()} (the same ID: ${h.id() == id})');
    for (final a in h.addrs()) {
      say('  listening on $a');
    }
    await h.close();

    // 5. Choosing the stack by hand: only TCP, Noise and yamux. Each piece
    //    is a Go constructor, passed as a token.
    //    Go:  libp2p.New(libp2p.Transport(tcp.NewTCPTransport),
    //             libp2p.Security(noise.ID, noise.New), libp2p.Muxer(yamux.ID, yamux.DefaultTransport))
    final small = await libp2p.new$([
      libp2p.transport(tcp.newTcpTransportFunc),
      libp2p.security(noise.id, noise.newFunc),
      libp2p.muxer(yamux.id, yamux.defaultTransport),
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ]);
    say('\na TCP-only host: ${small.addrs()} (a random key: another ID, '
        '${small.id().shortString()})');

    say('\n== Common mistakes\n');
    await mistake("listening on an IP that is not this machine's",
        why: 'a host can only listen on its own interfaces (0.0.0.0 means '
            'all of them)',
        instead: '/ip4/0.0.0.0/tcp/0, or 127.0.0.1 for this machine only',
        action: () async => (await libp2p.new$([
              libp2p.listenAddrStrings(['/ip4/203.0.113.7/tcp/0'])
            ]))
                .close());
    await small.close();
    await mistake('a multiaddr written like a URL',
        why: 'a multiaddr is /protocol/value pairs, not host:port',
        instead: '/ip4/127.0.0.1/tcp/4001 (or /dns4/example.com/tcp/4001)',
        action: () => multiaddr.newMultiaddr('127.0.0.1:4001'));
    await mistake('a peer ID that is not one',
        why: 'a peer ID is a multihash of a key; random text does not decode',
        instead: 'take it from the host (h.id()) or from a /p2p/ address',
        action: () => peer.decode('my-peer'));
    await silentlyWrong('a new key on every start',
        why: 'the peer ID is the key: a new key is a new peer for everyone '
            'who knew you',
        instead: 'marshal the key once and load it on every start (step 2)',
        wrong: () => peer
            .idFromPrivateKey(crypto.generateKeyPair(crypto.ed25519, -1).$1),
        right: () => peer.idFromPrivateKey(crypto.unmarshalPrivateKey(saved)));
  } finally {
    await P2pService.stop();
  }
}
