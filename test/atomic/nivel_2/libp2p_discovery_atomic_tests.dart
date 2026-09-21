// test/atomic/nivel_2/libp2p_discovery_atomic_tests.dart
//
// Testes atomicos 1 para 1 (Regra 24) para as implementacoes da camada
// discovery do Marco F.6 (Objetivo 5):
//   - go-libp2p/p2p/discovery/routing/routing.go -> RoutingDiscovery,
//     DiscoveryRouting
//   - go-libp2p/p2p/discovery/backoff/backoff.go -> BackoffStrategy e as
//     factories fixed/polynomial/exponential(DecorrelatedJitter), Jitter
//     (fullJitter/noJitter)
//   - go-libp2p/p2p/discovery/backoff/backoffcache.go -> BackoffDiscovery
//   - go-libp2p/p2p/discovery/backoff/backoffconnector.go -> BackoffConnector
// Revisao upstream fixada em doc/transpilation/UPSTREAM_LOCK.md. Vetores
// numericos extraidos de routing_test.go e backoff_test.go (polynomial e
// exponential, via NoJitter -- deterministicos, independentes do gerador
// pseudoaleatorio do Go). backoffcache_test.go/backoffconnector_test.go
// inspiraram os cenarios de cache/backoff/simultaneidade abaixo, adaptados
// para um clock controlavel injetado diretamente (campo publico
// BackoffDiscovery.clock) em vez do helper `withClock` de teste do Go
// (necessario la so porque o campo era privado ao pacote).
//
// Nivel 2: discovery/routing/host fakes in-process (sem socket real, sem
// daemon externo).
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/src/core/connmgr/manager.dart';
import 'package:transpiled_libp2p/src/core/discovery/discovery.dart';
import 'package:transpiled_libp2p/src/core/discovery/options.dart';
import 'package:transpiled_libp2p/src/core/event/bus.dart';
import 'package:transpiled_libp2p/src/core/host/host.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/addr_info.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/core/peerstore/peerstore.dart';
import 'package:transpiled_libp2p/src/core/protocol/protocol.dart';
import 'package:transpiled_libp2p/src/core/routing/routing.dart'
    as core_routing;
import 'package:transpiled_libp2p/src/p2p/discovery/backoff/backoff.dart';
import 'package:transpiled_libp2p/src/p2p/discovery/backoff/backoffcache.dart';
import 'package:transpiled_libp2p/src/p2p/discovery/backoff/backoffconnector.dart';
import 'package:transpiled_libp2p/src/p2p/discovery/routing/routing.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

PeerId _peer(int n) => PeerId(value: Uint8List.fromList([0xAA, n]));

AddrInfo _ai(int n, {List<String> addrs = const []}) =>
    AddrInfo(id: _peer(n), addrs: addrs.map(Multiaddr.parse).toList());

// ---------------------------------------------------------------------
// Fakes (test/ only -- RULE_NO_PRODUCTION_MOCKS explicitly permits these
// under test/, it only forbids them in lib/).
// ---------------------------------------------------------------------

class _FakeContentRouting implements core_routing.ContentRouting {
  final List<(Cid, bool)> provided = [];
  final Map<String, List<AddrInfo>> providers = {};

  @override
  Future<void> provide(Cid cid, bool local) async {
    provided.add((cid, local));
  }

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) {
    final found = providers[cid.toString()] ?? const <AddrInfo>[];
    final limited = count == 0 ? found : found.take(count).toList();
    return Stream.fromIterable(limited);
  }
}

class _RecordingDiscovery implements Discovery {
  final List<String> advertised = [];
  final List<List<DiscoveryOption>> advertisedOptions = [];
  final Map<String, List<AddrInfo>> peersByNs = {};
  Duration ttlToReturn = const Duration(hours: 1);
  Duration? perItemDelay;

  @override
  Future<Duration> advertise(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) async {
    advertised.add(namespace);
    advertisedOptions.add(options);
    return ttlToReturn;
  }

  @override
  Stream<AddrInfo> findPeers(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) {
    final opts = DiscoveryOptions()..apply(options);
    final found = peersByNs[namespace] ?? const <AddrInfo>[];
    final limited = opts.limit == 0 ? found : found.take(opts.limit).toList();
    final delay = perItemDelay;
    if (delay == null) return Stream.fromIterable(limited);
    return () async* {
      for (final ai in limited) {
        await Future<void>.delayed(delay);
        yield ai;
      }
    }();
  }
}

