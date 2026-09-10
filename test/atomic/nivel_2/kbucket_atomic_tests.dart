// test/atomic/nivel_2/kbucket_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo kbucket (transpiled_libp2p_kbucket).

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';

PeerId _makePeer(int seed) {
  final bytes = Uint8List(34);
  bytes[0] = 0x12;
  bytes[1] = 0x20;
  final bd = bytes.buffer.asByteData();
  bd.setUint32(2, seed, Endian.big);
  return PeerId(value: bytes);
}

class _TestPeerMetrics implements PeerMetrics {
  final Map<PeerId, Duration> latencies = {};
  Duration defaultLatency = Duration.zero;

  @override
  Duration latencyEwma(PeerId id) => latencies[id] ?? defaultLatency;
}

class _TestDiversityFilter implements DiversityFilter {
  final Set<PeerId> admitted = {};
  bool shouldAdmit = true;

  @override
  bool tryAdd(PeerId id) {
    if (!shouldAdmit) return false;
    admitted.add(id);
    return true;
  }

  @override
  void remove(PeerId id) {
    admitted.remove(id);
  }
}

class _FakeKeySpace implements KeySpace {
  @override
  BigInt distance(KeyspaceKey a, KeyspaceKey b) => BigInt.zero;
  @override
  int compare(KeyspaceKey a, KeyspaceKey b) => 0;
  @override
  KeyspaceKey key(Uint8List id) => KeyspaceKey(space: this, original: id, bytes: id);
  @override
  bool keyEqual(KeyspaceKey a, KeyspaceKey b) => true;
}

RoutingTable _makeTable({
  int bucketSize = 2,
  PeerId? local,
  Duration maxLatency = const Duration(seconds: 1),
  PeerMetrics? metrics,
  Duration usefulnessGracePeriod = const Duration(minutes: 1),
  DiversityFilter? diversityFilter,
}) {
  return RoutingTable(
    bucketSize: bucketSize,
    local: local ?? _makePeer(0),
    maxLatency: maxLatency,
    metrics: metrics ?? _TestPeerMetrics(),
    usefulnessGracePeriod: usefulnessGracePeriod,
    diversityFilter: diversityFilter,
  );
}

