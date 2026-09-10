// test/atomic/nivel_2/routing_helpers_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo transpiled_libp2p_routing_helpers (Nivel 2)

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

class _TestBootstrap implements Bootstrap {
  bool bootstrapped = false;
  @override
  Future<void> bootstrap() async {
    bootstrapped = true;
  }
}

class _TestProvideManyRouter implements ProvideManyRouter {
  final List<DecodedMultihash> provided = [];
  @override
  Future<void> provideMany(List<DecodedMultihash> keys) async {
    provided.addAll(keys);
  }
}

class _TestReadyAbleRouter implements ReadyAbleRouter {
  _TestReadyAbleRouter({this.isReady = true});
  final bool isReady;
  @override
  bool ready() => isReady;
}

class _TestComposableRouter implements ComposableRouter {
  _TestComposableRouter(this.nested);
  final List<Routing> nested;
  @override
  List<Routing> routers() => nested;
}

class _TestClosable implements Closable {
  bool closed = false;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class _TestPubKey extends PubKey {
  @override
  KeyType get type => KeyType.ed25519;
  @override
  Uint8List raw() => Uint8List(32);
  @override
  Future<bool> verify(Uint8List data, Uint8List signature) async => true;
}

class _MemoryRouter
    implements
        Routing,
        Bootstrap,
        Closable,
        ReadyAbleRouter,
        ProvideManyRouter,
        PubKeyFetcher {
  _MemoryRouter({
    Map<String, Uint8List>? initialValues,
    List<PeerId>? initialProviders,
    Map<PeerId, AddrInfo>? initialPeers,
    this.pubKey,
    this.isReady = true,
  }) {
    if (initialValues != null) _values.addAll(initialValues);
    if (initialProviders != null) _providers.addAll(initialProviders);
    if (initialPeers != null) _peers.addAll(initialPeers);
  }

  final Map<String, Uint8List> _values = {};
  final List<PeerId> _providers = [];
  final Map<PeerId, AddrInfo> _peers = {};
  final List<Cid> providedCids = [];
  final List<DecodedMultihash> providedKeys = [];
  final PubKey? pubKey;
  final bool isReady;

  int bootstrapCalls = 0;
  int closeCalls = 0;
  int putValueCalls = 0;

  @override
  bool ready() => isReady;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls++;
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }

  @override
  Future<void> provideMany(List<DecodedMultihash> keys) async {
    providedKeys.addAll(keys);
  }

  @override
  Future<void> provide(Cid cid, bool local) async {
    providedCids.add(cid);
  }

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {
    putValueCalls++;
    _values[key] = value;
  }

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    final val = _values[key];
    if (val == null) throw const RoutingNotFoundException();
    return val;
  }

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async* {
    final val = _values[key];
    if (val != null) yield val;
  }

  @override
  Future<AddrInfo> findPeer(PeerId id) async {
    final info = _peers[id];
    if (info == null) throw const RoutingNotFoundException();
    return info;
  }

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) async* {
    final limit = count <= 0 ? _providers.length : count;
    for (final id in _providers.take(limit)) {
      yield AddrInfo(id: id, addrs: const []);
    }
  }

  @override
  Future<PubKey> getPublicKey(PeerId id) async {
    final key = pubKey;
    if (key != null) return key;
    throw const RoutingNotFoundException();
  }
}

class _TestValidator implements Validator {
  const _TestValidator();
  @override
  int select(String key, List<Uint8List> values) => values.length - 1;
  @override
  void validate(String key, Uint8List value) {}
}