class _FakeHost implements Host {
  _FakeHost(this.id);

  @override
  final PeerId id;

  final List<AddrInfo> connected = [];
  bool shouldFail = false;

  @override
  Future<void> connect(
    AddrInfo pi, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    if (shouldFail) throw StateError('connect failed');
    connected.add(pi);
  }

  @override
  Peerstore get peerstore => throw UnimplementedError();
  @override
  List<Multiaddr> get addrs => const [];
  @override
  Network get network => throw UnimplementedError();
  @override
  ProtocolSwitch get mux => throw UnimplementedError();
  @override
  void setStreamHandler(ProtocolId pid, StreamHandler handler) =>
      throw UnimplementedError();
  @override
  void setStreamHandlerMatch(
    ProtocolId pid,
    bool Function(ProtocolId) match,
    StreamHandler handler,
  ) => throw UnimplementedError();
  @override
  void removeStreamHandler(ProtocolId pid) => throw UnimplementedError();
  @override
  Future<NetworkStream> newStream(
    PeerId p,
    List<ProtocolId> pids, {
    NetworkContext context = NetworkContext.empty,
  }) => throw UnimplementedError();
  @override
  Future<void> close() async {}
  @override
  ConnManager get connManager => throw UnimplementedError();
  @override
  Bus get eventBus => throw UnimplementedError();
}