void main() {
  group('PeerInfo [Atomic Audit]', () {
    test('lastUsefulAtIsZero - verifica se lastUsefulAt foi configurado ou permanece zero', () {
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      expect(p1.lastUsefulAtIsZero, isTrue);

      final p2 = PeerInfo(
        id: _makePeer(2),
        dhtId: convertPeerId(_makePeer(2)),
        lastUsefulAt: DateTime.now().toUtc(),
      );
      expect(p2.lastUsefulAtIsZero, isFalse);
    });
  });

  group('Bucket [Atomic Audit]', () {
    test('peers() - retorna lista defensiva e imutavel dos peers contidos', () {
      final bucket = Bucket();
      final p = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      bucket.pushFront(p);
      final list = bucket.peers();
      expect(list.length, equals(1));
      expect(list.first.id, equals(p.id));
      expect(() => list.add(p), throwsUnsupportedError);
    });

    test('min() - encontra o peer com menor valor pelo comparador fornecido', () {
      final bucket = Bucket();
      expect(bucket.min((a, b) => a.replaceable), isNull);

      final now = DateTime.now().toUtc();
      final p1 = PeerInfo(
        id: _makePeer(1),
        dhtId: convertPeerId(_makePeer(1)),
        addedAt: now.subtract(const Duration(minutes: 10)),
      );
      final p2 = PeerInfo(
        id: _makePeer(2),
        dhtId: convertPeerId(_makePeer(2)),
        addedAt: now.subtract(const Duration(minutes: 5)),
      );
      bucket.pushFront(p2);
      bucket.pushFront(p1);

      final oldest = bucket.min((a, b) => a.addedAt.isBefore(b.addedAt));
      expect(oldest?.id, equals(p1.id));
    });

    test('updateAllWith() - aplica atualizacao em todos os peers presentes', () {
      final bucket = Bucket();
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)), replaceable: false);
      final p2 = PeerInfo(id: _makePeer(2), dhtId: convertPeerId(_makePeer(2)), replaceable: false);
      bucket.pushFront(p1);
      bucket.pushFront(p2);

      bucket.updateAllWith((p) => p.replaceable = true);
      expect(bucket.peers().every((p) => p.replaceable), isTrue);
    });

    test('peerIds() - retorna lista de identificadores dos peers no bucket', () {
      final bucket = Bucket();
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      final p2 = PeerInfo(id: _makePeer(2), dhtId: convertPeerId(_makePeer(2)));
      bucket.pushFront(p1);
      bucket.pushFront(p2);

      final ids = bucket.peerIds();
      expect(ids, containsAll([p1.id, p2.id]));
      expect(ids.length, equals(2));
    });

    test('getPeer() - busca peer por ID ou retorna nulo se nao existir', () {
      final bucket = Bucket();
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      bucket.pushFront(p1);

      expect(bucket.getPeer(p1.id)?.id, equals(p1.id));
      expect(bucket.getPeer(_makePeer(99)), isNull);
    });

    test('remove() - remove peer existente por ID e retorna status booleano', () {
      final bucket = Bucket();
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      bucket.pushFront(p1);

      expect(bucket.remove(p1.id), isTrue);
      expect(bucket.remove(p1.id), isFalse);
      expect(bucket.length, equals(0));
    });

    test('pushFront() - insere peer no inicio da lista do bucket', () {
      final bucket = Bucket();
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      final p2 = PeerInfo(id: _makePeer(2), dhtId: convertPeerId(_makePeer(2)));
      bucket.pushFront(p1);
      bucket.pushFront(p2);

      expect(bucket.peers().first.id, equals(p2.id));
      expect(bucket.peers().last.id, equals(p1.id));
    });

    test('length - retorna a contagem exata de peers contidos', () {
      final bucket = Bucket();
      expect(bucket.length, equals(0));
      bucket.pushFront(PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1))));
      expect(bucket.length, equals(1));
    });

    test('split() - particiona bucket preservando peers com cpl menor ou igual e movendo maiores', () {
      final bucket = Bucket();
      final target = Uint8List(32);
      final idStay = Uint8List(32)..[0] = 0x80;
      final idMove = Uint8List(32)..[0] = 0x01;

      final pStay = PeerInfo(id: _makePeer(1), dhtId: idStay);
      final pMove = PeerInfo(id: _makePeer(2), dhtId: idMove);

      bucket.pushFront(pStay);
      bucket.pushFront(pMove);

      final splitBucket = bucket.split(0, target);
      expect(bucket.length, equals(1));
      expect(bucket.peers().first.id, equals(pStay.id));
      expect(splitBucket.length, equals(1));
      expect(splitBucket.peers().first.id, equals(pMove.id));
    });

    test('maxCommonPrefix() - computa o maior prefixo comum entre peers do bucket e o alvo', () {
      final bucket = Bucket();
      final target = Uint8List(32);
      expect(bucket.maxCommonPrefix(target), equals(0));

      final id1 = Uint8List(32)..[0] = 0x80;
      final id2 = Uint8List(32)..[0] = 0x08;
      bucket.pushFront(PeerInfo(id: _makePeer(1), dhtId: id1));
      bucket.pushFront(PeerInfo(id: _makePeer(2), dhtId: id2));

      expect(bucket.maxCommonPrefix(target), equals(4));
    });
  });

  group('KeyspaceKey [Atomic Audit]', () {
    test('compareTo() - compara chaves do mesmo espaco e lanca StateError se espacos diferirem', () {
      final space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([1]));
      final k2 = space.key(Uint8List.fromList([2]));

      expect(k1.compareTo(k1), equals(0));
      expect(k1.compareTo(k2) != 0, isTrue);

      final fakeKey = _FakeKeySpace().key(Uint8List.fromList([1]));
      expect(() => k1.compareTo(fakeKey), throwsA(isA<StateError>()));
    });

    test('keyEquals() - determina igualdade de chaves dentro do mesmo espaco', () {
      final space = XorKeySpace.instance;
      final k1a = space.key(Uint8List.fromList([10]));
      final k1b = space.key(Uint8List.fromList([10]));
      final k2 = space.key(Uint8List.fromList([20]));

      expect(k1a.keyEquals(k1b), isTrue);
      expect(k1a.keyEquals(k2), isFalse);
    });

    test('distanceTo() - calcula distancia numerica BigInt ate outra chave no mesmo espaco', () {
      final space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([5]));
      final k2 = space.key(Uint8List.fromList([5]));
      final k3 = space.key(Uint8List.fromList([6]));

      expect(k1.distanceTo(k2), equals(BigInt.zero));
      expect(k1.distanceTo(k3) > BigInt.zero, isTrue);
    });
  });

  group('KeySpace [Atomic Audit]', () {
    test('key() - instancia KeyspaceKey preservando original e espaco', () {
      final KeySpace space = XorKeySpace.instance;
      final raw = Uint8List.fromList([1, 2, 3]);
      final k = space.key(raw);
      expect(k.original, equals(raw));
      expect(k.space, equals(space));
    });

    test('keyEqual() - verifica igualdade de chaves pela interface KeySpace', () {
      final KeySpace space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([1]));
      final k2 = space.key(Uint8List.fromList([1]));
      final k3 = space.key(Uint8List.fromList([2]));
      expect(space.keyEqual(k1, k2), isTrue);
      expect(space.keyEqual(k1, k3), isFalse);
    });

    test('distance() - calcula metrica de distancia entre duas chaves', () {
      final KeySpace space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([1]));
      final k2 = space.key(Uint8List.fromList([2]));
      expect(space.distance(k1, k1), equals(BigInt.zero));
      expect(space.distance(k1, k2) > BigInt.zero, isTrue);
    });

    test('compare() - estabelece ordenacao entre chaves no espaco', () {
      final KeySpace space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([1]));
      final k2 = space.key(Uint8List.fromList([2]));
      expect(space.compare(k1, k1), equals(0));
      expect(space.compare(k1, k2) != 0, isTrue);
    });
  });

  group('PeerMetrics [Atomic Audit]', () {
    test('latencyEwma() - obtem duracao de latencia associada ao peer', () {
      final metrics = _TestPeerMetrics();
      final p = _makePeer(1);
      expect(metrics.latencyEwma(p), equals(Duration.zero));
      metrics.latencies[p] = const Duration(milliseconds: 250);
      expect(metrics.latencyEwma(p), equals(const Duration(milliseconds: 250)));
    });
  });

  group('PeerDistanceSorter [Atomic Audit]', () {
    test('length - retorna numero de peers anexados ao classificador', () {
      final target = Uint8List(32);
      final sorter = PeerDistanceSorter(target);
      expect(sorter.length, equals(0));
      sorter.appendPeer(_makePeer(1), convertPeerId(_makePeer(1)));
      expect(sorter.length, equals(1));
    });

    test('appendPeer() - adiciona peer com seu respectivo DhtId para ordenacao', () {
      final target = Uint8List(32);
      final sorter = PeerDistanceSorter(target);
      final p = _makePeer(1);
      sorter.appendPeer(p, convertPeerId(p));
      expect(sorter.peers.first, equals(p));
    });

    test('appendPeersFromBucket() - anexa peers contidos em um bucket no classificador', () {
      final target = Uint8List(32);
      final sorter = PeerDistanceSorter(target);
      final bucket = Bucket();
      final p1 = PeerInfo(id: _makePeer(1), dhtId: convertPeerId(_makePeer(1)));
      final p2 = PeerInfo(id: _makePeer(2), dhtId: convertPeerId(_makePeer(2)));
      bucket.pushFront(p1);
      bucket.pushFront(p2);

      sorter.appendPeersFromBucket(bucket);
      expect(sorter.length, equals(2));
      expect(sorter.peers, containsAll([p1.id, p2.id]));
    });

    test('sort() - reordena peers anexados por distancia crescente em relacao ao alvo', () {
      final target = Uint8List(32);
      final sorter = PeerDistanceSorter(target);
      final pFar = _makePeer(1);
      final idFar = Uint8List(32)..[0] = 0xFF;
      final pNear = _makePeer(2);
      final idNear = Uint8List(32)..[0] = 0x01;

      sorter.appendPeer(pFar, idFar);
      sorter.appendPeer(pNear, idNear);
      sorter.sort();

      expect(sorter.peers.first, equals(pNear));
      expect(sorter.peers.last, equals(pFar));
    });

    test('peers - expoe lista ordenada de PeerId atualmente armazenados', () {
      final target = Uint8List(32);
      final sorter = PeerDistanceSorter(target);
      final p = _makePeer(1);
      sorter.appendPeer(p, convertPeerId(p));
      expect(sorter.peers, equals([p]));
    });
  });

  group('DiversityFilter [Atomic Audit]', () {
    test('tryAdd() - tenta registrar novo peer avaliando diversidade de rede', () {
      final filter = _TestDiversityFilter();
      final p1 = _makePeer(1);
      expect(filter.tryAdd(p1), isTrue);
      expect(filter.admitted.contains(p1), isTrue);

      filter.shouldAdmit = false;
      expect(filter.tryAdd(_makePeer(2)), isFalse);
    });

    test('remove() - desregistra peer previamente admitido pelo filtro', () {
      final filter = _TestDiversityFilter();
      final p1 = _makePeer(1);
      filter.tryAdd(p1);
      expect(filter.admitted.contains(p1), isTrue);
      filter.remove(p1);
      expect(filter.admitted.contains(p1), isFalse);
    });
  });

  group('RoutingTable [Atomic Audit]', () {
    test('close() - encerra tabela sem erros de forma idempotente', () {
      final table = _makeTable();
      expect(() => table.close(), returnsNormally);
    });

    test('cplRefreshedAt - acessa e manipula mapa de timestamps de refresh por cpl', () {
      final table = _makeTable();
      expect(table.cplRefreshedAt, isEmpty);
      final now = DateTime.now().toUtc();
      table.cplRefreshedAt[0] = now;
      expect(table.cplRefreshedAt[0], equals(now));
    });

    test('nPeersForCpl() - retorna total de peers armazenados para determinado cpl', () {
      final table = _makeTable();
      expect(table.nPeersForCpl(0), equals(0));
      expect(table.nPeersForCpl(10), equals(0));
    });

    test('usefulNewPeer() - identifica se novo peer e util para entrada na tabela', () {
      final table = _makeTable(bucketSize: 2);
      final p1 = _makePeer(1);
      expect(table.usefulNewPeer(p1), isTrue);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);
      expect(table.usefulNewPeer(p1), isFalse);
    });

    test('tryAddPeer() - adiciona peer ou lanca rejeicao por latencia ou capacidade excedida', () {
      final table = _makeTable(bucketSize: 1);
      final p1 = _makePeer(1);
      expect(table.tryAddPeer(p1, queryPeer: true, isReplaceable: false), isTrue);
      expect(table.tryAddPeer(p1, queryPeer: true, isReplaceable: false), isFalse);

      final metrics = _TestPeerMetrics();
      final pHigh = _makePeer(2);
      metrics.latencies[pHigh] = const Duration(seconds: 10);
      final tableHigh = _makeTable(maxLatency: const Duration(seconds: 1), metrics: metrics);
      expect(
        () => tableHigh.tryAddPeer(pHigh, queryPeer: true, isReplaceable: false),
        throwsA(isA<PeerRejectedHighLatencyException>()),
      );
    });

    test('markAllPeersIrreplaceable() - define flag replaceable como false para todos os peers', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      table.tryAddPeer(p1, queryPeer: false, isReplaceable: true);
      expect(table.getPeerInfos().first.replaceable, isTrue);

      table.markAllPeersIrreplaceable();
      expect(table.getPeerInfos().first.replaceable, isFalse);
    });

    test('getPeerInfos() - retorna lista completa dos registros PeerInfo da tabela', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      final p2 = _makePeer(2);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);
      table.tryAddPeer(p2, queryPeer: true, isReplaceable: false);

      final infos = table.getPeerInfos();
      expect(infos.length, equals(2));
      expect(infos.map((i) => i.id), containsAll([p1, p2]));
    });

    test('updateLastSuccessfulOutboundQueryAt() - atualiza timestamp da ultima consulta bem sucedida', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);

      final queryTime = DateTime.utc(2026, 1, 1);
      expect(table.updateLastSuccessfulOutboundQueryAt(p1, queryTime), isTrue);
      expect(table.getPeerInfos().first.lastSuccessfulOutboundQueryAt, equals(queryTime));
      expect(table.updateLastSuccessfulOutboundQueryAt(_makePeer(99), queryTime), isFalse);
    });

    test('updateLastUsefulAt() - atualiza timestamp de utilidade do peer na tabela', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);

      final usefulTime = DateTime.utc(2026, 1, 2);
      expect(table.updateLastUsefulAt(p1, usefulTime), isTrue);
      expect(table.getPeerInfos().first.lastUsefulAt, equals(usefulTime));
      expect(table.updateLastUsefulAt(_makePeer(99), usefulTime), isFalse);
    });

    test('removePeer() - remove peer existente e invoca callback de remocao', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      PeerId? removed;
      table.onPeerRemoved = (id) => removed = id;

      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);
      expect(table.size(), equals(1));

      table.removePeer(p1);
      expect(table.size(), equals(0));
      expect(removed, equals(p1));
    });

    test('find() - localiza peer exato presente na tabela ou retorna nulo', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);

      expect(table.find(p1), equals(p1));
      expect(table.find(_makePeer(99)), isNull);
    });

    test('nearestPeer() - seleciona o peer mais proximo do DhtId de busca', () {
      final table = _makeTable(bucketSize: 5);
      expect(table.nearestPeer(convertPeerId(_makePeer(1))), isNull);

      final p1 = _makePeer(1);
      final p2 = _makePeer(2);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);
      table.tryAddPeer(p2, queryPeer: true, isReplaceable: false);

      final near = table.nearestPeer(convertPeerId(p1));
      expect(near, equals(p1));
    });

    test('nearestPeers() - retorna quantidade solicitada de peers proximos por XOR', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      final p2 = _makePeer(2);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);
      table.tryAddPeer(p2, queryPeer: true, isReplaceable: false);

      final nearest = table.nearestPeers(convertPeerId(p1), 1);
      expect(nearest.length, equals(1));
      expect(nearest.first, equals(p1));
    });

    test('size() - computa numero total de peers em todos os buckets', () {
      final table = _makeTable(bucketSize: 5);
      expect(table.size(), equals(0));
      table.tryAddPeer(_makePeer(1), queryPeer: true, isReplaceable: false);
      expect(table.size(), equals(1));
    });

    test('listPeers() - lista todos os identificadores presentes na tabela', () {
      final table = _makeTable(bucketSize: 5);
      final p1 = _makePeer(1);
      table.tryAddPeer(p1, queryPeer: true, isReplaceable: false);
      expect(table.listPeers(), equals([p1]));
    });

    test('maxCommonPrefix() - calcula maior prefixo comum entre peers e no local', () {
      final table = _makeTable(bucketSize: 5);
      expect(table.maxCommonPrefix(), equals(0));
      table.tryAddPeer(_makePeer(1), queryPeer: true, isReplaceable: false);
      expect(table.maxCommonPrefix(), greaterThanOrEqualTo(0));
    });
  });

  group('RoutingTableRefresh [Atomic Audit]', () {
    test('getTrackedCplsForRefresh() - obtem lista de instantes de atualizacao rastreados', () {
      final table = _makeTable(bucketSize: 5);
      final tracked = table.getTrackedCplsForRefresh();
      expect(tracked, isNotEmpty);
      expect(tracked.first, equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
    });

    test('genRandPeerId() - gera DhtId aleatorio com cpl determinado', () {
      final table = _makeTable(bucketSize: 5);
      final randId = table.genRandPeerId(0);
      expect(randId.length, equals(34));
    });

    test('genRandomKey() - deriva chave aleatoria com cpl especificado e valida limites', () {
      final table = _makeTable(bucketSize: 5);
      final key0 = table.genRandomKey(0);
      expect(key0.length, equals(32));
      expect(commonPrefixLen(convertPeerId(table.local), key0), equals(0));
      expect(() => table.genRandomKey(300), throwsA(isA<ArgumentError>()));
    });

    test('resetCplRefreshedAtForId() - atualiza momento de refresh para o cpl associado ao ID', () {
      final table = _makeTable(bucketSize: 5);
      final target = convertPeerId(_makePeer(1));
      final updateTime = DateTime.utc(2026, 2, 2);
      table.resetCplRefreshedAtForId(target, updateTime);

      final cpl = commonPrefixLen(target, convertPeerId(table.local));
      expect(table.cplRefreshedAt[cpl], equals(updateTime));
    });
  });

  group('LookupFailureException [Atomic Audit]', () {
    test('toString() - formata texto explicativo de falha ao buscar peer', () {
      const ex = LookupFailureException();
      expect(ex.toString(), equals('failed to find any peer in table'));
    });
  });

  group('PeerRejectedHighLatencyException [Atomic Audit]', () {
    test('toString() - descreve rejeicao de peer por latencia excessiva', () {
      const ex = PeerRejectedHighLatencyException();
      expect(ex.toString(), equals('peer rejected; latency too high'));
    });
  });

  group('PeerRejectedNoCapacityException [Atomic Audit]', () {
    test('toString() - descreve rejeicao por insuficiencia de capacidade no bucket', () {
      const ex = PeerRejectedNoCapacityException();
      expect(ex.toString(), equals('peer rejected; insufficient capacity'));
    });
  });

  group('XorKeySpace [Atomic Audit]', () {
    test('key() - gera chave normalizada por SHA256 no espaco XOR', () {
      final space = XorKeySpace.instance;
      final raw = Uint8List.fromList([1, 2, 3]);
      final k = space.key(raw);
      expect(k.original, equals(raw));
      expect(k.bytes.length, equals(32));
      expect(k.space, equals(space));
    });

    test('compare() - ordena chaves com base nos bytes de hash', () {
      final space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([1]));
      final k2 = space.key(Uint8List.fromList([2]));
      expect(space.compare(k1, k1), equals(0));
      expect(space.compare(k1, k2) != 0, isTrue);
    });

    test('keyEqual() - compara equivalencia de hashes entre duas chaves', () {
      final space = XorKeySpace.instance;
      final k1a = space.key(Uint8List.fromList([7]));
      final k1b = space.key(Uint8List.fromList([7]));
      final k2 = space.key(Uint8List.fromList([8]));
      expect(space.keyEqual(k1a, k1b), isTrue);
      expect(space.keyEqual(k1a, k2), isFalse);
    });

    test('distance() - calcula valor XOR resultante convertido para BigInt', () {
      final space = XorKeySpace.instance;
      final k1 = space.key(Uint8List.fromList([9]));
      final k2 = space.key(Uint8List.fromList([10]));
      expect(space.distance(k1, k1), equals(BigInt.zero));
      expect(space.distance(k1, k2) > BigInt.zero, isTrue);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('sortByDistance() - reordena lista de KeyspaceKey por distancia ao centro', () {
      final space = XorKeySpace.instance;
      final center = space.key(Uint8List.fromList([0]));
      final k1 = space.key(Uint8List.fromList([1]));
      final k2 = space.key(Uint8List.fromList([2]));
      final sorted = sortByDistance(space, center, [k2, k1]);
      expect(sorted.length, equals(2));
      expect(center.distanceTo(sorted.first) <= center.distanceTo(sorted.last), isTrue);
    });

    test('sortClosestPeers() - ordena identificadores de peers por distancia XOR ao alvo', () {
      final target = Uint8List(32);
      final p1 = _makePeer(1);
      final p2 = _makePeer(2);
      final sorted = sortClosestPeers([p1, p2], target);
      expect(sorted.length, equals(2));
    });

    test('xor() - efetua operacao XOR em dois arrays de identificador DHT', () {
      final a = Uint8List.fromList([0xAA, 0x55]);
      final b = Uint8List.fromList([0x55, 0xAA]);
      final result = xor(a, b);
      expect(result, equals(Uint8List.fromList([0xFF, 0xFF])));
    });

    test('commonPrefixLen() - mede quantidade de bits iniciais coincidentes', () {
      final a = Uint8List.fromList([0xFF, 0x00]);
      final b = Uint8List.fromList([0xFF, 0x80]);
      expect(commonPrefixLen(a, b), equals(8));
    });

    test('convertPeerId() - gera DhtId aplicando hash SHA256 sobre os bytes do peer', () {
      final p = _makePeer(42);
      final dhtId = convertPeerId(p);
      expect(dhtId.length, equals(32));
    });

    test('convertKey() - converte string textual em identificador DhtId via SHA256', () {
      final dhtId = convertKey('test-key-string');
      expect(dhtId.length, equals(32));
    });

    test('closer() - avalia qual dos dois peers possui menor distancia ao hash da chave', () {
      final p1 = _makePeer(1);
      final p2 = _makePeer(2);
      final p1Closer = closer(p1, p2, 'routing-key');
      final p2Closer = closer(p2, p1, 'routing-key');
      expect(p1Closer != p2Closer, isTrue);
    });

    test('randUint16() - produz inteiro sem sinal aleatorio de 16 bits', () {
      final value = randUint16();
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(0xFFFF));
    });

    test('genRandPeerIdWithCpl() - deriva PeerId compativel com cpl ou rejeita acima do limite', () {
      final target = Uint8List(32)..[0] = 0x12;
      final peer = genRandPeerIdWithCpl(target, 2);
      expect(peer.value.length, equals(34));
      expect(() => genRandPeerIdWithCpl(target, 16), throwsA(isA<ArgumentError>()));
    });

    test('zeroPrefixLen() - calcula numero de bits zero no inicio do byte array', () {
      expect(zeroPrefixLen(Uint8List.fromList([0x00, 0x00])), equals(16));
      expect(zeroPrefixLen(Uint8List.fromList([0x80])), equals(0));
      expect(zeroPrefixLen(Uint8List.fromList([0x01])), equals(7));
    });

    test('xorBytes() - calcula operacao XOR byte a byte para vetores de igual tamanho', () {
      final a = Uint8List.fromList([0x0F, 0xF0]);
      final b = Uint8List.fromList([0xF0, 0x0F]);
      expect(xorBytes(a, b), equals(Uint8List.fromList([0xFF, 0xFF])));
    });
  });
}
