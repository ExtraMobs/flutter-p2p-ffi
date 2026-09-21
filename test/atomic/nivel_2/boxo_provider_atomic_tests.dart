import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_boxo/src/provider/noop.dart';
import 'package:transpiled_boxo/src/provider/provider.dart';
import 'package:transpiled_boxo/src/provider/reprovider.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

// Traced through go-ipfs-reference/boxo-index/provider.md and the
// corresponding Go declarations at boxo 25b1db8931508bb069eb6e67243b34d353cbe845
// (go-ipfs-reference/boxo/provider/{provider,reprovider,noop}.go; see
// doc/transpilation/UPSTREAM_LOCK.md). These tests use memory-only
// dependencies (MapDatastore) with injected short intervals so scheduling
// behavior can be verified without waiting on real multi-hour timers.
//
// `reproviderSystem()`/`noopProviderSystem()` return the public `System`
// interface backed by private concrete classes (`_ReproviderSystem`,
// `_NoopProviderSystem`), mirroring boxo's own `New`/`NewNoopProvider`,
// which return the `System` interface backed by unexported structs. The
// two internal scheduling exceptions (thrown when a reprovide is already
// running, or when `online()` is applied twice) are likewise private --
// Go itself never gives either condition a named/sentinel error, just an
// ad hoc `fmt.Errorf`/`errors.New` string -- so they're asserted here by
// their message text rather than by type.

class _CountingProvider implements Provider {
  int calls = 0;
  final List<Cid> providedCids = [];

  @override
  Future<void> provide(Cid cid, bool announce) async {
    calls++;
    providedCids.add(cid);
  }
}

class _FailingProvider implements Provider {
  int calls = 0;

  @override
  Future<void> provide(Cid cid, bool announce) async {
    calls++;
    throw StateError('simulated provide failure');
  }
}

class _GatedProvider implements Provider {
  final Completer<void> gate = Completer<void>();
  int calls = 0;

  @override
  Future<void> provide(Cid cid, bool announce) async {
    calls++;
    await gate.future;
  }
}

