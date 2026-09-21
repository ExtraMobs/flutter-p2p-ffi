@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart' show ConnSecurity;
import 'package:transpiled_multibase/transpiled_multibase.dart' as multibase;
import 'package:transpiled_multihash/transpiled_multihash.dart' as multihash;
import 'package:transpiled_quic_go/src/client_handshake.dart' as quicgo;
import 'package:transpiled_webtransport_go/transpiled_webtransport_go.dart'
    as webtransport;

import '../lib/local_kubo_harness.dart';

/// Marco G.4, first layer -- the QUIC/TLS floor that WebTransport stands on.
///
/// A WebTransport multiaddr is an HTTP/3 endpoint, so its QUIC handshake
/// negotiates ALPN `h3` rather than `libp2p`, and the server is authenticated
/// not by a CA chain but by matching the SHA-256 of its leaf certificate
/// against the `certhash` components of the multiaddr itself
/// (https://www.w3.org/TR/webtransport/#certificate-hashes, and go-libp2p's
/// `p2p/transport/webtransport/crypto.go` `verifyRawCerts`).
///
/// This test proves exactly that floor against a real Kubo daemon and nothing
/// above it: `h3` is agreed and the certificate Kubo presents really does hash
/// to a certhash it published. A failure here means every WebTransport layer
/// above is untestable, so it is worth isolating.
void main() {
  _webtransportBitswapTest();

  test(
    'completes a QUIC handshake with ALPN h3 against Kubo and matches its certhash',
    () async {
      final executable = await LocalKuboHarness.findExecutable();
      if (executable == null) {
        markTestSkipped('Kubo executable not found');
        return;
      }

      final kubo = await LocalKuboHarness.start(
        executable: executable,
        swarmAddresses: const ['/ip4/127.0.0.1/udp/0/quic-v1/webtransport'],
      );
      try {
        final addresses = await kubo.effectiveSwarmAddresses();
        expect(
          addresses,
          isNotEmpty,
          reason: 'Kubo published no WebTransport address',
        );
        final address = addresses.first;
        expect(address, contains('/webtransport'));

        final port = int.parse(
          RegExp(r'/udp/(\d+)/').firstMatch(address)!.group(1)!,
        );
        final expectedHashes = _certHashesOf(address);
        expect(
          expectedHashes,
          isNotEmpty,
          reason: 'Kubo published no certhash to pin against',
        );

        final socket = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        var verified = false;
        try {
          final conn = await quicgo.dial(
            socket: socket,
            remoteAddress: InternetAddress.loopbackIPv4,
            remotePort: port,
            tlsConfig: quicgo.QuicTlsConfig(
              nextProtos: const ['h3'],
              verifyPeerCertificate: (chain) async {
                expect(chain, isNotEmpty, reason: 'Kubo presented no cert');
                final leaf = chain.last;
                final digest = Uint8List.fromList(
                  crypto_pkg.sha256.convert(leaf).bytes,
                );
                expect(
                  expectedHashes.any((h) => _sameBytes(h, digest)),
                  isTrue,
                  reason:
                      'leaf certificate hash is not one of the published certhashes',
                );
                verified = true;
              },
            ),
            // webtransport-go's server refuses a session whose client did
            // not advertise QUIC datagram support (`server.go`'s
            // "missing QUIC Datagram support").
            enableDatagrams: true,
            handshakeTimeout: const Duration(seconds: 15),
          );

          expect(verified, isTrue, reason: 'certificate was never verified');
          expect(conn.negotiatedProtocol, equals('h3'));
          expect(conn.peerCertificates, isNotEmpty);

          // Layer two: the HTTP/3 Extended CONNECT that turns this QUIC
          // connection into a WebTransport session, exactly as go-libp2p's
          // `p2p/transport/webtransport/transport.go` dials it.
          final session = await const webtransport.Dialer().dial(
            conn: conn,
            authority: '127.0.0.1:$port',
            path: '/.well-known/libp2p-webtransport?type=noise',
          );
          expect(session.sessionId % 4, equals(0));
          expect(session.isClosed, isFalse);
          await session.close();
        } finally {
          socket.close();
        }
      } finally {
        await kubo.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Extracts the SHA-256 digests carried by the `/certhash/...` components of a
/// WebTransport multiaddr.
List<Uint8List> _certHashesOf(String address) {
  final hashes = <Uint8List>[];
  final parts = address.split('/');
  for (var i = 0; i + 1 < parts.length; i++) {
    if (parts[i] != 'certhash') continue;
    final (_, decoded) = multibase.decode(parts[i + 1]);
    hashes.add(Uint8List.fromList(multihash.decode(decoded).digest));
  }
  return hashes;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Marco G.4 -- the whole WebTransport stack, proved against a real Kubo.
///
/// QUIC with ALPN `h3` and the certificate pinned by `certhash`, an HTTP/3
/// Extended CONNECT to `/.well-known/libp2p-webtransport?type=noise`, a Noise
/// handshake on the session's first stream whose early data carries the
/// server's `webtransport_certhashes`, and then Bitswap on a session stream
/// retrieving a block by CID. Nothing here is loopback: every byte crosses to
/// a go-libp2p implementation and back.
void _webtransportBitswapTest() {
  test('dials Kubo over quic-v1/webtransport and retrieves block via Bitswap',
      () async {
    final executable = await LocalKuboHarness.findExecutable();
    if (executable == null) {
      markTestSkipped('Kubo executable not found');
      return;
    }

    final kubo = await LocalKuboHarness.start(
      executable: executable,
      swarmAddresses: const ['/ip4/127.0.0.1/udp/0/quic-v1/webtransport'],
    );
    try {
      final addresses = await kubo.effectiveSwarmAddresses();
      expect(
        addresses,
        isNotEmpty,
        reason: 'Kubo reported no WebTransport addresses',
      );
      final address = addresses.first;
      expect(address, contains('/webtransport'));
      expect(address, contains('/certhash/'));

      final bytes = Uint8List.fromList(
        'hello webtransport bitswap block'.codeUnits,
      );
      final cid = Cid.decode(await kubo.putRawBlock(bytes));

      final node = await IpfsNode.fromBuildCfg(
        BuildCfg(
          online: true,
          config: const IpfsConfig(
            offline: false,
            network: NetworkConfig(bootstrapPeers: []),
          ),
        ),
      );
      try {
        await node
            .connect(addrInfoFromString(address))
            .timeout(const Duration(seconds: 20));

        // The proof is worthless unless the bytes really travelled over
        // WebTransport, so assert the transport the live connection reports
        // rather than trusting that Kubo published nothing else.
        final conns = node.peerHost!.network.conns();
        expect(conns, isNotEmpty, reason: 'no connection was established');
        expect(
          conns.whereType<ConnSecurity>().map(
                (c) => c.connState().transport,
              ),
          everyElement(equals('webtransport')),
        );

        final downloaded =
            await node.getBlock(cid).timeout(const Duration(seconds: 20));
        expect(downloaded.rawData(), orderedEquals(bytes));
        expect(downloaded.cid(), equals(cid));
      } finally {
        await node.close();
      }
    } finally {
      await kubo.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
