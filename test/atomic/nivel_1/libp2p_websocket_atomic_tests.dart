// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

// Upstream: go-libp2p e20bb60ffc4b4ee33640e5fe8f45fccce893cecd,
// p2p/transport/websocket/{websocket.go,addrs.go}. AST: libp2p-index.
//
// Pure, I/O-free coverage: multiaddr matching (canDial, mirrors TestCanDial)
// and /wss -> /tls/sni/.../ws canonicalization (resolve, mirrors
// TestResolveMultiaddr). Connection-level behavior (dial/listen/read/write
// against a real local socket) lives in
// test/atomic/nivel_2/libp2p_websocket_atomic_tests.dart.
void main() async {
  final identity = await generateEd25519KeyPair();
  WebsocketTransport newTransport() =>
      WebsocketTransport(upgrader: BasicUpgrader(localIdentityKey: identity));

  group('WebsocketTransport [Atomic Audit]', () {
    test(
      'constructor - stores upgrader, resourceManager and handshakeTimeout defaults',
      () {
        final upgrader = BasicUpgrader(localIdentityKey: identity);
        final t = WebsocketTransport(upgrader: upgrader);
        expect(t.upgrader, same(upgrader));
        expect(t.resourceManager, isA<NullResourceManager>());
        expect(t.handshakeTimeout, equals(const Duration(seconds: 15)));
        expect(t.tlsClientContext, isNull);
        expect(t.tlsSecurityContext, isNull);
      },
    );

    test('canDial() - matches a plain /ws multiaddr', () {
      final t = newTransport();
      expect(t.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/5555/ws')), isTrue);
    });

    test('canDial() - matches a plain /wss multiaddr', () {
      final t = newTransport();
      expect(t.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/5555/wss')), isTrue);
    });

    test('canDial() - rejects a bare TCP multiaddr with no ws/wss suffix', () {
      final t = newTransport();
      expect(t.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/5555')), isFalse);
    });

    test(
      'canDial() - matches /tls/ws (secure websocket without explicit SNI)',
      () {
        final t = newTransport();
        expect(
          t.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/5555/tls/ws')),
          isTrue,
        );
      },
    );

    test('canDial() - matches /tls/sni/<host>/ws', () {
      final t = newTransport();
      expect(
        t.canDial(
          Multiaddr.parse('/ip4/127.0.0.1/tcp/5555/tls/sni/example.com/ws'),
        ),
        isTrue,
      );
    });

    test('canDial() - matches a dns4 host with /tls/sni/.../ws', () {
      final t = newTransport();
      expect(
        t.canDial(
          Multiaddr.parse('/dns4/example.com/tcp/5555/tls/sni/example.com/ws'),
        ),
        isTrue,
      );
    });

    test(
      'canDial() - matches a dnsaddr host with /tls/sni/.../ws (matcher parity; dial() cannot resolve dnsaddr)',
      () {
        final t = newTransport();
        expect(
          t.canDial(
            Multiaddr.parse(
              '/dnsaddr/example.com/tcp/5555/tls/sni/example.com/ws',
            ),
          ),
          isTrue,
        );
      },
    );

    test('protocols() - returns the ws and wss protocol codes', () {
      final t = newTransport();
      expect(t.protocols(), containsAll(<int>[Protocols.ws, Protocols.wss]));
    });

    test('proxy() - returns false', () {
      final t = newTransport();
      expect(t.proxy(), isFalse);
    });

    test('resolve() - leaves a plain /ws multiaddr unchanged', () {
      final t = newTransport();
      final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/5555/ws');
      expect(t.resolve(addr), equals([addr]));
    });

    test('resolve() - derives SNI from a dns component for /dns/.../wss', () {
      final t = newTransport();
      final resolved = t.resolve(
        Multiaddr.parse('/dns/example.com/tcp/1234/wss'),
      );
      expect(resolved, hasLength(1));
      expect(
        resolved.single.toString(),
        equals('/dns/example.com/tcp/1234/tls/sni/example.com/ws'),
      );
    });

    test(
      'resolve() - derives SNI from a dns4 component for /dns4/.../tls/ws',
      () {
        final t = newTransport();
        final resolved = t.resolve(
          Multiaddr.parse('/dns4/example.com/tcp/1234/tls/ws'),
        );
        expect(resolved, hasLength(1));
        expect(
          resolved.single.toString(),
          equals('/dns4/example.com/tcp/1234/tls/sni/example.com/ws'),
        );
      },
    );

    test('resolve() - derives SNI from a dns6 component for /dns6/.../wss', () {
      final t = newTransport();
      final resolved = t.resolve(
        Multiaddr.parse('/dns6/example.com/tcp/1234/wss'),
      );
      expect(resolved, hasLength(1));
      expect(
        resolved.single.toString(),
        equals('/dns6/example.com/tcp/1234/tls/sni/example.com/ws'),
      );
    });

    test(
      'resolve() - leaves /dnsaddr/.../wss unchanged (dnsaddr is not a derivable SNI source)',
      () {
        final t = newTransport();
        final addr = Multiaddr.parse('/dnsaddr/example.com/tcp/1234/wss');
        expect(t.resolve(addr), equals([addr]));
      },
    );

    test(
      'resolve() - leaves /dnsaddr/.../tls/ws unchanged (no dns component to derive SNI from)',
      () {
        final t = newTransport();
        final addr = Multiaddr.parse('/dnsaddr/example.com/tcp/1234/tls/ws');
        expect(t.resolve(addr), equals([addr]));
      },
    );

    test(
      'resolve() - throws FormatException for a non-websocket multiaddr',
      () {
        final t = newTransport();
        expect(
          () => t.resolve(Multiaddr.parse('/ip4/127.0.0.1/tcp/5555')),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
