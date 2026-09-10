// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

class _Router implements Routing {
  _Router({
    this.values = const {},
    this.delay = Duration.zero,
    this.providers = const [],
  });
  final Map<String, String> values;
  final Duration delay;
  final List<PeerId> providers;
  @override
  Future<void> bootstrap() async {}
  @override
  Future<AddrInfo> findPeer(PeerId id) async =>
      throw const RoutingNotFoundException();
  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) async* {
    for (final id in providers.take(count == 0 ? providers.length : count)) {
      yield AddrInfo(id: id, addrs: const []);
    }
  }

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    await Future<void>.delayed(delay);
    final value = values[key];
    if (value == null) throw const RoutingNotFoundException();
    return Uint8List.fromList(value.codeUnits);
  }

  @override
  Future<void> provide(Cid cid, bool local) async {}
  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {}
  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async* {
    try {
      yield await getValue(key, options: options);
    } on RoutingNotFoundException {
      // SearchValue maps not-found to an empty stream.
    }
  }
}

void main() {
  test(
    'Parallel takes the first value and Tiered takes the first router',
    () async {
      final slow = _Router(
        values: {'key': 'slow'},
        delay: const Duration(milliseconds: 20),
      );
      final fast = _Router(values: {'key': 'fast'});
      expect(
        String.fromCharCodes(
          await Parallel(routers: [slow, fast]).getValue('key'),
        ),
        'fast',
      );
      expect(
        String.fromCharCodes(
          await Tiered(routers: [slow, fast]).getValue('key'),
        ),
        'slow',
      );
    },
  );

  test('Parallel provider lookup deduplicates and honors count', () async {
    final one = PeerId(value: Uint8List.fromList([1]));
    final two = PeerId(value: Uint8List.fromList([2]));
    final cid = Cid.computeForDataSync(Uint8List(0));
    final found = await Parallel(
      routers: [
        _Router(providers: [one, two]),
        _Router(providers: [one]),
      ],
    ).findProvidersAsync(cid, 2).toList();
    expect(found.map((info) => info.id).toSet(), {one, two});
  });

  test(
    'Composable routers honor ignoreError and delayed parallel fallback',
    () async {
      final ignored = _FailingRouter();
      final value = _Router(values: {'key': 'ok'});
      final parallel = ComposableParallel([
        ParallelRouter(router: ignored, ignoreError: true),
        ParallelRouter(
          router: value,
          executeAfter: const Duration(milliseconds: 1),
        ),
      ]);
      expect(String.fromCharCodes(await parallel.getValue('key')), 'ok');
      final sequential = ComposableSequential([
        SequentialRouter(router: ignored, ignoreError: true),
        SequentialRouter(router: value),
      ]);
      expect(String.fromCharCodes(await sequential.getValue('key')), 'ok');
    },
  );

  test('Parallel merges query events for value and provider streams', () async {
    final peer = PeerId(value: Uint8List.fromList([7]));
    final cid = Cid.computeForDataSync(Uint8List(0));
    final registration = registerForQueryEvents();
    final events = registration.events.toList();

    await registration.run(() async {
      final values = await Parallel(
        routers: [
          _EventRouter(eventType: queryError),
          _EventRouter(eventType: value, valueText: 'ok'),
        ],
      ).searchValue('key').toList();
      expect(values.map(String.fromCharCodes), ['ok']);

      final providers = await Parallel(
        routers: [
          _EventRouter(eventType: queryError),
          _EventRouter(eventType: provider, providers: [peer]),
        ],
      ).findProvidersAsync(cid, 1).toList();
      expect(providers.single.id, peer);
    });

    await registration.close();
    expect((await events).map((event) => event.type), [value, provider]);
  });

  test('Parallel merges query events for Future reads', () async {
    final registration = registerForQueryEvents();
    final events = registration.events.toList();
    final found = await registration.run(
      () => Parallel(
        routers: [
          _EventRouter(eventType: queryError),
          _EventRouter(eventType: value, valueText: 'ok'),
        ],
      ).getValue('key'),
    );
    expect(String.fromCharCodes(found), 'ok');
    await registration.close();
    expect((await events).map((event) => event.type), [value]);
  });

  test('Parallel public-key lookup filters by key support', () async {
    final key = _PublicKey();
    final store = _PublicKeyStore(key);
    final peer = PeerId(
      value: Uint8List.fromList([0x12, 0x20, ...List.filled(32, 0)]),
    );
    expect(
      await Parallel(routers: [Compose(valueStore: store)]).getPublicKey(peer),
      same(key),
    );
  });

  test('Parallel publishes one query error when every stream fails', () async {
    final registration = registerForQueryEvents();
    final events = registration.events.toList();
    await registration.run(
      () => Parallel(
        routers: [
          _EventRouter(eventType: queryError),
          _EventRouter(eventType: queryError),
        ],
      ).searchValue('key').drain<void>(),
    );
    await registration.close();
    expect((await events).map((event) => event.type), [queryError]);
  });

  test('Parallel search closes after a productive router completes', () async {
    final stalled = StreamController<Uint8List>();
    var cancelled = false;
    stalled.onCancel = () => cancelled = true;
    final values = await Parallel(
      routers: [
        _StreamRouter(stalled.stream),
        _Router(values: {'key': 'ok'}),
      ],
    ).searchValue('key').toList();
    expect(values.map(String.fromCharCodes), ['ok']);
    expect(cancelled, isTrue);
  });

  test(
    'Parallel search keeps empty duplicates and skips selector errors',
    () async {
      final emptyValues = await Parallel(
        routers: [
          _SequenceRouter([Uint8List(0), Uint8List(0)]),
        ],
        validator: const _Validator(),
      ).searchValue('key').toList();
      expect(emptyValues, hasLength(2));

      final selected = await Parallel(
        routers: [
          _SequenceRouter([
            Uint8List.fromList([1]),
            Uint8List.fromList([2]),
          ]),
        ],
        validator: const _Validator(throwOnSelect: true),
      ).searchValue('key').toList();
      expect(selected, [
        Uint8List.fromList([1]),
      ]);
    },
  );

  test('Composable fallbacks skip empty values', () async {
    final empty = _Router(values: {'key': ''});
    final found = _Router(
      values: {'key': 'ok'},
      delay: const Duration(milliseconds: 5),
    );
    expect(
      String.fromCharCodes(
        await ComposableParallel([
          ParallelRouter(router: empty),
          ParallelRouter(router: found),
        ]).getValue('key'),
      ),
      'ok',
    );
    expect(
      String.fromCharCodes(
        await ComposableSequential([
          SequentialRouter(router: empty),
          SequentialRouter(router: found),
        ]).getValue('key'),
      ),
      'ok',
    );
  });

  test(
    'Composable provider lookup preserves duplicates like upstream',
    () async {
      final peer = PeerId(value: Uint8List.fromList([9]));
      final cid = Cid.computeForDataSync(Uint8List(0));
      final found = await ComposableParallel([
        ParallelRouter(router: _Router(providers: [peer])),
        ParallelRouter(router: _Router(providers: [peer])),
      ]).findProvidersAsync(cid, 0).toList();
      expect(found.map((info) => info.id), [peer, peer]);
    },
  );

  test(
    'Composable stream timeout advances and non-blocking search cancels',
    () async {
      final stalledSequential = StreamController<Uint8List>();
      final sequential = await ComposableSequential([
        SequentialRouter(
          router: _StreamRouter(stalledSequential.stream),
          timeout: const Duration(milliseconds: 10),
        ),
        SequentialRouter(router: _Router(values: {'key': 'next'})),
      ]).searchValue('key').toList();
      expect(sequential.map(String.fromCharCodes), ['next']);

      final stalledParallel = StreamController<Uint8List>();
      var cancelled = false;
      stalledParallel.onCancel = () => cancelled = true;
      final parallel = await ComposableParallel([
        ParallelRouter(router: _Router(values: {'key': 'done'})),
        ParallelRouter(
          router: _StreamRouter(stalledParallel.stream),
          doNotWaitForSearchValue: true,
        ),
      ]).searchValue('key').toList();
      expect(parallel.map(String.fromCharCodes), ['done']);
      expect(cancelled, isTrue);
    },
  );

  test('Composable stream errors follow upstream fallback rules', () async {
    final failure = _StreamRouter(Stream.error(StateError('fail')));
    final valueRouter = _Router(values: {'key': 'ok'});
    final parallel = await ComposableParallel([
      ParallelRouter(router: failure),
      ParallelRouter(router: valueRouter),
    ]).searchValue('key').toList();
    expect(parallel.map(String.fromCharCodes), ['ok']);

    await expectLater(
      ComposableParallel([ParallelRouter(router: failure)]).searchValue('key'),
      emitsError(isA<StateError>()),
    );

    final sequential = await ComposableSequential([
      SequentialRouter(router: failure),
      SequentialRouter(router: valueRouter),
    ]).searchValue('key').toList();
    expect(sequential, isEmpty);
  });

  test('ProvideMany uses batch support and raw-Cid fallback', () async {
    final keys = [
      MultihashUtils.sum('sha2-256', Uint8List.fromList([1])),
      MultihashUtils.sum('sha2-256', Uint8List.fromList([2])),
    ];
    final batched = _BatchRouter();
    final fallback = _ProvidingRouter();
    await ComposableParallel([
      ParallelRouter(router: batched),
      ParallelRouter(router: fallback),
    ]).provideMany(keys);
    expect(batched.batches.single, keys);
    expect(fallback.provided, hasLength(2));
    expect(fallback.provided.every((cid) => cid.codec == 'raw'), isTrue);

    final sequentialBatch = _BatchRouter();
    await ComposableSequential([
      SequentialRouter(router: sequentialBatch),
    ]).provideMany(keys);
    expect(sequentialBatch.batches.single, keys);
  });
}