void main() {
  final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
  final sampleCid = Cid.computeForDataSync(sampleBytes);
  final sampleMultihash = MultihashUtils.sum('sha2-256', sampleBytes);
  final samplePeerId = PeerId(value: sampleBytes);
  final sampleAddrInfo = AddrInfo(id: samplePeerId, addrs: const []);

  group('Bootstrap [Atomic Audit]', () {
    test('bootstrap() - executa operacao de inicializacao da interface', () async {
      final b = _TestBootstrap();
      expect(b.bootstrapped, isFalse);
      await b.bootstrap();
      expect(b.bootstrapped, isTrue);
    });
  });

  group('ProvideManyRouter [Atomic Audit]', () {
    test('provideMany() - anuncia lista de multihashes em lote na interface', () async {
      final pm = _TestProvideManyRouter();
      await pm.provideMany([sampleMultihash]);
      expect(pm.provided, equals([sampleMultihash]));
    });
  });

  group('ReadyAbleRouter [Atomic Audit]', () {
    test('ready() - verifica se o roteador esta pronto para receber requisicoes', () {
      final readyRouter = _TestReadyAbleRouter(isReady: true);
      final unreadyRouter = _TestReadyAbleRouter(isReady: false);
      expect(readyRouter.ready(), isTrue);
      expect(unreadyRouter.ready(), isFalse);
    });
  });

  group('ComposableRouter [Atomic Audit]', () {
    test('routers() - retorna lista de roteadores aninhados da interface', () {
      final r1 = _MemoryRouter();
      final cr = _TestComposableRouter([r1]);
      expect(cr.routers(), equals([r1]));
    });
  });

  group('ComposableParallel [Atomic Audit]', () {
    test('routers() - expoem lista de roteadores configurados', () {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cp = ComposableParallel([
        ParallelRouter(router: r1),
        ParallelRouter(router: r2),
      ]);
      expect(cp.routers(), equals([r1, r2]));
    });

    test('ready() - verifica se todos os roteadores aninhados estao prontos', () {
      final readyRouter = _MemoryRouter(isReady: true);
      final unreadyRouter = _MemoryRouter(isReady: false);
      final allReady = ComposableParallel([
        ParallelRouter(router: readyRouter),
      ]);
      final notAllReady = ComposableParallel([
        ParallelRouter(router: readyRouter),
        ParallelRouter(router: unreadyRouter),
      ]);
      expect(allReady.ready(), isTrue);
      expect(notAllReady.ready(), isFalse);
    });

    test('provide() - anuncia conteudo para todos os roteadores concorrentemente', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cp = ComposableParallel([
        ParallelRouter(router: r1),
        ParallelRouter(router: r2),
      ]);
      await cp.provide(sampleCid, true);
      expect(r1.providedCids, contains(sampleCid));
      expect(r2.providedCids, contains(sampleCid));
    });

    test('provideMany() - anuncia chaves em lote ou por fallback raw cid', () async {
      final r1 = _MemoryRouter();
      final cp = ComposableParallel([ParallelRouter(router: r1)]);
      await cp.provideMany([sampleMultihash]);
      expect(r1.providedKeys, contains(sampleMultihash));
    });

    test('putValue() - armazena valor em todos os roteadores concorrentemente', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cp = ComposableParallel([
        ParallelRouter(router: r1),
        ParallelRouter(router: r2),
      ]);
      await cp.putValue('/ipns/key', sampleBytes);
      expect(r1.putValueCalls, equals(1));
      expect(r2.putValueCalls, equals(1));
    });

    test('getValue() - recupera o primeiro valor retornado entre os roteadores', () async {
      final r1 = _MemoryRouter(initialValues: {'/test/val': sampleBytes});
      final r2 = _MemoryRouter();
      final cp = ComposableParallel([
        ParallelRouter(router: r1),
        ParallelRouter(router: r2),
      ]);
      final val = await cp.getValue('/test/val');
      expect(val, equals(sampleBytes));
    });

    test('findPeer() - localiza endereco do par a partir do primeiro roteador que responder', () async {
      final r1 = _MemoryRouter(initialPeers: {samplePeerId: sampleAddrInfo});
      final cp = ComposableParallel([ParallelRouter(router: r1)]);
      final info = await cp.findPeer(samplePeerId);
      expect(info.id, equals(samplePeerId));
    });

    test('bootstrap() - inicializa todos os roteadores concorrentemente', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cp = ComposableParallel([
        ParallelRouter(router: r1),
        ParallelRouter(router: r2),
      ]);
      await cp.bootstrap();
      expect(r1.bootstrapCalls, equals(1));
      expect(r2.bootstrapCalls, equals(1));
    });

    test('searchValue() - retorna stream unificada de valores emitidos pelos roteadores', () async {
      final r1 = _MemoryRouter(initialValues: {'/test/key': sampleBytes});
      final cp = ComposableParallel([ParallelRouter(router: r1)]);
      final results = await cp.searchValue('/test/key').toList();
      expect(results, contains(sampleBytes));
    });

    test('findProvidersAsync() - retorna stream unificada de provedores ate o limite solicitado', () async {
      final r1 = _MemoryRouter(initialProviders: [samplePeerId]);
      final cp = ComposableParallel([ParallelRouter(router: r1)]);
      final list = await cp.findProvidersAsync(sampleCid, 1).toList();
      expect(list.map((info) => info.id), contains(samplePeerId));
    });
  });

  group('ComposableSequential [Atomic Audit]', () {
    test('routers() - expoem lista de roteadores configurados na ordem', () {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cs = ComposableSequential([
        SequentialRouter(router: r1),
        SequentialRouter(router: r2),
      ]);
      expect(cs.routers(), equals([r1, r2]));
    });

    test('ready() - verifica se todos os roteadores configurados estao prontos', () {
      final rReady = _MemoryRouter(isReady: true);
      final rUnready = _MemoryRouter(isReady: false);
      final allReady = ComposableSequential([SequentialRouter(router: rReady)]);
      final notReady = ComposableSequential([
        SequentialRouter(router: rReady),
        SequentialRouter(router: rUnready),
      ]);
      expect(allReady.ready(), isTrue);
      expect(notReady.ready(), isFalse);
    });

    test('provide() - propaga anuncio de conteudo sequencialmente pelos roteadores', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cs = ComposableSequential([
        SequentialRouter(router: r1),
        SequentialRouter(router: r2),
      ]);
      await cs.provide(sampleCid, true);
      expect(r1.providedCids, contains(sampleCid));
      expect(r2.providedCids, contains(sampleCid));
    });

    test('provideMany() - executa anuncio em lote sequencialmente pelos roteadores', () async {
      final r1 = _MemoryRouter();
      final cs = ComposableSequential([SequentialRouter(router: r1)]);
      await cs.provideMany([sampleMultihash]);
      expect(r1.providedKeys, contains(sampleMultihash));
    });

    test('putValue() - grava valor sequencialmente em todos os roteadores', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cs = ComposableSequential([
        SequentialRouter(router: r1),
        SequentialRouter(router: r2),
      ]);
      await cs.putValue('/seq/key', sampleBytes);
      expect(r1.putValueCalls, equals(1));
      expect(r2.putValueCalls, equals(1));
    });

    test('getValue() - busca valor sequencialmente retornando o primeiro encontrado', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter(initialValues: {'/seq/key': sampleBytes});
      final cs = ComposableSequential([
        SequentialRouter(router: r1),
        SequentialRouter(router: r2),
      ]);
      final val = await cs.getValue('/seq/key');
      expect(val, equals(sampleBytes));
    });

    test('findPeer() - busca informacoes de endereco do par sequencialmente', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter(initialPeers: {samplePeerId: sampleAddrInfo});
      final cs = ComposableSequential([
        SequentialRouter(router: r1),
        SequentialRouter(router: r2),
      ]);
      final info = await cs.findPeer(samplePeerId);
      expect(info.id, equals(samplePeerId));
    });

    test('bootstrap() - executa bootstrap sequencialmente em todos os roteadores', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final cs = ComposableSequential([
        SequentialRouter(router: r1),
        SequentialRouter(router: r2),
      ]);
      await cs.bootstrap();
      expect(r1.bootstrapCalls, equals(1));
      expect(r2.bootstrapCalls, equals(1));
    });

    test('searchValue() - emite valores encontrados na sequencia dos roteadores', () async {
      final r1 = _MemoryRouter(initialValues: {'/k': sampleBytes});
      final cs = ComposableSequential([SequentialRouter(router: r1)]);
      final list = await cs.searchValue('/k').toList();
      expect(list, contains(sampleBytes));
    });

    test('findProvidersAsync() - emite provedores na ordem de execucao dos roteadores', () async {
      final r1 = _MemoryRouter(initialProviders: [samplePeerId]);
      final cs = ComposableSequential([SequentialRouter(router: r1)]);
      final list = await cs.findProvidersAsync(sampleCid, 1).toList();
      expect(list.map((info) => info.id), contains(samplePeerId));
    });
  });

  group('Compose [Atomic Audit]', () {
    test('putValue() - grava valor no valueStore ou lanca excecao quando ausente', () async {
      final emptyCompose = Compose();
      expect(
        () => emptyCompose.putValue('/k', sampleBytes),
        throwsA(isA<RoutingNotSupportedException>()),
      );

      final store = _MemoryRouter();
      final compose = Compose(valueStore: store);
      await compose.putValue('/k', sampleBytes);
      expect(store.putValueCalls, equals(1));
    });

    test('getValue() - le valor do valueStore ou lanca excecao quando ausente', () async {
      final emptyCompose = Compose();
      expect(
        () => emptyCompose.getValue('/k'),
        throwsA(isA<RoutingNotFoundException>()),
      );

      final store = _MemoryRouter(initialValues: {'/k': sampleBytes});
      final compose = Compose(valueStore: store);
      final got = await compose.getValue('/k');
      expect(got, equals(sampleBytes));
    });

    test('searchValue() - emite stream do valueStore ou stream vazia quando ausente', () async {
      final emptyCompose = Compose();
      expect(await emptyCompose.searchValue('/k').toList(), isEmpty);

      final store = _MemoryRouter(initialValues: {'/k': sampleBytes});
      final compose = Compose(valueStore: store);
      expect(await compose.searchValue('/k').toList(), contains(sampleBytes));
    });

    test('provide() - anuncia conteudo via contentRouting ou lanca excecao quando ausente', () async {
      final emptyCompose = Compose();
      expect(
        () => emptyCompose.provide(sampleCid, true),
        throwsA(isA<RoutingNotSupportedException>()),
      );

      final contentRouter = _MemoryRouter();
      final compose = Compose(contentRouting: contentRouter);
      await compose.provide(sampleCid, true);
      expect(contentRouter.providedCids, contains(sampleCid));
    });

    test('findProvidersAsync() - busca provedores via contentRouting ou retorna stream vazia', () async {
      final emptyCompose = Compose();
      expect(await emptyCompose.findProvidersAsync(sampleCid, 1).toList(), isEmpty);

      final contentRouter = _MemoryRouter(initialProviders: [samplePeerId]);
      final compose = Compose(contentRouting: contentRouter);
      final results = await compose.findProvidersAsync(sampleCid, 1).toList();
      expect(results.map((info) => info.id), contains(samplePeerId));
    });

    test('findPeer() - localiza par via peerRouting ou lanca excecao quando ausente', () async {
      final emptyCompose = Compose();
      expect(
        () => emptyCompose.findPeer(samplePeerId),
        throwsA(isA<RoutingNotFoundException>()),
      );

      final peerRouter = _MemoryRouter(initialPeers: {samplePeerId: sampleAddrInfo});
      final compose = Compose(peerRouting: peerRouter);
      final found = await compose.findPeer(samplePeerId);
      expect(found.id, equals(samplePeerId));
    });

    test('getPublicKey() - extrai chave publica do par ou lanca excecao quando ausente', () async {
      final emptyCompose = Compose();
      expect(
        () => emptyCompose.getPublicKey(samplePeerId),
        throwsA(isA<RoutingNotFoundException>()),
      );

      final pk = _TestPubKey();
      final store = _MemoryRouter(pubKey: pk);
      final compose = Compose(valueStore: store);
      final got = await compose.getPublicKey(samplePeerId);
      expect(got, equals(pk));
    });

    test('bootstrap() - inicializa componentes distintos que implementam bootstrap', () async {
      final store = _MemoryRouter();
      final compose = Compose(
        valueStore: store,
        contentRouting: store,
        peerRouting: store,
      );
      await compose.bootstrap();
      expect(store.bootstrapCalls, equals(1));
    });
  });

  group('LimitedValueStore [Atomic Audit]', () {
    test('keySupported() - valida se o prefixo da chave pertence a lista de namespaces suportados', () {
      final store = _MemoryRouter();
      final lvs = LimitedValueStore(valueStore: store, namespaces: ['pk', 'allow']);
      expect(lvs.keySupported('/allow/hello'), isTrue);
      expect(lvs.keySupported('/pk/abc'), isTrue);
      expect(lvs.keySupported('/deny/hello'), isFalse);
      expect(lvs.keySupported('invalid'), isFalse);
      expect(lvs.keySupported('/'), isFalse);
    });

    test('getPublicKey() - resolve chave publica quando namespace pk e suportado', () async {
      final pk = _TestPubKey();
      final store = _MemoryRouter(pubKey: pk);
      final lvsWithPk = LimitedValueStore(valueStore: store, namespaces: ['pk']);
      final got = await lvsWithPk.getPublicKey(samplePeerId);
      expect(got, equals(pk));

      final lvsNoPk = LimitedValueStore(valueStore: store, namespaces: ['other']);
      expect(
        () => lvsNoPk.getPublicKey(samplePeerId),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test('putValue() - delega gravacao quando namespace e valido e rejeita namespace nao suportado', () async {
      final store = _MemoryRouter();
      final lvs = LimitedValueStore(valueStore: store, namespaces: ['allowed']);
      await lvs.putValue('/allowed/test', sampleBytes);
      expect(store.putValueCalls, equals(1));

      expect(
        () => lvs.putValue('/denied/test', sampleBytes),
        throwsA(isA<RoutingNotSupportedException>()),
      );
    });

    test('getValue() - delega leitura para namespace valido e rejeita para namespace invalido', () async {
      final store = _MemoryRouter(initialValues: {'/ns/key': sampleBytes});
      final lvs = LimitedValueStore(valueStore: store, namespaces: ['ns']);
      final got = await lvs.getValue('/ns/key');
      expect(got, equals(sampleBytes));

      expect(
        () => lvs.getValue('/other/key'),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test('searchValue() - emite stream de busca para namespace valido e vazia para invalido', () async {
      final store = _MemoryRouter(initialValues: {'/ns/key': sampleBytes});
      final lvs = LimitedValueStore(valueStore: store, namespaces: ['ns']);
      final items = await lvs.searchValue('/ns/key').toList();
      expect(items, contains(sampleBytes));

      final emptyItems = await lvs.searchValue('/denied/key').toList();
      expect(emptyItems, isEmpty);
    });

    test('bootstrap() - delega bootstrap para o store subjacente quando suportado', () async {
      final store = _MemoryRouter();
      final lvs = LimitedValueStore(valueStore: store, namespaces: ['ns']);
      await lvs.bootstrap();
      expect(store.bootstrapCalls, equals(1));
    });
  });

  group('MultiException [Atomic Audit]', () {
    test('toString() - formata multiplos erros separados por ponto e virgula', () {
      final err = MultiException([Exception('err1'), const FormatException('err2')]);
      final str = err.toString();
      expect(str, contains('err1'));
      expect(str, contains('err2'));
      expect(str, contains('; '));
    });
  });

  group('NullRouter [Atomic Audit]', () {
    const nr = NullRouter();

    test('putValue() - lanca RoutingNotSupportedException em qualquer gravacao', () async {
      expect(
        () => nr.putValue('/any', sampleBytes),
        throwsA(isA<RoutingNotSupportedException>()),
      );
    });

    test('getValue() - lanca RoutingNotFoundException em qualquer busca', () async {
      expect(
        () => nr.getValue('/any'),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test('searchValue() - emite stream contendo RoutingNotFoundException', () async {
      expect(
        nr.searchValue('/any'),
        emitsError(isA<RoutingNotFoundException>()),
      );
    });

    test('provide() - lanca RoutingNotSupportedException ao tentar anunciar', () async {
      expect(
        () => nr.provide(sampleCid, true),
        throwsA(isA<RoutingNotSupportedException>()),
      );
    });

    test('findProvidersAsync() - retorna sempre uma stream vazia de provedores', () async {
      final list = await nr.findProvidersAsync(sampleCid, 10).toList();
      expect(list, isEmpty);
    });

    test('findPeer() - lanca RoutingNotFoundException em qualquer par', () async {
      expect(
        () => nr.findPeer(samplePeerId),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test('bootstrap() - conclui imediatamente sem erros', () async {
      await expectLater(nr.bootstrap(), completes);
    });
  });

  group('Parallel [Atomic Audit]', () {
    test('putValue() - grava valor em paralelo nos roteadores compativeis com a chave', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final p = Parallel(routers: [r1, r2]);
      await p.putValue('/k/x', sampleBytes);
      expect(r1.putValueCalls, equals(1));
      expect(r2.putValueCalls, equals(1));
    });

    test('getValue() - consulta roteadores concorrentemente e retorna o primeiro valor', () async {
      final r1 = _MemoryRouter(initialValues: {'/k/x': sampleBytes});
      final r2 = _MemoryRouter();
      final p = Parallel(routers: [r1, r2]);
      final val = await p.getValue('/k/x');
      expect(val, equals(sampleBytes));
    });

    test('searchValue() - combina streams e seleciona melhor valor com validador', () async {
      final r1 = _MemoryRouter(initialValues: {'/k/x': Uint8List.fromList([1])});
      final r2 = _MemoryRouter(initialValues: {'/k/x': Uint8List.fromList([2])});
      final p = Parallel(routers: [r1, r2], validator: const _TestValidator());
      final list = await p.searchValue('/k/x').toList();
      expect(list, isNotEmpty);
    });

    test('getPublicKey() - consulta chaves publicas nos roteadores compativeis', () async {
      final pk = _TestPubKey();
      final r = _MemoryRouter(pubKey: pk);
      final p = Parallel(routers: [r]);
      final key = await p.getPublicKey(samplePeerId);
      expect(key, equals(pk));
    });

    test('findPeer() - localiza par nos roteadores que suportam busca de pares', () async {
      final r = _MemoryRouter(initialPeers: {samplePeerId: sampleAddrInfo});
      final p = Parallel(routers: [r]);
      final info = await p.findPeer(samplePeerId);
      expect(info.id, equals(samplePeerId));
    });

    test('provide() - anuncia conteudo para todos os roteadores que suportam conteudo', () async {
      final r = _MemoryRouter();
      final p = Parallel(routers: [r]);
      await p.provide(sampleCid, true);
      expect(r.providedCids, contains(sampleCid));
    });

    test('findProvidersAsync() - desduplica e emite provedores encontrados em paralelo', () async {
      final r1 = _MemoryRouter(initialProviders: [samplePeerId]);
      final r2 = _MemoryRouter(initialProviders: [samplePeerId]);
      final p = Parallel(routers: [r1, r2]);
      final list = await p.findProvidersAsync(sampleCid, 2).toList();
      expect(list.length, equals(1));
      expect(list.first.id, equals(samplePeerId));
    });

    test('bootstrap() - executa bootstrap em todos os roteadores aninhados', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final p = Parallel(routers: [r1, r2]);
      await p.bootstrap();
      expect(r1.bootstrapCalls, equals(1));
      expect(r2.bootstrapCalls, equals(1));
    });

    test('close() - fecha todos os roteadores aninhados que implementam Closable', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final p = Parallel(routers: [r1, r2]);
      await p.close();
      expect(r1.closeCalls, equals(1));
      expect(r2.closeCalls, equals(1));
    });
  });

  group('Closable [Atomic Audit]', () {
    test('close() - libera recursos do roteador na interface', () async {
      final closable = _TestClosable();
      expect(closable.closed, isFalse);
      await closable.close();
      expect(closable.closed, isTrue);
    });
  });

  group('Tiered [Atomic Audit]', () {
    test('putValue() - delega gravacao para execucao paralela', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter();
      final tiered = Tiered(routers: [r1, r2]);
      await tiered.putValue('/k/x', sampleBytes);
      expect(r1.putValueCalls, equals(1));
      expect(r2.putValueCalls, equals(1));
    });

    test('getValue() - consulta roteadores em ordem sequencial ate obter sucesso', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter(initialValues: {'/k/x': sampleBytes});
      final tiered = Tiered(routers: [r1, r2]);
      final val = await tiered.getValue('/k/x');
      expect(val, equals(sampleBytes));
    });

    test('searchValue() - delega busca de valores para execucao paralela', () async {
      final r1 = _MemoryRouter(initialValues: {'/k/x': sampleBytes});
      final tiered = Tiered(routers: [r1], validator: const _TestValidator());
      final list = await tiered.searchValue('/k/x').toList();
      expect(list, contains(sampleBytes));
    });

    test('getPublicKey() - busca chave publica sequencialmente entre os roteadores', () async {
      final pk = _TestPubKey();
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter(pubKey: pk);
      final tiered = Tiered(routers: [r1, r2]);
      final found = await tiered.getPublicKey(samplePeerId);
      expect(found, equals(pk));
    });

    test('findPeer() - busca par sequencialmente na ordem dos roteadores', () async {
      final r1 = _MemoryRouter();
      final r2 = _MemoryRouter(initialPeers: {samplePeerId: sampleAddrInfo});
      final tiered = Tiered(routers: [r1, r2]);
      final info = await tiered.findPeer(samplePeerId);
      expect(info.id, equals(samplePeerId));
    });

    test('provide() - delega anuncio de provedores para execucao paralela', () async {
      final r1 = _MemoryRouter();
      final tiered = Tiered(routers: [r1]);
      await tiered.provide(sampleCid, true);
      expect(r1.providedCids, contains(sampleCid));
    });

    test('findProvidersAsync() - delega descoberta de provedores para execucao paralela', () async {
      final r1 = _MemoryRouter(initialProviders: [samplePeerId]);
      final tiered = Tiered(routers: [r1]);
      final list = await tiered.findProvidersAsync(sampleCid, 1).toList();
      expect(list.map((info) => info.id), contains(samplePeerId));
    });

    test('bootstrap() - delega inicializacao para execucao paralela', () async {
      final r1 = _MemoryRouter();
      final tiered = Tiered(routers: [r1]);
      await tiered.bootstrap();
      expect(r1.bootstrapCalls, equals(1));
    });

    test('close() - delega encerramento para os roteadores compativeis', () async {
      final r1 = _MemoryRouter();
      final tiered = Tiered(routers: [r1]);
      await tiered.close();
      expect(r1.closeCalls, equals(1));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('appendError() - concatena erros acumulando valores ou retornando o nao nulo', () {
      final err1 = Exception('e1');
      final err2 = Exception('e2');
      expect(appendError(null, null), isNull);
      expect(appendError(err1, null), same(err1));
      expect(appendError(null, err2), same(err2));

      final combined = appendError(err1, err2);
      expect(combined, isA<MultiException>());
      final me = combined as MultiException;
      expect(me.errors, equals([err1, err2]));

      final err3 = Exception('e3');
      final accumulated = appendError(combined, err3);
      expect(accumulated, isA<MultiException>());
      expect((accumulated as MultiException).errors, equals([err1, err2, err3]));
    });

    test('combineErrors() - consolida lista de erros retornando nulo unico ou MultiException', () {
      expect(combineErrors([]), isNull);
      final err1 = Exception('e1');
      expect(combineErrors([err1]), same(err1));

      final err2 = Exception('e2');
      final combined = combineErrors([err1, err2]);
      expect(combined, isA<MultiException>());
      expect((combined as MultiException).errors, equals([err1, err2]));
    });
  });
}