void main() {
  late Cid cidA;
  late Cid cidB;

  setUpAll(() async {
    cidA = await Cid.fromContent(Uint8List.fromList([1, 2, 3]));
    cidB = await Cid.fromContent(Uint8List.fromList([4, 5, 6]));
  });

  group('reprovideFirstDelay() [Atomic Audit]', () {
    test(
      'reprovideFirstDelay() - no last reprovide returns the initial delay',
      () {
        final delay = reprovideFirstDelay(
          reprovideInterval: const Duration(hours: 22),
          initialReprovideDelay: const Duration(minutes: 1),
          now: DateTime(2026),
        );
        expect(delay, const Duration(minutes: 1));
      },
    );

    test('reprovideFirstDelay() - recent last reprovide waits out the '
        'remainder of the interval instead of the initial delay', () {
      final now = DateTime(2026, 1, 1, 12);
      final last = now.subtract(const Duration(hours: 1));
      final delay = reprovideFirstDelay(
        reprovideInterval: const Duration(hours: 22),
        initialReprovideDelay: const Duration(minutes: 1),
        now: now,
        lastReprovide: last,
      );
      expect(delay, const Duration(hours: 21));
    });

    test('reprovideFirstDelay() - a last reprovide older than one interval '
        'falls back to the initial delay', () {
      final now = DateTime(2026, 1, 1, 12);
      final last = now.subtract(const Duration(hours: 23));
      final delay = reprovideFirstDelay(
        reprovideInterval: const Duration(hours: 22),
        initialReprovideDelay: const Duration(minutes: 1),
        now: now,
        lastReprovide: last,
      );
      expect(delay, const Duration(minutes: 1));
    });

    test('reprovideFirstDelay() - clamps a negative delay to Duration.zero '
        '(Future.delayed cannot take a negative duration, unlike a Go timer, '
        'which fires immediately)', () {
      final delay = reprovideFirstDelay(
        reprovideInterval: const Duration(hours: 22),
        initialReprovideDelay: const Duration(minutes: -5),
        now: DateTime(2026),
      );
      expect(delay, Duration.zero);
    });
  });

  group('defaultReproviderInterval [Atomic Audit]', () {
    test('defaultReproviderInterval - equals the boxo upstream default of 22h '
        '(reprovider.go:24), not the 12h this project\'s own docs '
        'mistakenly claim', () {
      expect(defaultReproviderInterval, const Duration(hours: 22));
    });
  });

  group('defaultKeyPrefix [Atomic Audit]', () {
    test('defaultKeyPrefix - equals /provider', () {
      expect(defaultKeyPrefix.toString(), '/provider');
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('reproviderSystem() - reproviderInterval(Duration.zero) disables '
        'automatic reprovide scheduling entirely', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(Duration.zero),
          online(counting),
          keyProvider(() => Stream.fromIterable([cidA])),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await system.close();
      expect(counting.calls, 0);
    });

    test('reproviderSystem() - schedules automatic reprovides at the '
        'configured short interval', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(const Duration(milliseconds: 25)),
          online(counting),
          keyProvider(() => Stream.fromIterable([cidA])),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await system.close();
      expect(counting.calls, greaterThanOrEqualTo(2));
    });

    test(
      'reproviderSystem() - close() stops the scheduling loop promptly '
      'even under the default 22h interval, leaving no orphan timer',
      () async {
        final counting = _CountingProvider();
        final system = reproviderSystem(
          MapDatastore(),
          options: [
            online(counting),
            keyProvider(() => Stream.fromIterable([cidA])),
          ],
        );
        final stopwatch = Stopwatch()..start();
        await system.close();
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
        expect(counting.calls, 0);
      },
    );

    test('reproviderSystem() - close() is a clean no-op for an offline '
        'system that never started scheduling', () async {
      final system = reproviderSystem(MapDatastore());
      await system.close();
      expect(system.stat().totalReprovides, 0);
    });

    test('reproviderSystem() - reprovide() throws when a reprovide is '
        'already in progress', () async {
      final gated = _GatedProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(Duration.zero),
          online(gated),
          keyProvider(() => Stream.fromIterable([cidA])),
        ],
      );
      final inFlight = system.reprovide();
      expect(
        () => system.reprovide(),
        throwsA(
          predicate<Object>(
            (e) => e.toString() == 'instance of reprovide already running',
          ),
        ),
      );
      gated.gate.complete();
      await inFlight;
      await system.close();
    });

    test(
      'reproviderSystem() - a mid-cycle provide failure is logged and '
      'stops that run without throwing or attempting the remaining keys',
      () async {
        final failing = _FailingProvider();
        final system = reproviderSystem(
          MapDatastore(),
          options: [
            reproviderInterval(Duration.zero),
            online(failing),
            keyProvider(() => Stream.fromIterable([cidA, cidB])),
          ],
        );
        await system.reprovide();
        expect(failing.calls, 1);
        expect(system.stat().totalReprovides, 0);
        await system.close();
      },
    );

    test('reproviderSystem() - a successful reprovide updates stat() with '
        'the batch size, total count and last-run time', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(Duration.zero),
          online(counting),
          keyProvider(() => Stream.fromIterable([cidA, cidB])),
        ],
      );
      await system.reprovide();
      final stats = system.stat();
      expect(stats.totalReprovides, 2);
      expect(stats.lastReprovideBatchSize, 2);
      expect(stats.lastRun, isNotNull);
      await system.close();
    });

    test('reproviderSystem() - reprovide() on an empty key stream is a '
        'no-op that does not touch stat()', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(Duration.zero),
          online(counting),
          keyProvider(() => const Stream.empty()),
        ],
      );
      await system.reprovide();
      expect(counting.calls, 0);
      expect(system.stat().totalReprovides, 0);
      await system.close();
    });

    test('reproviderSystem() - provide() delegates straight to the online '
        'provider', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [reproviderInterval(Duration.zero), online(counting)],
      );
      await system.provide(cidA, true);
      expect(counting.calls, 1);
      expect(counting.providedCids, [cidA]);
      await system.close();
    });

    test('reproviderSystem() - provide() throws StateError when the system '
        'has no online provider', () {
      final system = reproviderSystem(MapDatastore());
      expect(() => system.provide(cidA, true), throwsStateError);
    });

    test('reproviderSystem() - clear() always returns 0 (no persisted '
        'provide queue is ported)', () {
      final system = reproviderSystem(MapDatastore());
      expect(system.clear(), 0);
    });

    test('reproviderSystem() - stat() reflects the interval, batch size and '
        'total count after a successful reprovide', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(const Duration(minutes: 3)),
          online(counting),
          keyProvider(() => Stream.fromIterable([cidA])),
        ],
      );
      await system.reprovide();
      final stats = system.stat();
      expect(stats.reprovideInterval, const Duration(minutes: 3));
      expect(stats.totalReprovides, 1);
      expect(stats.lastReprovideBatchSize, 1);
      await system.close();
    });

    test('noopProviderSystem() - returns a System that does nothing and '
        'never records a reprovide', () async {
      final system = noopProviderSystem();
      await system.provide(cidA, true);
      await system.reprovide();
      expect(system.clear(), 0);
      expect(system.stat().totalReprovides, 0);
      await system.close();
    });

    test('reproviderInterval() - option sets the interval reflected in '
        'stat()', () {
      final system = reproviderSystem(
        MapDatastore(),
        options: [reproviderInterval(const Duration(minutes: 7))],
      );
      expect(system.stat().reprovideInterval, const Duration(minutes: 7));
    });

    test(
      'keyProvider() - option supplies the keys used by reprovide()',
      () async {
        final counting = _CountingProvider();
        final system = reproviderSystem(
          MapDatastore(),
          options: [
            reproviderInterval(Duration.zero),
            online(counting),
            keyProvider(() => Stream.fromIterable([cidA])),
          ],
        );
        await system.reprovide();
        expect(counting.calls, 1);
        await system.close();
      },
    );

    test('datastorePrefix() - option changes where the last-reprovide time '
        'is persisted', () async {
      final ds = MapDatastore();
      final prefix = Key('/top-level-prefix-test');
      final counting = _CountingProvider();
      final system = reproviderSystem(
        ds,
        options: [
          reproviderInterval(Duration.zero),
          datastorePrefix(prefix),
          online(counting),
          keyProvider(() => Stream.fromIterable([cidA])),
        ],
      );
      await system.reprovide();
      expect(await ds.has(Key('$prefix/reprovide/lastreprovide')), isTrue);
      await system.close();
    });

    test(
      'online() - option binds the Provider a reproviderSystem() calls',
      () async {
        final counting = _CountingProvider();
        final system = reproviderSystem(
          MapDatastore(),
          options: [reproviderInterval(Duration.zero), online(counting)],
        );
        await system.provide(cidA, true);
        expect(counting.calls, 1);
        await system.close();
      },
    );

    test(
      'online() - throws when applied twice on the same reproviderSystem()',
      () {
        final counting = _CountingProvider();
        expect(
          () => reproviderSystem(
            MapDatastore(),
            options: [online(counting), online(counting)],
          ),
          throwsA(
            predicate<Object>(
              (e) =>
                  e.toString() ==
                  'trying to register two providers on the same reprovider',
            ),
          ),
        );
      },
    );

    test('setKeyProvider() - replaces the key provider used by later '
        'reprovide() runs', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(Duration.zero),
          online(counting),
          keyProvider(() => const Stream.empty()),
        ],
      );
      system.setKeyProvider(() => Stream.fromIterable([cidA, cidB]));
      await system.reprovide();
      expect(counting.calls, 2);
      await system.close();
    });
  });

  group('Provider [Atomic Audit]', () {
    test('provide(cid, announce) - dispatched polymorphically through the '
        'Provider interface', () async {
      final counting = _CountingProvider();
      final Provider provider = counting;
      await provider.provide(cidA, true);
      expect(counting.calls, 1);
      expect(counting.providedCids, [cidA]);
    });
  });

  group('Reprovider [Atomic Audit]', () {
    test('reprovide() - dispatched polymorphically through the Reprovider '
        'interface', () async {
      final counting = _CountingProvider();
      final system = reproviderSystem(
        MapDatastore(),
        options: [
          reproviderInterval(Duration.zero),
          online(counting),
          keyProvider(() => Stream.fromIterable([cidA])),
        ],
      );
      final Reprovider reprovider = system;
      await reprovider.reprovide();
      expect(counting.calls, 1);
      await system.close();
    });
  });

  group('System [Atomic Audit]', () {
    test(
      'clear() - dispatched polymorphically through the System interface',
      () {
        final System system = reproviderSystem(MapDatastore());
        expect(system.clear(), 0);
      },
    );

    test(
      'close() - dispatched polymorphically through the System interface',
      () async {
        final System system = reproviderSystem(MapDatastore());
        await system.close();
        expect(system.stat().totalReprovides, 0);
      },
    );

    test(
      'stat() - dispatched polymorphically through the System interface',
      () {
        final System system = reproviderSystem(MapDatastore());
        expect(system.stat().totalReprovides, 0);
      },
    );

    test('setKeyProvider(kp) - dispatched polymorphically through the '
        'System interface', () async {
      final counting = _CountingProvider();
      final concrete = reproviderSystem(
        MapDatastore(),
        options: [reproviderInterval(Duration.zero), online(counting)],
      );
      final System system = concrete;
      system.setKeyProvider(() => Stream.fromIterable([cidA]));
      await concrete.reprovide();
      expect(counting.calls, 1);
      await concrete.close();
    });
  });

  group('ReproviderStats [Atomic Audit]', () {
    test('totalReprovides/lastReprovideBatchSize/lastRun - all-zero, '
        'never-run snapshot before any reprovide', () {
      final stats = noopProviderSystem().stat();
      expect(stats.totalReprovides, 0);
      expect(stats.lastReprovideBatchSize, 0);
      expect(stats.avgReprovideDuration, Duration.zero);
      expect(stats.lastReprovideDuration, Duration.zero);
      expect(stats.lastRun, isNull);
    });
  });

  group('NoopProviderSystem [Atomic Audit]', () {
    test('provide() - does nothing and completes without throwing', () async {
      await expectLater(noopProviderSystem().provide(cidA, true), completes);
    });

    test('reprovide() - does nothing and completes without throwing', () async {
      await expectLater(noopProviderSystem().reprovide(), completes);
    });

    test('clear() - returns 0', () {
      expect(noopProviderSystem().clear(), 0);
    });

    test('close() - does nothing and completes without throwing', () async {
      await expectLater(noopProviderSystem().close(), completes);
    });

    test('stat() - returns an all-zero, never-run snapshot', () {
      final stats = noopProviderSystem().stat();
      expect(stats.totalReprovides, 0);
      expect(stats.lastReprovideBatchSize, 0);
      expect(stats.lastRun, isNull);
    });

    test('setKeyProvider() - accepts a provider without throwing', () {
      expect(
        () => noopProviderSystem().setKeyProvider(() => const Stream.empty()),
        returnsNormally,
      );
    });
  });
}