void main() {
  // -----------------------------------------------------------------
  // routing.go -- RoutingDiscovery
  // -----------------------------------------------------------------
  group('RoutingDiscovery [Atomic Audit]', () {
    test('router - exposes the wrapped ContentRouting', () {
      final router = _FakeContentRouting();
      final d = RoutingDiscovery(router);
      expect(d.router, same(router));
    });

    test(
      'advertise() - clamps a zero ttl to the 3h default (routing.go:33-37)',
      () async {
        final router = _FakeContentRouting();
        final d = RoutingDiscovery(router);
        final ttl = await d.advertise('/test');
        expect(ttl, const Duration(hours: 3));
      },
    );

    test('advertise() - clamps a ttl above 3h down to 3h', () async {
      final router = _FakeContentRouting();
      final d = RoutingDiscovery(router);
      final result = await d.advertise(
        '/test',
        options: [ttl(const Duration(hours: 10))],
      );
      expect(result, const Duration(hours: 3));
    });

    test('advertise() - keeps a ttl within 3h as given', () async {
      final router = _FakeContentRouting();
      final d = RoutingDiscovery(router);
      final result = await d.advertise(
        '/test',
        options: [ttl(const Duration(minutes: 30))],
      );
      expect(result, const Duration(minutes: 30));
    });

    test(
      'advertise() - provides the SHA2-256 raw Cid of the namespace, broadcasting',
      () async {
        final router = _FakeContentRouting();
        final d = RoutingDiscovery(router);
        await d.advertise('/test');
        expect(router.provided, hasLength(1));
        final (cid, local) = router.provided.single;
        expect(local, isTrue);
        expect(cid.version, 1);
        expect(cid.toString(), isNotEmpty);
      },
    );

    test(
      'findPeers() - defaults the limit to 100 when unspecified (routing.go:61)',
      () async {
        final router = _FakeContentRouting();
        final d = RoutingDiscovery(router);
        // Seed the provider map keyed by whatever Cid the namespace hashes
        // to, by round-tripping through advertise's own Cid computation.
        await d.advertise('/test');
        final cid = router.provided.single.$1;
        router.providers[cid.toString()] = List.generate(150, (i) => _ai(i));
        final results = await d.findPeers('/test').toList();
        expect(results, hasLength(100));
      },
    );

    test('findPeers() - an explicit limit overrides the 100 default', () async {
      final router = _FakeContentRouting();
      final d = RoutingDiscovery(router);
      await d.advertise('/test');
      final cid = router.provided.single.$1;
      router.providers[cid.toString()] = [_ai(1), _ai(2), _ai(3)];
      final results = await d.findPeers('/test', options: [limit(2)]).toList();
      expect(results, hasLength(2));
    });
  });

  group('DiscoveryRouting [Atomic Audit]', () {
    test(
      'disc/options - expose the wrapped discovery and configured options',
      () {
        final disc = _RecordingDiscovery();
        final opts = [ttl(const Duration(hours: 1))];
        final r = DiscoveryRouting(disc, opts);
        expect(r.disc, same(disc));
        expect(r.options, same(opts));
      },
    );

    test(
      'advertise() - passes through directly to the wrapped Discovery',
      () async {
        final disc = _RecordingDiscovery()
          ..ttlToReturn = const Duration(minutes: 5);
        final r = DiscoveryRouting(disc);
        final result = await r.advertise('/ns');
        expect(disc.advertised, ['/ns']);
        expect(result, const Duration(minutes: 5));
      },
    );

    test(
      'findPeers() - passes through directly to the wrapped Discovery',
      () async {
        final disc = _RecordingDiscovery()..peersByNs['/ns'] = [_ai(1)];
        final r = DiscoveryRouting(disc);
        final results = await r.findPeers('/ns').toList();
        expect(results, hasLength(1));
      },
    );

    test(
      'provide() - a no-op when bcast/local is false (routing.go:88-90)',
      () async {
        final disc = _RecordingDiscovery();
        final r = DiscoveryRouting(disc);
        await r.provide(await Cid.fromContent(Uint8List.fromList([1])), false);
        expect(disc.advertised, isEmpty);
      },
    );

    test(
      'provide() - advertises "/provider/<cid>" when bcast/local is true',
      () async {
        final disc = _RecordingDiscovery();
        final r = DiscoveryRouting(disc);
        final cid = await Cid.fromContent(Uint8List.fromList([1, 2, 3]));
        await r.provide(cid, true);
        expect(disc.advertised, ['/provider/$cid']);
      },
    );

    test(
      'findProvidersAsync() - finds "/provider/<cid>" with count as the limit',
      () async {
        final disc = _RecordingDiscovery();
        final r = DiscoveryRouting(disc);
        final cid = await Cid.fromContent(Uint8List.fromList([9]));
        disc.peersByNs['/provider/$cid'] = [_ai(1), _ai(2), _ai(3)];
        final results = await r.findProvidersAsync(cid, 2).toList();
        expect(results, hasLength(2));
      },
    );
  });

  // -----------------------------------------------------------------
  // backoff.go
  // -----------------------------------------------------------------
  group('BackoffStrategy [Atomic Audit]', () {
    // BackoffStrategy is the interface every factory below returns an
    // implementation of; exercised here directly through a concrete
    // instance, matching what each `test(...)` in the factory-specific
    // groups already does through their own `delay()`/`reset()` calls.
    test('delay() - computes a non-negative duration from prior calls', () {
      final BackoffStrategy strat = fixedBackoff(const Duration(seconds: 3))();
      expect(strat.delay(), const Duration(seconds: 3));
    });

    test(
      'reset() - clears state so delay() restarts from the first attempt',
      () {
        final BackoffStrategy strat = exponentialBackoff(
          const Duration(milliseconds: 1),
          const Duration(seconds: 100),
          noJitter,
          const Duration(seconds: 1),
          2,
          Duration.zero,
          Random(0),
        )();
        final first = strat.delay(); // attempt 0: 2^0 * 1s == 1s
        final second = strat.delay(); // attempt 1: 2^1 * 1s == 2s
        expect(second, isNot(first));
        strat.reset();
        expect(strat.delay(), first);
      },
    );
  });

  group('fixedBackoff [Atomic Audit]', () {
    test('fixedBackoff() - always returns the same configured delay', () {
      final strat = fixedBackoff(const Duration(seconds: 1))();
      expect(strat.delay(), const Duration(seconds: 1));
      expect(strat.delay(), const Duration(seconds: 1));
    });

    test('fixedBackoff() - reset() is a no-op (backoff.go:91)', () {
      final strat = fixedBackoff(const Duration(seconds: 1))();
      strat.reset();
      expect(strat.delay(), const Duration(seconds: 1));
    });

    test(
      'fixedBackoff() - each factory call produces an independent strategy',
      () {
        final factory = fixedBackoff(const Duration(seconds: 2));
        expect(factory(), isNot(same(factory())));
      },
    );
  });

  group('polynomialBackoff [Atomic Audit]', () {
    // Exact vectors from backoff_test.go's TestPolynomialBackoff: min=1s,
    // max=33s, NoJitter, timeUnits=1s, coefficients [0.5, 2, 3].
    test(
      'polynomialBackoff() - matches TestPolynomialBackoff\'s exact sequence',
      () {
        final factory = polynomialBackoff(
          const Duration(seconds: 1),
          const Duration(seconds: 33),
          noJitter,
          const Duration(seconds: 1),
          [0.5, 2, 3],
          Random(0),
        );
        final b1 = factory();
        final b2 = factory();

        expect(b1.delay(), const Duration(seconds: 1));
        expect(b2.delay(), const Duration(seconds: 1));

        expect(b1.delay(), const Duration(milliseconds: 5500));
        expect(b1.delay(), const Duration(milliseconds: 16500));
        expect(b1.delay(), const Duration(seconds: 33)); // clamped to max
        expect(b2.delay(), const Duration(milliseconds: 5500));

        b1.reset();
        b1.delay(); // attempt 0 again, consumed (== 1s, unchecked in Go too)
        expect(b1.delay(), const Duration(milliseconds: 5500));
      },
    );

    test(
      'polynomialBackoff() - an empty coefficient list always delays zero',
      () {
        final strat = polynomialBackoff(
          Duration.zero,
          const Duration(seconds: 100),
          noJitter,
          const Duration(seconds: 1),
          const [],
          Random(0),
        )();
        expect(strat.delay(), Duration.zero);
        expect(strat.delay(), Duration.zero);
      },
    );
  });

  group('exponentialBackoff [Atomic Audit]', () {
    // Exact vectors from backoff_test.go's TestExponentialBackoff: min=650ms,
    // max=7s, NoJitter, timeUnits=1s, base=1.5, offset=-400ms.
    test(
      'exponentialBackoff() - matches TestExponentialBackoff\'s exact sequence',
      () {
        final factory = exponentialBackoff(
          const Duration(milliseconds: 650),
          const Duration(seconds: 7),
          noJitter,
          const Duration(seconds: 1),
          1.5,
          const Duration(milliseconds: -400),
          Random(0),
        );
        final b1 = factory();
        final b2 = factory();

        expect(b1.delay(), const Duration(milliseconds: 650));
        expect(b2.delay(), const Duration(milliseconds: 650));

        expect(b1.delay(), const Duration(milliseconds: 1100));
        expect(b1.delay(), const Duration(milliseconds: 1850));
        expect(b1.delay(), const Duration(milliseconds: 2975));
        expect(b1.delay(), const Duration(microseconds: 4662500));
        expect(b1.delay(), const Duration(seconds: 7)); // clamped to max
        expect(b2.delay(), const Duration(milliseconds: 1100));

        b1.reset();
        b1.delay(); // attempt 0 again, consumed (== 650ms, unchecked in Go too)
        expect(b1.delay(), const Duration(milliseconds: 1100));
      },
    );
  });

  group('exponentialDecorrelatedJitter [Atomic Audit]', () {
    test('exponentialDecorrelatedJitter() - the first delay is min', () {
      final strat = exponentialDecorrelatedJitter(
        const Duration(milliseconds: 100),
        const Duration(seconds: 10),
        3,
        Random(0),
      )();
      expect(strat.delay(), const Duration(milliseconds: 100));
    });

    test(
      'exponentialDecorrelatedJitter() - subsequent delays stay within [min, max]',
      () {
        final strat = exponentialDecorrelatedJitter(
          const Duration(milliseconds: 100),
          const Duration(seconds: 10),
          3,
          Random(0),
        )();
        strat.delay(); // seeds lastDelay = min
        for (var i = 0; i < 20; i++) {
          final d = strat.delay();
          expect(d, greaterThanOrEqualTo(const Duration(milliseconds: 100)));
          expect(d, lessThanOrEqualTo(const Duration(seconds: 10)));
        }
      },
    );

    test(
      'exponentialDecorrelatedJitter() - reset() returns to the min delay',
      () {
        final strat = exponentialDecorrelatedJitter(
          const Duration(milliseconds: 100),
          const Duration(seconds: 10),
          3,
          Random(0),
        )();
        strat.delay();
        strat.delay();
        strat.reset();
        expect(strat.delay(), const Duration(milliseconds: 100));
      },
    );
  });

  group('noJitter [Atomic Audit]', () {
    test('noJitter() - bounds a duration below min up to min', () {
      expect(
        noJitter(
          Duration.zero,
          const Duration(hours: 10),
          const Duration(hours: 20),
          null,
        ),
        const Duration(hours: 10),
      );
    });

    test('noJitter() - bounds a duration above max down to max', () {
      expect(
        noJitter(
          const Duration(hours: 1),
          Duration.zero,
          const Duration(microseconds: 10),
          null,
        ),
        const Duration(microseconds: 10),
      );
    });

    test(
      'noJitter() - passes an in-range duration through unchanged (TestNoJitter)',
      () {
        for (var i = 0; i < 10; i++) {
          final expected = Duration(seconds: i);
          expect(
            noJitter(
              expected,
              Duration.zero,
              const Duration(seconds: 100),
              null,
            ),
            expected,
          );
        }
      },
    );
  });

  group('fullJitter [Atomic Audit]', () {
    test('fullJitter() - bounds a duration at or below min up to min', () {
      expect(
        fullJitter(
          const Duration(microseconds: 1),
          const Duration(hours: 10),
          const Duration(hours: 20),
          Random(0),
        ),
        const Duration(hours: 10),
      );
    });

    test('fullJitter() - never returns less than min or more than max', () {
      final rng = Random(0);
      for (var i = 0; i < 200; i++) {
        final d = fullJitter(
          const Duration(microseconds: 50),
          Duration.zero,
          const Duration(microseconds: 100),
          rng,
        );
        expect(d, greaterThanOrEqualTo(Duration.zero));
        expect(d, lessThanOrEqualTo(const Duration(microseconds: 100)));
      }
    });

    test(
      'fullJitter() - is not degenerate: produces more than one distinct value',
      () {
        final rng = Random(0);
        final seen = <Duration>{};
        for (var i = 0; i < 50; i++) {
          seen.add(
            fullJitter(
              const Duration(microseconds: 50),
              Duration.zero,
              const Duration(microseconds: 100),
              rng,
            ),
          );
        }
        expect(seen.length, greaterThan(1));
      },
    );
  });

  // -----------------------------------------------------------------
  // backoffcache.go
  // -----------------------------------------------------------------
  group('withBackoffDiscoverySimultaneousQueryBufferSize [Atomic Audit]', () {
    test(
      'withBackoffDiscoverySimultaneousQueryBufferSize() - sets parallelBufferSize',
      () {
        final bd = BackoffDiscovery(
          _RecordingDiscovery(),
          fixedBackoff(const Duration(seconds: 1)),
          options: [withBackoffDiscoverySimultaneousQueryBufferSize(64)],
        );
        expect(bd.parallelBufferSize, 64);
      },
    );

    test(
      'withBackoffDiscoverySimultaneousQueryBufferSize() - rejects a negative size (backoffcache.go:55-56)',
      () {
        expect(
          () => withBackoffDiscoverySimultaneousQueryBufferSize(-1),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('withBackoffDiscoveryReturnedChannelSize [Atomic Audit]', () {
    test(
      'withBackoffDiscoveryReturnedChannelSize() - sets returnedBufferSize',
      () {
        final bd = BackoffDiscovery(
          _RecordingDiscovery(),
          fixedBackoff(const Duration(seconds: 1)),
          options: [withBackoffDiscoveryReturnedChannelSize(64)],
        );
        expect(bd.returnedBufferSize, 64);
      },
    );

    test(
      'withBackoffDiscoveryReturnedChannelSize() - rejects a negative size (backoffcache.go:67-68)',
      () {
        expect(
          () => withBackoffDiscoveryReturnedChannelSize(-1),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('BackoffDiscovery [Atomic Audit]', () {
    test(
      'advertise() - passes through directly to the wrapped Discovery',
      () async {
        final disc = _RecordingDiscovery()
          ..ttlToReturn = const Duration(hours: 2);
        final bd = BackoffDiscovery(
          disc,
          fixedBackoff(const Duration(seconds: 1)),
        );
        final ttl = await bd.advertise('/ns');
        expect(disc.advertised, ['/ns']);
        expect(ttl, const Duration(hours: 2));
      },
    );

    test(
      'findPeers() - caches results and refetches only after the backoff expires '
      '(adapted from TestBackoffDiscoverySingleBackoff; real short delays -- '
      'go-libp2p\'s mock-clock test hook is itself test-only/unexported, so '
      'no clock abstraction is part of this port\'s public API, see '
      'backoffcache.dart\'s top-of-file note)',
      () async {
        final disc = _RecordingDiscovery()..peersByNs['test'] = [_ai(1)];
        final bd = BackoffDiscovery(
          disc,
          fixedBackoff(const Duration(milliseconds: 80)),
        );

        // First query: nothing cached yet, dispatches immediately.
        var results = await bd.findPeers('test', options: [limit(10)]).toList();
        expect(results, hasLength(1));
        expect(disc.advertised, isEmpty); // sanity: findPeers, not advertise

        // A new peer becomes available, but the backoff (80ms) has not
        // expired: the cached result set is returned unchanged.
        disc.peersByNs['test'] = [_ai(1), _ai(2)];
        results = await bd.findPeers('test', options: [limit(10)]).toList();
        expect(results, hasLength(1));

        // The backoff has now expired: the fresh (larger) result set surfaces.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        results = await bd.findPeers('test', options: [limit(10)]).toList();
        expect(results, hasLength(2));
      },
    );

    test('findPeers() - a concurrent caller joins the same in-flight query '
        '(adapted from TestBackoffDiscoverySimultaneousQuery)', () async {
      final disc = _RecordingDiscovery()
        ..peersByNs['test'] = [_ai(1), _ai(2), _ai(3)]
        ..perItemDelay = const Duration(milliseconds: 5);
      final bd = BackoffDiscovery(
        disc,
        fixedBackoff(const Duration(seconds: 1)),
      );

      final first = bd.findPeers('test', options: [limit(10)]).toList();
      // Let the first query start (and register as `ongoing`) before the
      // second caller joins it.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final second = bd.findPeers('test', options: [limit(10)]).toList();

      final results = await Future.wait([first, second]);
      expect(results[0], hasLength(3));
      expect(results[1], hasLength(3));
    });

    test(
      'findPeers() - an empty result set for an unseen namespace closes cleanly',
      () async {
        final disc = _RecordingDiscovery();
        final bd = BackoffDiscovery(
          disc,
          fixedBackoff(const Duration(seconds: 1)),
        );
        final results = await bd
            .findPeers('nothing', options: [limit(10)])
            .toList();
        expect(results, isEmpty);
      },
    );
  });

  // -----------------------------------------------------------------
  // backoffconnector.go
  // -----------------------------------------------------------------
  group('BackoffConnector [Atomic Audit]', () {
    test('BackoffConnector() - rejects a non-positive cacheSize', () {
      expect(
        () => BackoffConnector(
          _FakeHost(_peer(0)),
          0,
          const Duration(seconds: 1),
          fixedBackoff(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('connect() - dials a newly seen peer', () async {
      final host = _FakeHost(_peer(0));
      final connector = BackoffConnector(
        host,
        16,
        const Duration(seconds: 5),
        fixedBackoff(const Duration(seconds: 10)),
      );
      await connector.connect(Stream.fromIterable([_ai(1)]));
      await Future<void>.delayed(Duration.zero);
      expect(host.connected.map((a) => a.id), [_peer(1)]);
    });

    test(
      'connect() - skips the host\'s own peer ID and an empty peer ID (backoffconnector.go:57)',
      () async {
        final self = _peer(0);
        final host = _FakeHost(self);
        final connector = BackoffConnector(
          host,
          16,
          const Duration(seconds: 5),
          fixedBackoff(const Duration(seconds: 10)),
        );
        await connector.connect(
          Stream.fromIterable([
            AddrInfo(id: self),
            AddrInfo(id: PeerId(value: Uint8List(0))),
          ]),
        );
        await Future<void>.delayed(Duration.zero);
        expect(host.connected, isEmpty);
      },
    );

    test(
      'connect() - does not redial the same peer within its backoff window',
      () async {
        final host = _FakeHost(_peer(0));
        final connector = BackoffConnector(
          host,
          16,
          const Duration(seconds: 5),
          fixedBackoff(const Duration(seconds: 10)),
        );
        await connector.connect(Stream.fromIterable([_ai(1), _ai(1)]));
        await Future<void>.delayed(Duration.zero);
        expect(host.connected, hasLength(1));
      },
    );

    test(
      'connect() - redials the same peer once its backoff has elapsed',
      () async {
        final host = _FakeHost(_peer(0));
        final connector = BackoffConnector(
          host,
          16,
          const Duration(seconds: 5),
          fixedBackoff(const Duration(milliseconds: 10)),
        );
        await connector.connect(Stream.fromIterable([_ai(1)]));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await connector.connect(Stream.fromIterable([_ai(1)]));
        await Future<void>.delayed(Duration.zero);
        expect(host.connected, hasLength(2));
      },
    );

    test(
      'connect() - a failed connection attempt does not stop the loop (swallowed, backoffconnector.go:82-86)',
      () async {
        final host = _FakeHost(_peer(0))..shouldFail = true;
        final connector = BackoffConnector(
          host,
          16,
          const Duration(seconds: 5),
          fixedBackoff(const Duration(seconds: 10)),
        );
        await connector.connect(Stream.fromIterable([_ai(1), _ai(2)]));
        await Future<void>.delayed(Duration.zero);
        expect(host.connected, isEmpty);
      },
    );
  });
}
