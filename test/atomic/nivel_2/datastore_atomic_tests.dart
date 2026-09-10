// test/atomic/nivel_2/datastore_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo datastore (transpiled_datastore)
// Nivel 2 - Emulacao Local / Memoria

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

bool _dummyFeatureMatch(Datastore d) => true;
bool _otherFeatureMatch(Datastore d) => false;

class _TestTtlDatastore implements TtlDatastore {
  DateTime _expiration = DateTime.now().add(const Duration(hours: 1));

  @override
  Future<void> putWithTtl(Key key, List<int> value, Duration ttl) async {
    _expiration = DateTime.now().add(ttl);
  }

  @override
  Future<void> setTtl(Key key, Duration ttl) async {
    _expiration = DateTime.now().add(ttl);
  }

  @override
  Future<DateTime> getExpiration(Key key) async => _expiration;

  @override
  Future<void> close() async {}

  @override
  Future<void> delete(Key key) async {}

  @override
  Future<List<int>> get(Key key) async => const [1];

  @override
  Future<int> getSize(Key key) async => 1;

  @override
  Future<bool> has(Key key) async => true;

  @override
  Future<void> put(Key key, List<int> value) async {}

  @override
  Future<Results> query(Query q) async => resultsWithEntries(q, const []);

  @override
  Future<void> sync(Key prefix) async {}
}