class _FailingRouter extends _Router {
  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async => throw StateError('fail');
}

class _EventRouter extends _Router {
  _EventRouter({required this.eventType, this.valueText, super.providers});

  final QueryEventType eventType;
  final String? valueText;

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    publishQueryEvent(QueryEvent(type: eventType));
    final text = valueText;
    if (text == null) throw const RoutingNotFoundException();
    return Uint8List.fromList(text.codeUnits);
  }

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async* {
    publishQueryEvent(QueryEvent(type: eventType));
    if (valueText != null) yield Uint8List.fromList(valueText!.codeUnits);
  }

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) async* {
    publishQueryEvent(QueryEvent(type: eventType));
    yield* super.findProvidersAsync(cid, count);
  }
}

class _StreamRouter extends _Router {
  _StreamRouter(this.stream);

  final Stream<Uint8List> stream;

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => stream;
}

class _SequenceRouter extends _Router {
  _SequenceRouter(this.sequence);

  final List<Uint8List> sequence;

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => Stream.fromIterable(sequence);
}

class _Validator implements Validator {
  const _Validator({this.throwOnSelect = false});

  final bool throwOnSelect;

  @override
  int select(String key, List<Uint8List> values) {
    if (throwOnSelect) throw StateError('invalid candidate');
    return 1;
  }

  @override
  void validate(String key, Uint8List value) {}
}

class _PublicKey extends PubKey {
  @override
  KeyType get type => KeyType.ed25519;

  @override
  Uint8List raw() => Uint8List(32);

  @override
  Future<bool> verify(Uint8List data, Uint8List signature) async => true;
}

class _PublicKeyStore implements ValueStore, PubKeyFetcher {
  _PublicKeyStore(this.key);

  final PubKey key;

  @override
  Future<PubKey> getPublicKey(PeerId id) async => key;

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async => throw const RoutingNotFoundException();

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {}

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => const Stream.empty();
}

class _BatchRouter extends _Router implements ProvideManyRouter {
  final List<List<DecodedMultihash>> batches = [];

  @override
  Future<void> provideMany(List<DecodedMultihash> keys) async {
    batches.add(keys);
  }
}

class _ProvidingRouter extends _Router {
  final List<Cid> provided = [];

  @override
  Future<void> provide(Cid cid, bool local) async {
    expect(local, isTrue);
    provided.add(cid);
  }
}