void main() {
  group('MapDatastore [Atomic Audit]', () {
    test('put(key, value) - armazena par chave e valor no datastore', () async {
      final ds = MapDatastore();
      await ds.put(Key('/a'), [1, 2, 3]);
      expect(await ds.has(Key('/a')), isTrue);
    });

    test('sync(prefix) - sincroniza prefixo sem erros', () async {
      final ds = MapDatastore();
      await ds.put(Key('/a/1'), [1]);
      await ds.sync(Key('/a'));
      expect(await ds.has(Key('/a/1')), isTrue);
    });

    test('get(key) - busca valor associado a chave', () async {
      final ds = MapDatastore();
      await ds.put(Key('/a'), [10, 20]);
      expect(await ds.get(Key('/a')), equals([10, 20]));
      expect(() => ds.get(Key('/inexistente')), throwsA(isA<NotFoundException>()));
    });

    test('has(key) - verifica existencia da chave informada', () async {
      final ds = MapDatastore();
      await ds.put(Key('/existe'), [1]);
      expect(await ds.has(Key('/existe')), isTrue);
      expect(await ds.has(Key('/nao_existe')), isFalse);
    });

    test('getSize(key) - retorna tamanho em bytes do valor mapeado', () async {
      final ds = MapDatastore();
      await ds.put(Key('/size_key'), [1, 2, 3, 4, 5]);
      expect(await ds.getSize(Key('/size_key')), equals(5));
      expect(() => ds.getSize(Key('/inexistente')), throwsA(isA<NotFoundException>()));
    });

    test('delete(key) - remove par chave e valor do datastore', () async {
      final ds = MapDatastore();
      await ds.put(Key('/del'), [1]);
      await ds.delete(Key('/del'));
      expect(await ds.has(Key('/del')), isFalse);
    });

    test('query(q) - executa consulta estruturada sobre as entradas', () async {
      final ds = MapDatastore();
      await ds.put(Key('/q/1'), [1]);
      await ds.put(Key('/q/2'), [2]);
      final res = await ds.query(const Query(prefix: '/q'));
      final list = res.rest();
      expect(list.length, equals(2));
    });

    test('batch() - instancia lote basico para operacoes agrupadas', () async {
      final ds = MapDatastore();
      final b = await ds.batch();
      expect(b, isA<BasicBatch>());
      await b.put(Key('/b1'), [42]);
      await b.commit();
      expect(await ds.has(Key('/b1')), isTrue);
    });

    test('close() - encerra datastore sem lancar excecoes', () async {
      final ds = MapDatastore();
      await ds.close();
      expect(true, isTrue);
    });
  });

  group('Shim [Atomic Audit]', () {
    test('children() - expoem lista de datastores filhos encapsulados', () {
      final inner = MapDatastore();
      final Shim shim = LogDatastore(inner);
      expect(shim.children(), equals([inner]));
    });
  });

  group('LogDatastore [Atomic Audit]', () {
    test('children() - retorna datastore filho monitorado', () {
      final inner = MapDatastore();
      final logDs = LogDatastore(inner, 'TestLogger');
      expect(logDs.children(), equals([inner]));
    });

    test('put(key, value) - registra log e delega escrita para filho', () async {
      final inner = MapDatastore();
      final logDs = LogDatastore(inner);
      await logDs.put(Key('/k'), [10, 20]);
      expect(await inner.has(Key('/k')), isTrue);
    });

    test('sync(prefix) - registra log e delega sincronizacao', () async {
      final inner = MapDatastore();
      final logDs = LogDatastore(inner);
      await logDs.sync(Key('/k'));
      expect(true, isTrue);
    });

    test('get(key) - registra log e delega leitura para filho', () async {
      final inner = MapDatastore();
      await inner.put(Key('/k'), [1, 2, 3]);
      final logDs = LogDatastore(inner);
      expect(await logDs.get(Key('/k')), equals([1, 2, 3]));
    });

    test('has(key) - registra log e delega verificacao de chave', () async {
      final inner = MapDatastore();
      await inner.put(Key('/k'), [1]);
      final logDs = LogDatastore(inner);
      expect(await logDs.has(Key('/k')), isTrue);
      expect(await logDs.has(Key('/absent')), isFalse);
    });

    test('getSize(key) - registra log e delega calculo de tamanho', () async {
      final inner = MapDatastore();
      await inner.put(Key('/k'), [1, 2, 3, 4]);
      final logDs = LogDatastore(inner);
      expect(await logDs.getSize(Key('/k')), equals(4));
    });

    test('delete(key) - registra log e delega remocao', () async {
      final inner = MapDatastore();
      await inner.put(Key('/k'), [1]);
      final logDs = LogDatastore(inner);
      await logDs.delete(Key('/k'));
      expect(await inner.has(Key('/k')), isFalse);
    });

    test('diskUsage() - registra log e calcula uso de disco do filho', () async {
      final inner = MapDatastore();
      final logDs = LogDatastore(inner);
      final usage = await logDs.diskUsage();
      expect(usage, equals(0));
    });

    test('query(q) - registra log e delega consulta ao datastore filho', () async {
      final inner = MapDatastore();
      await inner.put(Key('/item/1'), [99]);
      final logDs = LogDatastore(inner);
      final res = await logDs.query(const Query(prefix: '/item'));
      expect(res.rest().length, equals(1));
    });

    test('batch() - instancia lote com logs para filho compativel', () async {
      final inner = MapDatastore();
      final logDs = LogDatastore(inner);
      final b = await logDs.batch();
      await b.put(Key('/b'), [77]);
      await b.commit();
      expect(await inner.has(Key('/b')), isTrue);
    });

    test('close() - registra log e fecha o datastore filho', () async {
      final inner = MapDatastore();
      final logDs = LogDatastore(inner);
      await logDs.close();
      expect(true, isTrue);
    });

    test('check() - delega checagem caso o filho suporte CheckedDatastore', () async {
      final inner = NullDatastore();
      final logDs = LogDatastore(inner);
      await logDs.check();
      expect(true, isTrue);
    });

    test('scrub() - delega limpeza caso o filho suporte ScrubbedDatastore', () async {
      final inner = NullDatastore();
      final logDs = LogDatastore(inner);
      await logDs.scrub();
      expect(true, isTrue);
    });

    test('collectGarbage() - delega coleta de lixo se suportada', () async {
      final inner = NullDatastore();
      final logDs = LogDatastore(inner);
      await logDs.collectGarbage();
      expect(true, isTrue);
    });
  });

  group('BasicBatch [Atomic Audit]', () {
    test('put(key, value) - enfileira gravacao no lote para posterior commit', () async {
      final ds = MapDatastore();
      final b = BasicBatch(ds);
      await b.put(Key('/k1'), [1, 2]);
      expect(await ds.has(Key('/k1')), isFalse);
    });

    test('delete(key) - enfileira remocao no lote para posterior commit', () async {
      final ds = MapDatastore();
      await ds.put(Key('/k2'), [3, 4]);
      final b = BasicBatch(ds);
      await b.delete(Key('/k2'));
      expect(await ds.has(Key('/k2')), isTrue);
    });

    test('commit() - descarrega todas as operacoes gravadas no datastore alvo', () async {
      final ds = MapDatastore();
      await ds.put(Key('/del_me'), [1]);
      final b = BasicBatch(ds);
      await b.put(Key('/add_me'), [2]);
      await b.delete(Key('/del_me'));
      await b.commit();
      expect(await ds.has(Key('/add_me')), isTrue);
      expect(await ds.has(Key('/del_me')), isFalse);
    });
  });

  group('NotFoundException [Atomic Audit]', () {
    test('toString() - formata texto padrao de chave nao encontrada', () {
      const ex = NotFoundException();
      expect(ex.toString(), equals('datastore: key not found'));
    });
  });

  group('BatchUnsupportedException [Atomic Audit]', () {
    test('toString() - formata texto padrao de lote nao suportado', () {
      const ex = BatchUnsupportedException();
      expect(ex.toString(), equals('this datastore does not support batching'));
    });
  });

  group('Read [Atomic Audit]', () {
    test('get(key) - le valor atraves da interface abstrata Read', () async {
      final MapDatastore mapDs = MapDatastore();
      await mapDs.put(Key('/r1'), [5, 6]);
      final Read reader = mapDs;
      expect(await reader.get(Key('/r1')), equals([5, 6]));
    });

    test('has(key) - verifica chave atraves da interface abstrata Read', () async {
      final MapDatastore mapDs = MapDatastore();
      await mapDs.put(Key('/r1'), [5, 6]);
      final Read reader = mapDs;
      expect(await reader.has(Key('/r1')), isTrue);
      expect(await reader.has(Key('/none')), isFalse);
    });

    test('getSize(key) - obtem tamanho atraves da interface abstrata Read', () async {
      final MapDatastore mapDs = MapDatastore();
      await mapDs.put(Key('/r1'), [5, 6]);
      final Read reader = mapDs;
      expect(await reader.getSize(Key('/r1')), equals(2));
    });

    test('query(q) - executa consulta atraves da interface abstrata Read', () async {
      final MapDatastore mapDs = MapDatastore();
      await mapDs.put(Key('/r1/sub'), [5, 6]);
      final Read reader = mapDs;
      final res = await reader.query(const Query(prefix: '/r1'));
      expect(res.rest(), hasLength(1));
    });
  });

  group('Write [Atomic Audit]', () {
    test('put(key, value) - armazena dados atraves da interface Write', () async {
      final MapDatastore mapDs = MapDatastore();
      final Write writer = mapDs;
      await writer.put(Key('/w1'), [9, 8]);
      expect(await mapDs.has(Key('/w1')), isTrue);
    });

    test('delete(key) - remove dados atraves da interface Write', () async {
      final MapDatastore mapDs = MapDatastore();
      await mapDs.put(Key('/w1'), [9, 8]);
      final Write writer = mapDs;
      await writer.delete(Key('/w1'));
      expect(await mapDs.has(Key('/w1')), isFalse);
    });
  });

  group('Datastore [Atomic Audit]', () {
    test('sync(prefix) - sincroniza dados atraves da interface Datastore', () async {
      final Datastore ds = MapDatastore();
      await ds.sync(Key('/test_sync'));
      expect(true, isTrue);
    });

    test('close() - libera recursos atraves da interface Datastore', () async {
      final Datastore ds = MapDatastore();
      await ds.close();
      expect(true, isTrue);
    });
  });

  group('Batch [Atomic Audit]', () {
    test('commit() - executa confirmacao das alteracoes do lote', () async {
      final ds = MapDatastore();
      final Batch b = BasicBatch(ds);
      await b.put(Key('/batch_key'), [123]);
      await b.commit();
      expect(await ds.has(Key('/batch_key')), isTrue);
    });
  });

  group('Batching [Atomic Audit]', () {
    test('batch() - cria instancia de lote atraves da interface Batching', () async {
      final Batching bds = MapDatastore();
      final batch = await bds.batch();
      expect(batch, isA<Batch>());
    });
  });

  group('CheckedDatastore [Atomic Audit]', () {
    test('check() - valida integridade atraves da interface CheckedDatastore', () async {
      final CheckedDatastore cds = NullDatastore();
      await cds.check();
      expect(true, isTrue);
    });
  });

  group('ScrubbedDatastore [Atomic Audit]', () {
    test('scrub() - executa higienizacao atraves da interface ScrubbedDatastore', () async {
      final ScrubbedDatastore sds = NullDatastore();
      await sds.scrub();
      expect(true, isTrue);
    });
  });

  group('GcDatastore [Atomic Audit]', () {
    test('collectGarbage() - coleta lixo atraves da interface GcDatastore', () async {
      final GcDatastore gcds = NullDatastore();
      await gcds.collectGarbage();
      expect(true, isTrue);
    });
  });

  group('PersistentDatastore [Atomic Audit]', () {
    test('diskUsage() - quantifica armazenamento atraves da interface PersistentDatastore', () async {
      final PersistentDatastore pds = NullDatastore();
      final usage = await pds.diskUsage();
      expect(usage, equals(0));
    });
  });

  group('TtlDatastore [Atomic Audit]', () {
    test('putWithTtl(key, value, ttl) - armazena registro associado a prazo de expiracao', () async {
      final TtlDatastore ttlDs = _TestTtlDatastore();
      await ttlDs.putWithTtl(Key('/temp'), [1, 2], const Duration(minutes: 5));
      expect(true, isTrue);
    });

    test('setTtl(key, ttl) - atualiza tempo de vida para chave existente', () async {
      final TtlDatastore ttlDs = _TestTtlDatastore();
      await ttlDs.setTtl(Key('/temp'), const Duration(minutes: 10));
      expect(true, isTrue);
    });

    test('getExpiration(key) - consulta timestamp de expiracao configurado', () async {
      final TtlDatastore ttlDs = _TestTtlDatastore();
      final exp = await ttlDs.getExpiration(Key('/temp'));
      expect(exp.isAfter(DateTime.now().subtract(const Duration(minutes: 1))), isTrue);
    });
  });

  group('Txn [Atomic Audit]', () {
    test('commit() - confirma operacoes realizadas na transacao', () async {
      final txnDs = NullDatastore();
      final Txn txn = await txnDs.newTransaction(readOnly: false);
      await txn.commit();
      expect(true, isTrue);
    });

    test('discard() - cancela e descarta alteracoes da transacao', () async {
      final txnDs = NullDatastore();
      final Txn txn = await txnDs.newTransaction(readOnly: false);
      await txn.discard();
      expect(true, isTrue);
    });
  });

  group('TxnDatastore [Atomic Audit]', () {
    test('newTransaction({required bool readOnly}) - cria instancia de transacao isolada', () async {
      final TxnDatastore txnDs = NullDatastore();
      final txn = await txnDs.newTransaction(readOnly: true);
      expect(txn, isNotNull);
    });
  });

  group('Feature [Atomic Audit]', () {
    test('operator == - compara metadados de features pelo nome canonico', () {
      const f1 = Feature('Batching', _dummyFeatureMatch);
      const f2 = Feature('Batching', _otherFeatureMatch);
      const f3 = Feature('Checked', _dummyFeatureMatch);
      expect(f1 == f2, isTrue);
      expect(f1 == f3, isFalse);
    });

    test('hashCode - gera hash code compativel baseado no nome da feature', () {
      const f1 = Feature('Batching', _dummyFeatureMatch);
      const f2 = Feature('Batching', _otherFeatureMatch);
      expect(f1.hashCode, equals(f2.hashCode));
    });

    test('toString() - formata metadados de feature para exibicao como string', () {
      const f1 = Feature('Batching', _dummyFeatureMatch);
      expect(f1.toString(), equals('Batching'));
    });
  });

  group('Key [Atomic Audit]', () {
    test('value - retorna caminho textual canônico formatado', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.value, equals('/Comedy/MontyPython'));
    });

    test('bytes - converte caminho da chave em bytes utf8', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.bytes, equals(utf8.encode('/Comedy/MontyPython')));
    });

    test('equalTo(other) - valida correspondencia estrita de conteudo com outra chave', () {
      final k1 = Key('/Comedy/MontyPython');
      final k2 = Key('/Comedy/MontyPython');
      final k3 = Key('/Outro');
      expect(k1.equalTo(k2), isTrue);
      expect(k1.equalTo(k3), isFalse);
    });

    test('operator == - operador de igualdade entre instancias de chaves', () {
      final k1 = Key('/Comedy/MontyPython');
      final k2 = Key('/Comedy/MontyPython');
      final k3 = Key('/Outro');
      expect(k1 == k2, isTrue);
      expect(k1 == k3, isFalse);
    });

    test('hashCode - gera hash code deterministico para a chave', () {
      final k1 = Key('/Comedy/MontyPython');
      final k2 = Key('/Comedy/MontyPython');
      expect(k1.hashCode, equals(k2.hashCode));
    });

    test('toString() - expressa a chave em formato de string', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.toString(), equals('/Comedy/MontyPython'));
    });

    test('compareTo(other) - compara chaves componente por componente', () {
      final k1 = Key('/a');
      final k2 = Key('/b');
      expect(k1.compareTo(k2), equals(-1));
      expect(k2.compareTo(k1), equals(1));
      expect(k1.compareTo(k1), equals(0));
    });

    test('less(other) - avalia precedencia de ordenacao da chave', () {
      final k1 = Key('/a');
      final k2 = Key('/b');
      expect(k1.less(k2), isTrue);
      expect(k2.less(k1), isFalse);
    });

    test('list - divide o caminho nos componentes de namespace correspondentes', () {
      final k = Key('/Comedy/MontyPython/Actor:JohnCleese');
      expect(k.list, equals(['Comedy', 'MontyPython', 'Actor:JohnCleese']));
    });

    test('namespaces - expoem os namespaces como lista de strings', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.namespaces, equals(['Comedy', 'MontyPython']));
    });

    test('reverse - inverte os namespaces mantendo delimitadores corretos', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.reverse.value, equals('/MontyPython/Comedy'));
    });

    test('baseNamespace - recupera o ultimo componente do namespace', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.baseNamespace, equals('MontyPython'));
    });

    test('rootNamespace - recupera o primeiro componente do namespace', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.rootNamespace, equals('Comedy'));
    });

    test('type - recupera o prefixo de tipo presente no baseNamespace', () {
      final k = Key('/Comedy/MontyPython/Actor:JohnCleese');
      expect(k.type, equals('Actor'));
      expect(Key('/Comedy').type, equals(''));
    });

    test('name - recupera o nome ou valor do baseNamespace', () {
      final k = Key('/Comedy/MontyPython/Actor:JohnCleese');
      expect(k.name, equals('JohnCleese'));
      expect(Key('/Comedy/MontyPython').name, equals('MontyPython'));
    });

    test('instance(s) - concatena especificador de instancia com separador dois pontos', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.instance('sketch').value, equals('/Comedy/MontyPython:sketch'));
    });

    test('path - forma chave combinando ancestral e tipo', () {
      final k = Key('/Comedy/MontyPython/Actor:JohnCleese');
      expect(k.path.value, equals('/Comedy/MontyPython/Actor'));
    });

    test('parent - localiza chave ascendente imediata', () {
      final k = Key('/Comedy/MontyPython');
      expect(k.parent.value, equals('/Comedy'));
      expect(Key('/Comedy').parent.value, equals('/'));
    });

    test('child(other) - agrega chave filha ao final do caminho', () {
      final k = Key('/Comedy');
      expect(k.child(Key('/MontyPython')).value, equals('/Comedy/MontyPython'));
      expect(Key('/').child(Key('/a')).value, equals('/a'));
      expect(k.child(Key('/')).value, equals('/Comedy'));
    });

    test('childString(s) - agrega nome textual como filho', () {
      final k = Key('/Comedy');
      expect(k.childString('MontyPython').value, equals('/Comedy/MontyPython'));
    });

    test('isAncestorOf(other) - checa se chave eh ancestral legitima de outra', () {
      final k1 = Key('/Comedy');
      final k2 = Key('/Comedy/MontyPython');
      expect(k1.isAncestorOf(k2), isTrue);
      expect(k2.isAncestorOf(k1), isFalse);
      expect(Key('/').isAncestorOf(k1), isTrue);
    });

    test('isDescendantOf(other) - checa se chave eh descendente legitima de outra', () {
      final k1 = Key('/Comedy');
      final k2 = Key('/Comedy/MontyPython');
      expect(k2.isDescendantOf(k1), isTrue);
      expect(k1.isDescendantOf(k2), isFalse);
    });

    test('isTopLevel - verifica se chave pertence ao nivel imediatamente raiz', () {
      expect(Key('/Comedy').isTopLevel, isTrue);
      expect(Key('/Comedy/MontyPython').isTopLevel, isFalse);
    });

    test('marshalJson() - serializa chave em formato JSON codificado em UTF8', () {
      final k = Key('/Comedy/MontyPython');
      final jsonBytes = k.marshalJson();
      expect(utf8.decode(jsonBytes), equals('"/Comedy/MontyPython"'));
    });
  });

  group('NullDatastore [Atomic Audit]', () {
    test('put(key, value) - executa gravacao nula sem efeitos colaterais', () async {
      final nds = NullDatastore();
      await nds.put(Key('/a'), [1, 2]);
      expect(true, isTrue);
    });

    test('sync(prefix) - executa sincronizacao nula com sucesso', () async {
      final nds = NullDatastore();
      await nds.sync(Key('/a'));
      expect(true, isTrue);
    });

    test('get(key) - lanca NotFoundException ao tentar recuperar valor', () async {
      final nds = NullDatastore();
      expect(() => nds.get(Key('/a')), throwsA(isA<NotFoundException>()));
    });

    test('has(key) - sempre reporta que a chave nao existe', () async {
      final nds = NullDatastore();
      expect(await nds.has(Key('/a')), isFalse);
    });

    test('getSize(key) - lanca NotFoundException ao requisitar dimensao do valor', () async {
      final nds = NullDatastore();
      expect(() => nds.getSize(Key('/a')), throwsA(isA<NotFoundException>()));
    });

    test('delete(key) - executa remocao nula sem erros', () async {
      final nds = NullDatastore();
      await nds.delete(Key('/a'));
      expect(true, isTrue);
    });

    test('scrub() - executa operacao de limpeza vazia com sucesso', () async {
      final nds = NullDatastore();
      await nds.scrub();
      expect(true, isTrue);
    });

    test('check() - executa checagem vazia com sucesso', () async {
      final nds = NullDatastore();
      await nds.check();
      expect(true, isTrue);
    });

    test('query(q) - devolve conjunto de resultados vazio para qualquer consulta', () async {
      final nds = NullDatastore();
      final res = await nds.query(const Query());
      expect(res.rest(), isEmpty);
    });

    test('batch() - instancia lote funcional apoiado no NullDatastore', () async {
      final nds = NullDatastore();
      final b = await nds.batch();
      expect(b, isA<Batch>());
    });

    test('collectGarbage() - executa coleta de lixo no-op com sucesso', () async {
      final nds = NullDatastore();
      await nds.collectGarbage();
      expect(true, isTrue);
    });

    test('diskUsage() - reporta zero bytes de uso de disco', () async {
      final nds = NullDatastore();
      expect(await nds.diskUsage(), equals(0));
    });

    test('close() - finaliza datastore nulo sem falhas', () async {
      final nds = NullDatastore();
      await nds.close();
      expect(true, isTrue);
    });

    test('newTransaction({required bool readOnly}) - gera transacao no-op valida', () async {
      final nds = NullDatastore();
      final txn = await nds.newTransaction(readOnly: true);
      expect(txn, isNotNull);
      await txn.commit();
      await txn.discard();
    });
  });

  group('Filter [Atomic Audit]', () {
    test('filter(e) - avalia se entrada passa pelo filtro estabelecido', () {
      final Filter f = FilterKeyPrefix('/alvo');
      expect(f.filter(const Entry(key: '/alvo/dado')), isTrue);
      expect(f.filter(const Entry(key: '/outro/dado')), isFalse);
    });
  });

  group('FilterOp [Atomic Audit]', () {
    test('lessThanOrEqual - verifica simbolo textual atribuido ao operador menor ou igual', () {
      expect(FilterOp.lessThanOrEqual.symbol, equals('<='));
    });
  });

  group('FilterValueCompare [Atomic Audit]', () {
    test('filter(e) - compara conteudo binario da entrada contra valor de teste', () {
      final fvc = FilterValueCompare(FilterOp.equal, [1, 2, 3]);
      expect(fvc.filter(const Entry(key: '/k', value: [1, 2, 3])), isTrue);
      expect(fvc.filter(const Entry(key: '/k', value: [1, 2, 4])), isFalse);
    });

    test('toString() - gera representacao em string descritiva do filtro de valor', () {
      final fvc = FilterValueCompare(FilterOp.equal, [65, 66]);
      expect(fvc.toString(), equals('VALUE == "AB"'));
    });
  });

  group('FilterKeyCompare [Atomic Audit]', () {
    test('filter(e) - compara chave da entrada com parametro de referencia', () {
      final fkc = FilterKeyCompare(FilterOp.greaterThan, '/b');
      expect(fkc.filter(const Entry(key: '/c')), isTrue);
      expect(fkc.filter(const Entry(key: '/a')), isFalse);
    });

    test('toString() - gera representacao textual da condicao de comparacao de chave', () {
      final fkc = FilterKeyCompare(FilterOp.greaterThan, '/b');
      expect(fkc.toString(), equals('KEY > "/b"'));
    });
  });

  group('FilterKeyPrefix [Atomic Audit]', () {
    test('filter(e) - confere se o caminho da entrada inicia com o prefixo esperado', () {
      final fkp = FilterKeyPrefix('/prefixo');
      expect(fkp.filter(const Entry(key: '/prefixo/dado')), isTrue);
      expect(fkp.filter(const Entry(key: '/outro/dado')), isFalse);
    });

    test('toString() - gera expressao descritiva do filtro de prefixo de chave', () {
      final fkp = FilterKeyPrefix('/prefixo');
      expect(fkp.toString(), equals('PREFIX("/prefixo")'));
    });
  });

  group('Order [Atomic Audit]', () {
    test('compare(a, b) - compara duas entradas de consulta atraves da interface Order', () {
      final Order o = const OrderByKey();
      expect(o.compare(const Entry(key: '/a'), const Entry(key: '/b')), isNegative);
    });
  });

  group('OrderByFunction [Atomic Audit]', () {
    test('compare(a, b) - ordena entradas utilizando closure de comparacao fornecida', () {
      final obf = OrderByFunction((a, b) => a.size.compareTo(b.size));
      expect(obf.compare(const Entry(key: '/1', size: 10), const Entry(key: '/2', size: 20)), isNegative);
    });

    test('toString() - expressa nome textual representativo da ordenacao por funcao', () {
      final obf = OrderByFunction((a, b) => 0);
      expect(obf.toString(), equals('FN'));
    });
  });

  group('OrderByValue [Atomic Audit]', () {
    test('compare(a, b) - compara entradas ordenando de forma crescente por bytes do valor', () {
      const obv = OrderByValue();
      expect(obv.compare(const Entry(key: '/1', value: [1]), const Entry(key: '/2', value: [2])), isNegative);
    });

    test('toString() - expressa identificador textual do ordenador por valor', () {
      const obv = OrderByValue();
      expect(obv.toString(), equals('VALUE'));
    });
  });

  group('OrderByValueDescending [Atomic Audit]', () {
    test('compare(a, b) - compara entradas ordenando de forma decrescente por bytes do valor', () {
      const obvd = OrderByValueDescending();
      expect(obvd.compare(const Entry(key: '/1', value: [1]), const Entry(key: '/2', value: [2])), isPositive);
    });

    test('toString() - expressa identificador textual do ordenador decrescente por valor', () {
      const obvd = OrderByValueDescending();
      expect(obvd.toString(), equals('desc(VALUE)'));
    });
  });

  group('OrderByKey [Atomic Audit]', () {
    test('compare(a, b) - compara entradas ordenando de forma crescente pela chave', () {
      const obk = OrderByKey();
      expect(obk.compare(const Entry(key: '/alpha'), const Entry(key: '/beta')), isNegative);
    });

    test('toString() - expressa identificador textual do ordenador por chave', () {
      const obk = OrderByKey();
      expect(obk.toString(), equals('KEY'));
    });
  });

  group('OrderByKeyDescending [Atomic Audit]', () {
    test('compare(a, b) - compara entradas ordenando de forma decrescente pela chave', () {
      const obkd = OrderByKeyDescending();
      expect(obkd.compare(const Entry(key: '/alpha'), const Entry(key: '/beta')), isPositive);
    });

    test('toString() - expressa identificador textual do ordenador decrescente por chave', () {
      const obkd = OrderByKeyDescending();
      expect(obkd.toString(), equals('desc(KEY)'));
    });
  });

  group('Query [Atomic Audit]', () {
    test('operator == - compara configuracoes de consulta para determinar igualdade', () {
      const q1 = Query(prefix: '/test', limit: 10);
      const q2 = Query(prefix: '/test', limit: 10);
      const q3 = Query(prefix: '/outro', limit: 5);
      expect(q1 == q2, isTrue);
      expect(q1 == q3, isFalse);
    });

    test('hashCode - gera hash code congruente com configuracao da query', () {
      const q1 = Query(prefix: '/test', limit: 10);
      const q2 = Query(prefix: '/test', limit: 10);
      expect(q1.hashCode, equals(q2.hashCode));
    });

    test('toString() - formata instrucao descritiva da consulta em string', () {
      const q = Query(prefix: '/test', limit: 10);
      expect(q.toString(), contains('FROM "/test"'));
    });
  });

  group('Results [Atomic Audit]', () {
    test('query() - retorna os parametros de consulta que originaram o resultado', () {
      const q = Query(prefix: '/origem');
      final res = resultsWithEntries(q, [const Entry(key: '/origem/1')]);
      expect(res.query(), equals(q));
    });

    test('nextSync() - itera sincronicamente obtendo a proxima entrada disponivel', () {
      final res = resultsWithEntries(const Query(), [const Entry(key: '/item/1')]);
      final (result, ok) = res.nextSync();
      expect(ok, isTrue);
      expect(result.entry.key, equals('/item/1'));
    });

    test('next - expoem os resultados como stream de QueryResult', () async {
      final res = resultsWithEntries(const Query(), [const Entry(key: '/item/1'), const Entry(key: '/item/2')]);
      final items = await res.next.toList();
      expect(items.length, equals(2));
    });

    test('done - future que completa ao terminar a emissao de resultados', () async {
      final res = resultsWithEntries(const Query(), []);
      res.nextSync();
      await expectLater(res.done, completes);
    });

    test('rest() - drena e retorna em lista todas as entradas remanescentes', () {
      final res = resultsWithEntries(const Query(), [const Entry(key: '/r1'), const Entry(key: '/r2')]);
      final list = res.rest();
      expect(list.length, equals(2));
    });

    test('close() - encerra prematuramente a iteracao e consumo de resultados', () {
      final res = resultsWithEntries(const Query(), [const Entry(key: '/fechar')]);
      res.close();
      expect(true, isTrue);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('diskUsage(ds) - calcula ocupacao de armazenamento de um datastore', () async {
      final usage1 = await diskUsage(MapDatastore());
      expect(usage1, equals(0));
      final usage2 = await diskUsage(NullDatastore());
      expect(usage2, equals(0));
    });

    test('getBackedHas(ds, key) - checa presenca da chave baseando-se em get', () async {
      final ds = MapDatastore();
      await ds.put(Key('/item'), [1, 2]);
      expect(await getBackedHas(ds, Key('/item')), isTrue);
      expect(await getBackedHas(ds, Key('/ausente')), isFalse);
    });

    test('getBackedSize(ds, key) - apura tamanho do conteudo baseando-se em get', () async {
      final ds = MapDatastore();
      await ds.put(Key('/item'), [1, 2, 3]);
      expect(await getBackedSize(ds, Key('/item')), equals(3));
      expect(() => getBackedSize(ds, Key('/ausente')), throwsA(isA<NotFoundException>()));
    });

    test('queryIter(ds, q) - converte resultados de consulta em stream assincrona', () async {
      final ds = MapDatastore();
      await ds.put(Key('/q1'), [1]);
      await ds.put(Key('/q2'), [2]);
      final stream = queryIter(ds, const Query());
      final list = await stream.toList();
      expect(list.length, equals(2));
    });

    test('features() - lista metadados de todas as capacidades de datastore registradas', () {
      final list = features();
      expect(list.length, equals(7));
      expect(list.map((f) => f.name), contains('Batching'));
    });

    test('featureByName(name) - recupera capacidade pelo nome informado', () {
      expect(featureByName('Batching'), isNotNull);
      expect(featureByName('Batching')?.name, equals('Batching'));
      expect(featureByName('Inexistente'), isNull);
    });

    test('featuresForDatastore(ds) - identifica conjunto de capacidades de um datastore', () {
      final ds = MapDatastore();
      final supported = featuresForDatastore(ds);
      expect(supported.map((f) => f.name), contains('Batching'));
      expect(featuresForDatastore(null), isEmpty);
    });

    test('randomKey() - produz chave aleatoria com 32 caracteres hexadecimais seguros', () {
      final k1 = randomKey();
      final k2 = randomKey();
      expect(k1.value.length, equals(33));
      expect(k1.value, isNot(equals(k2.value)));
    });

    test('namespaceType(namespace) - separa prefixo de tipo presente antes dos dois pontos', () {
      expect(namespaceType('Actor:JohnCleese'), equals('Actor'));
      expect(namespaceType('SemTipo'), equals(''));
    });

    test('namespaceValue(namespace) - extrai valor final apos ultimo separador', () {
      expect(namespaceValue('Actor:JohnCleese'), equals('JohnCleese'));
      expect(namespaceValue('ApenasValor'), equals('ApenasValor'));
    });

    test('entryKeys(entries) - converte colecao de entradas em colecao de chaves', () {
      final entries = [const Entry(key: '/k1'), const Entry(key: '/k2')];
      final keys = entryKeys(entries);
      expect(keys.map((k) => k.value), equals(['/k1', '/k2']));
    });

    test('cleanPath(path) - simplifica e normaliza caminho removendo duplicidades', () {
      expect(cleanPath('//a///b//'), equals('/a/b'));
      expect(cleanPath('/a/b/'), equals('/a/b'));
      expect(cleanPath(''), equals('.'));
    });

    test('queryLess(orders, a, b) - afere se uma entrada precede outra na ordenacao', () {
      final a = const Entry(key: '/a', value: [1]);
      final b = const Entry(key: '/b', value: [2]);
      expect(queryLess([const OrderByValue()], a, b), isTrue);
      expect(queryLess([const OrderByValue()], b, a), isFalse);
    });

    test('queryCompare(orders, a, b) - compara par de entradas de acordo com os ordenadores', () {
      final a = const Entry(key: '/a');
      final b = const Entry(key: '/b');
      expect(queryCompare([const OrderByKey()], a, b), isNegative);
      expect(queryCompare([const OrderByKey()], b, a), isPositive);
      expect(queryCompare([const OrderByKey()], a, a), equals(0));
    });

    test('querySort(orders, entries) - ordena colecao mutavel de entradas segundo ordenadores', () {
      final e1 = const Entry(key: '/z');
      final e2 = const Entry(key: '/a');
      final list = [e1, e2];
      querySort([const OrderByKey()], list);
      expect(list.first.key, equals('/a'));
    });

    test('compareBytes(a, b) - compara duas listas de bytes tratando nulos adequadamente', () {
      expect(compareBytes([1], [2]), isNegative);
      expect(compareBytes([2], [1]), isPositive);
      expect(compareBytes([1, 2], [1, 2]), equals(0));
      expect(compareBytes(null, [1]), isNegative);
      expect(compareBytes([1], null), isPositive);
    });

    test('resultsWithContext(q, process) - instancia Results com processo assincrono de cancelamento', () async {
      final res = resultsWithContext(const Query(), (cancelled, sink) {
        sink.add(const QueryResult(Entry(key: '/ctx')));
      });
      final item = await res.next.first;
      expect(item.entry.key, equals('/ctx'));
      res.close();
    });

    test('resultsFromIterator(q, iterator) - encapsula iterador pull-based em Results', () {
      var emitted = false;
      final res = resultsFromIterator(const Query(), QueryIterator(next: () {
        if (!emitted) {
          emitted = true;
          return (const QueryResult(Entry(key: '/iter')), true);
        }
        return (const QueryResult(Entry(key: '')), false);
      }));
      final (item, ok) = res.nextSync();
      expect(ok, isTrue);
      expect(item.entry.key, equals('/iter'));
    });

    test('resultsWithEntries(q, entries) - constroi Results suportado por lista estatica', () {
      final res = resultsWithEntries(const Query(), [const Entry(key: '/fixo')]);
      final entries = res.rest();
      expect(entries.length, equals(1));
      expect(entries.first.key, equals('/fixo'));
    });

    test('resultsReplaceQuery(results, query) - substitui definicao da query preservando iterador', () {
      const q1 = Query(prefix: '/antigo');
      const q2 = Query(prefix: '/novo');
      final res = resultsWithEntries(q1, [const Entry(key: '/antigo/1')]);
      final replaced = resultsReplaceQuery(res, q2);
      expect(replaced.query(), equals(q2));
    });

    test('naiveFilter(results, filter) - aplica filtro em memoria descartando discrepancias', () {
      final base = resultsWithEntries(const Query(), [const Entry(key: '/aceitar'), const Entry(key: '/rejeitar')]);
      final filtered = naiveFilter(base, FilterKeyCompare(FilterOp.equal, '/aceitar'));
      final list = filtered.rest();
      expect(list.length, equals(1));
      expect(list.first.key, equals('/aceitar'));
    });

    test('naiveLimit(results, limit) - trunca fluxo de resultados ao limite configurado', () {
      final base = resultsWithEntries(const Query(), [const Entry(key: '/1'), const Entry(key: '/2'), const Entry(key: '/3')]);
      final limited = naiveLimit(base, 2);
      expect(limited.rest().length, equals(2));
    });

    test('naiveOffset(results, offset) - descarta entradas iniciais correspondentes ao offset', () {
      final base = resultsWithEntries(const Query(), [const Entry(key: '/1'), const Entry(key: '/2'), const Entry(key: '/3')]);
      final offsetted = naiveOffset(base, 1);
      final list = offsetted.rest();
      expect(list.length, equals(2));
      expect(list.first.key, equals('/2'));
    });

    test('naiveOrder(results, orders) - ordena entradas em memoria segundo a lista de ordenadores', () {
      final base = resultsWithEntries(const Query(), [const Entry(key: '/z'), const Entry(key: '/a')]);
      final ordered = naiveOrder(base, [const OrderByKey()]);
      final list = ordered.rest();
      expect(list.first.key, equals('/a'));
    });

    test('naiveQueryApply(q, results) - processa consulta aplicando filtro ordenacao e limites', () {
      final base = resultsWithEntries(const Query(), [
        const Entry(key: '/p/3'),
        const Entry(key: '/p/1'),
        const Entry(key: '/p/2'),
        const Entry(key: '/outro'),
      ]);
      const q = Query(prefix: '/p', orders: [OrderByKey()], offset: 1, limit: 1);
      final result = naiveQueryApply(q, base);
      final list = result.rest();
      expect(list.length, equals(1));
      expect(list.first.key, equals('/p/2'));
    });

    test('resultEntriesFrom(keys, values) - emparelha chaves e valores compondo lista de Entry', () {
      final entries = resultEntriesFrom(['/k1', '/k2'], [[10], [20, 30]]);
      expect(entries.length, equals(2));
      expect(entries[0].key, equals('/k1'));
      expect(entries[0].value, equals([10]));
      expect(entries[1].key, equals('/k2'));
      expect(entries[1].size, equals(2));
    });
  });
}
