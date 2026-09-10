import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart' hide Matcher;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/fluent/qp.dart';
import 'package:transpiled_ipld_prime/src/codec/dagjson/codec.dart' as dagjson;
import 'package:transpiled_ipld_prime/src/codec/json/codec.dart' as json_codec;
import 'package:transpiled_ipld_prime/src/codec/raw/codec.dart' as raw_codec;
import 'package:transpiled_ipld_prime/src/linking/cid/cid_link.dart';
import 'package:transpiled_ipld_prime/src/linking/cid/link_system.dart' as cid_ls;
import 'package:transpiled_ipld_prime/src/linking/linking.dart';
import 'package:transpiled_ipld_prime/src/multicodec/registry.dart' as reg;
import 'package:transpiled_ipld_prime/src/storage/memstore.dart';
import 'package:transpiled_ipld_prime/src/storage/storage.dart' as stor;
import 'package:transpiled_ipld_prime/src/traversal/selector/selector.dart' as sel;
import 'package:transpiled_ipld_prime/src/traversal/traversal.dart' as trav;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

class _TestByteSeeker implements ByteReadSeeker {
  _TestByteSeeker(this._data);
  final Uint8List _data;
  int _pos = 0;

  @override
  int read(Uint8List buffer) {
    if (_pos >= _data.length) return 0;
    var count = 0;
    while (_pos < _data.length && count < buffer.length) {
      buffer[count++] = _data[_pos++];
    }
    return count;
  }

  @override
  int seek(int offset, SeekOrigin origin) {
    switch (origin) {
      case SeekOrigin.start:
        _pos = offset;
      case SeekOrigin.current:
        _pos += offset;
      case SeekOrigin.end:
        _pos = _data.length + offset;
    }
    return _pos;
  }
}

class _TestAmendPrototype implements NodePrototypeSupportingAmend {
  @override
  NodeBuilder amendingBuilder(Node base) => const PrototypeMap().newBuilder();
}

class _TestStreamingWritableStore implements stor.StreamingWritableStorage, stor.Storage {
  final Map<String, Uint8List> data = {};
  @override
  bool has(Object? context, String key) => data.containsKey(key);
  @override
  (Sink<List<int>>, stor.WriteCommitter) putStream(Object? context) {
    final bytes = <int>[];
    final sink = StreamControllerSink([bytes]);
    return (sink, (key) => data[key] = Uint8List.fromList(bytes));
  }
}

class _TestVectorWritableStore implements stor.VectorWritableStorage, stor.Storage {
  final Map<String, Uint8List> data = {};
  @override
  bool has(Object? context, String key) => data.containsKey(key);
  @override
  void putVec(Object? context, String key, List<Uint8List> blobs) {
    data[key] = Uint8List.fromList(blobs.expand((b) => b).toList());
  }
}

void main() {
  final dummyCid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
  final testLink = CidLink(dummyCid);
  Prefix makeRawPrefix() => Prefix(version: 1, codec: 'raw', mhType: 'sha2-256', mhLength: 32);

  group('Top-Level Functions [Atomic Audit]', () {
    test('buildMap() - constroi mapa fluentemente com callback sem erros', () {
      final (res, err) = buildMap(const PrototypeMap(), 1, (ma) {
        mapEntry(ma, 'foo', stringValue('bar'));
      });
      expect(err, isNull);
      expect(res, isNotNull);
      expect(res!.lookupByString('foo').asString(), equals('bar'));
    });

    test('map() - cria assemble de mapa para montar entradas', () {
      final fn = map(1, (ma) {
        mapEntry(ma, 'k', intValue(42));
      });
      final b = const PrototypeMap().newBuilder();
      fn(b);
      final n = b.build();
      expect(n.lookupByString('k').asInt(), equals(42));
    });

    test('mapEntry() - adiciona uma chave string ao assembler de mapa', () {
      final b = const PrototypeMap().newBuilder();
      final ma = b.beginMap(1);
      mapEntry(ma, 'key1', boolValue(true));
      ma.finish();
      final n = b.build();
      expect(n.lookupByString('key1').asBool(), isTrue);
    });

    test('buildList() - constroi lista fluentemente com callback sem erros', () {
      final (res, err) = buildList(const PrototypeList(), 2, (la) {
        listEntry(la, intValue(10));
        listEntry(la, intValue(20));
      });
      expect(err, isNull);
      expect(res, isNotNull);
      expect(res!.length(), equals(2));
      expect(res.lookupByIndex(0).asInt(), equals(10));
      expect(res.lookupByIndex(1).asInt(), equals(20));
    });

    test('list() - cria assemble de lista para montar valores', () {
      final fn = list(1, (la) {
        listEntry(la, floatValue(3.14));
      });
      final b = const PrototypeList().newBuilder();
      fn(b);
      final n = b.build();
      expect(n.lookupByIndex(0).asFloat(), closeTo(3.14, 0.001));
    });

    test('listEntry() - adiciona um elemento a lista fluente', () {
      final b = const PrototypeList().newBuilder();
      final la = b.beginList(1);
      listEntry(la, nullValue());
      la.finish();
      final n = b.build();
      expect(n.lookupByIndex(0).isNull(), isTrue);
    });

    test('nullValue() - define valor nulo em assemble', () {
      final b = const PrototypeAny().newBuilder();
      nullValue()(b);
      expect(b.build().isNull(), isTrue);
    });

    test('boolValue() - define booleano em assemble', () {
      final b = const PrototypeBool().newBuilder();
      boolValue(true)(b);
      expect(b.build().asBool(), isTrue);
    });

    test('intValue() - define inteiro em assemble', () {
      final b = const PrototypeInt().newBuilder();
      intValue(99)(b);
      expect(b.build().asInt(), equals(99));
    });

    test('floatValue() - define ponto flutuante em assemble', () {
      final b = const PrototypeFloat().newBuilder();
      floatValue(2.5)(b);
      expect(b.build().asFloat(), equals(2.5));
    });

    test('stringValue() - define string em assemble', () {
      final b = const PrototypeString().newBuilder();
      stringValue('ipld')(b);
      expect(b.build().asString(), equals('ipld'));
    });

    test('bytes() - define bytes em assemble', () {
      final b = const PrototypeBytes().newBuilder();
      bytes([1, 2, 3])(b);
      expect(b.build().asBytes(), equals([1, 2, 3]));
    });

    test('link() - define link em assemble', () {
      final b = const PrototypeLink().newBuilder();
      link(testLink)(b);
      expect(b.build().asLink(), equals(testLink));
    });

    test('node() - copia no existente para o assemble', () {
      final b = const PrototypeInt().newBuilder();
      node(const PlainInt(77))(b);
      expect(b.build().asInt(), equals(77));
    });

    test('copyNode() - copia recursiva entre nos com sucesso', () {
      final src = const PlainString('copy me');
      final b = const PrototypeString().newBuilder();
      copyNode(src, b);
      expect(b.build().asString(), equals('copy me'));
    });

    test('deepEqual() - compara recursivamente a igualdade de dois nos', () {
      expect(deepEqual(const PlainInt(10), const PlainInt(10)), isTrue);
      expect(deepEqual(const PlainInt(10), const PlainInt(20)), isFalse);
    });

    test('registerEncoder() - registra encoder globalmente', () {
      reg.registerEncoder(0x7777, (node, sink) => sink.add([1, 2]));
      expect(reg.listEncoders(), contains(0x7777));
    });

    test('lookupEncoder() - busca encoder registrado globalmente', () {
      final enc = reg.lookupEncoder(0x7777);
      expect(enc, isNotNull);
    });

    test('listEncoders() - lista todos encoders registrados globalmente', () {
      final list = reg.listEncoders();
      expect(list, isNotEmpty);
    });

    test('registerDecoder() - registra decoder globalmente', () {
      reg.registerDecoder(0x7777, (assembler, reader) => assembler.assignInt(123));
      expect(reg.listDecoders(), contains(0x7777));
    });

    test('lookupDecoder() - busca decoder registrado globalmente', () {
      final dec = reg.lookupDecoder(0x7777);
      expect(dec, isNotNull);
    });

    test('listDecoders() - lista todos decoders registrados globalmente', () {
      final list = reg.listDecoders();
      expect(list, isNotEmpty);
    });

    test('has() - helper global de verificacao em storage', () {
      final ms = MemoryStore();
      ms.put(null, 'k1', Uint8List.fromList([1]));
      expect(stor.has(null, ms, 'k1'), isTrue);
      expect(stor.has(null, ms, 'unknown'), isFalse);
    });

    test('get() - helper global de leitura de storage', () {
      final ms = MemoryStore();
      ms.put(null, 'k2', Uint8List.fromList([42]));
      expect(stor.get(null, ms, 'k2'), equals(Uint8List.fromList([42])));
    });

    test('put() - helper global de gravacao em storage', () {
      final ms = MemoryStore();
      stor.put(null, ms, 'k3', Uint8List.fromList([99]));
      expect(ms.has(null, 'k3'), isTrue);
    });

    test('getStream() - helper global de leitura em stream', () {
      final ms = MemoryStore();
      ms.put(null, 'k4', Uint8List.fromList([1, 2, 3]));
      expect(stor.getStream(null, ms, 'k4'), equals([1, 2, 3]));
    });

    test('putStream() - helper global de escrita em stream', () {
      final ms = MemoryStore();
      final (sink, commit) = stor.putStream(null, ms);
      sink.add([7, 8]);
      commit('k5');
      expect(ms.get(null, 'k5'), equals(Uint8List.fromList([7, 8])));
    });

    test('putVec() - helper global de gravacao vetorial', () {
      final ms = MemoryStore();
      stor.putVec(null, ms, 'k6', [Uint8List.fromList([1, 2]), Uint8List.fromList([3, 4])]);
      expect(ms.get(null, 'k6'), equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('peek() - helper global de inspecao sem consumo', () {
      final ms = MemoryStore();
      ms.put(null, 'k7', Uint8List.fromList([55]));
      expect(stor.peek(null, ms, 'k7'), equals(Uint8List.fromList([55])));
    });

    test('walkLocal() - percorre localmente um no ipld', () {
      var visited = 0;
      trav.walkLocal(const PlainInt(5), (progress, node) {
        visited++;
        expect(node.asInt(), equals(5));
      });
      expect(visited, equals(1));
    });

    test('walkMatching() - percorre no com seletor de correspondencia', () {
      var count = 0;
      trav.walkMatching(const PlainInt(8), const sel.Matcher(), (progress, node) {
        count++;
        expect(node.asInt(), equals(8));
      });
      expect(count, equals(1));
    });

    test('walkAdv() - executa caminhada avancada com visit reason', () {
      var reasonSeen = false;
      trav.walkAdv(const PlainInt(9), const sel.Matcher(), (progress, node, reason) {
        reasonSeen = true;
        expect(reason, equals(trav.VisitReason.selectionMatch));
      });
      expect(reasonSeen, isTrue);
    });

    test('walkTransforming() - transforma valores durante caminhada', () {
      final result = trav.walkTransforming(const PlainInt(10), const sel.Matcher(), (progress, node) {
        return const PlainInt(20);
      });
      expect(result.asInt(), equals(20));
    });

    test('focus() - foca caminhada em um path especifico', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) {
        mapEntry(ma, 'a', intValue(100));
      });
      var focused = false;
      trav.focus(mapNode!, Path.parse('a'), (progress, node) {
        focused = true;
        expect(node.asInt(), equals(100));
      });
      expect(focused, isTrue);
    });

    test('get() - busca no diretamente por caminho', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) {
        mapEntry(ma, 'target', stringValue('hit'));
      });
      final found = trav.get(mapNode!, Path.parse('target'));
      expect(found.asString(), equals('hit'));
    });

    test('focusedTransform() - aplica transformacao focada em caminho', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) {
        mapEntry(ma, 'val', intValue(1));
      });
      final transformed = trav.focusedTransform(mapNode!, Path.parse('val'), (prog, node) {
        return const PlainInt(99);
      }, false);
      expect(transformed.lookupByString('val').asInt(), equals(99));
    });

    test('selectLinks() - extrai todos os links contidos em uma arvore de nos', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) {
        mapEntry(ma, 'ln', link(testLink));
      });
      final links = trav.selectLinks(mapNode!);
      expect(links, hasLength(1));
      expect(links.first, equals(testLink));
    });

    test('defaultLinkSystem() - instancia sistema de links padrao', () {
      final ls = cid_ls.defaultLinkSystem();
      expect(ls, isNotNull);
      expect(ls.encoderChooser, isNotNull);
    });

    test('linkSystemUsingMulticodecRegistry() - cria link system com registro customizado', () {
      final r = reg.Registry();
      raw_codec.registerRawCodec(r);
      final ls = cid_ls.linkSystemUsingMulticodecRegistry(r);
      expect(ls, isNotNull);
    });

    test('registerDagJsonCodec() - registra dag-json no registro indicado', () {
      final r = reg.Registry();
      dagjson.registerDagJsonCodec(r);
      expect(r.listEncoders(), contains(0x0129));
      expect(r.listDecoders(), contains(0x0129));
    });

    test('encodeDagJson() - codifica no para dag-json padrao', () {
      final out = <List<int>>[];
      final sink = StreamControllerSink(out);
      dagjson.encodeDagJson(const PlainString('hello'), sink);
      final str = utf8.decode(out.expand((i) => i).toList());
      expect(str, contains('hello'));
    });

    test('encodeDagJsonWithOptions() - codifica no com opcoes dag-json customizadas', () {
      final out = <List<int>>[];
      final sink = StreamControllerSink(out);
      dagjson.encodeDagJsonWithOptions(
        const PlainInt(123),
        sink,
        const dagjson.DagJsonEncodeOptions(sortMaps: false),
      );
      final str = utf8.decode(out.expand((i) => i).toList());
      expect(str, equals('123'));
    });

    test('decodeDagJson() - decodifica dag-json para assembler', () {
      final b = const PrototypeString().newBuilder();
      dagjson.decodeDagJson(b, utf8.encode('"world"'));
      expect(b.build().asString(), equals('world'));
    });

    test('decodeDagJsonWithOptions() - decodifica dag-json com opcoes', () {
      final b = const PrototypeInt().newBuilder();
      dagjson.decodeDagJsonWithOptions(
        b,
        utf8.encode('456'),
        const dagjson.DagJsonDecodeOptions(maxDepth: 10),
      );
      expect(b.build().asInt(), equals(456));
    });

    test('registerJsonCodec() - registra codec json puro', () {
      final r = reg.Registry();
      json_codec.registerJsonCodec(r);
      expect(r.listEncoders(), contains(0x0200));
    });

    test('registerRawCodec() - registra codec raw de bytes puros', () {
      final r = reg.Registry();
      raw_codec.registerRawCodec(r);
      expect(r.listEncoders(), contains(0x55));
    });
  });

  group('LinkSystem [Atomic Audit]', () {
    late LinkSystem ls;
    late MemoryStore store;

    setUp(() {
      ls = cid_ls.defaultLinkSystem();
      store = MemoryStore();
      ls.setReadStorage(store);
      ls.setWriteStorage(store);
    });

    test('setReadStorage() - define storage de leitura no link system', () {
      ls.setReadStorage(store);
      expect(ls.storageReadOpener, isNotNull);
    });

    test('setWriteStorage() - define storage de escrita no link system', () {
      ls.setWriteStorage(store);
      expect(ls.storageWriteOpener, isNotNull);
    });

    test('computeLink() - computa link deterministico do no sem gravar', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.computeLink(proto, PlainBytes(Uint8List.fromList([1, 2, 3])));
      expect(link, isA<CidLink>());
    });

    test('mustComputeLink() - computa link com sucesso', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.mustComputeLink(proto, PlainBytes(Uint8List.fromList([4, 5, 6])));
      expect(link, isNotNull);
    });

    test('store() - grava no no storage e retorna link criado', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([10, 20, 30])));
      expect(link, isNotNull);
      expect(ls.load(const LinkContext(), link, const PrototypeBytes()).asBytes(), equals([10, 20, 30]));
    });

    test('mustStore() - grava no com mustStore', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.mustStore(const LinkContext(), proto, PlainBytes(Uint8List.fromList([40, 50])));
      expect(link, isNotNull);
    });

    test('load() - carrega no do storage reconstruindo o modelo', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([1, 2])));
      final loaded = ls.load(const LinkContext(), link, const PrototypeBytes());
      expect(loaded.asBytes(), equals([1, 2]));
    });

    test('mustLoad() - carrega no com mustLoad', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([3, 4])));
      final loaded = ls.mustLoad(const LinkContext(), link, const PrototypeBytes());
      expect(loaded.asBytes(), equals([3, 4]));
    });

    test('loadRaw() - obtem bytes puros do bloco referenciado', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([7, 8, 9])));
      final raw = ls.loadRaw(const LinkContext(), link);
      expect(raw, equals(Uint8List.fromList([7, 8, 9])));
    });

    test('loadPlusRaw() - carrega no montado juntamente com seus bytes puros', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([11, 12])));
      final (node, raw) = ls.loadPlusRaw(const LinkContext(), link, const PrototypeBytes());
      expect(node.asBytes(), equals([11, 12]));
      expect(raw, equals(Uint8List.fromList([11, 12])));
    });

    test('fill() - preenche assembler a partir de link', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([13, 14])));
      final b = const PrototypeBytes().newBuilder();
      ls.fill(const LinkContext(), link, b);
      expect(b.build().asBytes(), equals([13, 14]));
    });

    test('mustFill() - preenche assembler via mustFill', () {
      final proto = CidLinkPrototype(makeRawPrefix());
      final link = ls.store(const LinkContext(), proto, PlainBytes(Uint8List.fromList([15, 16])));
      final b = const PrototypeBytes().newBuilder();
      ls.mustFill(const LinkContext(), link, b);
      expect(b.build().asBytes(), equals([15, 16]));
    });
  });

  group('Progress [Atomic Audit]', () {
    test('walkMatching() - metodo de instancia do progresso', () {
      final p = trav.Progress();
      var called = false;
      p.walkMatching(const PlainInt(1), const sel.Matcher(), (prog, n) {
        called = true;
      });
      expect(called, isTrue);
    });

    test('walkLocal() - metodo de instancia para varredura local', () {
      final p = trav.Progress();
      var called = false;
      p.walkLocal(const PlainInt(2), (prog, n) {
        called = true;
      });
      expect(called, isTrue);
    });

    test('walkAdv() - metodo de instancia com visit reason', () {
      final p = trav.Progress();
      var called = false;
      p.walkAdv(const PlainInt(3), const sel.Matcher(), (prog, n, reason) {
        called = true;
      });
      expect(called, isTrue);
    });

    test('walkTransforming() - metodo de instancia para transformacao', () {
      final p = trav.Progress();
      final n = p.walkTransforming(const PlainInt(4), const sel.Matcher(), (prog, node) => const PlainInt(40));
      expect(n.asInt(), equals(40));
    });

    test('focus() - metodo de instancia para foco por path', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) => mapEntry(ma, 'z', intValue(7)));
      final p = trav.Progress();
      var called = false;
      p.focus(mapNode!, Path.parse('z'), (prog, node) {
        called = true;
        expect(node.asInt(), equals(7));
      });
      expect(called, isTrue);
    });

    test('get() - metodo de instancia para busca direta', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) => mapEntry(ma, 'w', intValue(8)));
      final p = trav.Progress();
      expect(p.get(mapNode!, Path.parse('w')).asInt(), equals(8));
    });

    test('focusedTransform() - metodo de instancia para transformacao focada', () {
      final (mapNode, _) = buildMap(const PrototypeMap(), 1, (ma) => mapEntry(ma, 'v', intValue(9)));
      final p = trav.Progress();
      final res = p.focusedTransform(mapNode!, Path.parse('v'), (prog, n) => const PlainInt(99), false);
      expect(res.lookupByString('v').asInt(), equals(99));
    });
  });

  group('Registry [Atomic Audit]', () {
    test('registerEncoder() - armazena funcao de encoder', () {
      final r = reg.Registry();
      r.registerEncoder(1, (node, sink) {});
      expect(r.listEncoders(), contains(1));
    });

    test('lookupEncoder() - recupera funcao de encoder', () {
      final r = reg.Registry();
      r.registerEncoder(2, (node, sink) {});
      expect(r.lookupEncoder(2), isNotNull);
    });

    test('listEncoders() - lista chaves de encoders registrados', () {
      final r = reg.Registry();
      r.registerEncoder(3, (node, sink) {});
      expect(r.listEncoders(), equals([3]));
    });

    test('registerDecoder() - armazena funcao de decoder', () {
      final r = reg.Registry();
      r.registerDecoder(10, (assembler, reader) {});
      expect(r.listDecoders(), contains(10));
    });

    test('lookupDecoder() - recupera funcao de decoder', () {
      final r = reg.Registry();
      r.registerDecoder(20, (assembler, reader) {});
      expect(r.lookupDecoder(20), isNotNull);
    });

    test('listDecoders() - lista chaves de decoders registrados', () {
      final r = reg.Registry();
      r.registerDecoder(30, (assembler, reader) {});
      expect(r.listDecoders(), equals([30]));
    });
  });

  group('StreamBytes [Atomic Audit]', () {
    late StreamBytes sb;
    setUp(() {
      sb = StreamBytes(_TestByteSeeker(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('typeName - retorna nome do tipo bytes', () {
      expect(sb.typeName, equals('bytes'));
    });

    test('kind() - retorna Kind bytes', () {
      expect(sb.kind(), equals(Kind.bytes));
    });

    test('asLargeBytes() - expoem ByteReadSeeker subjacente', () {
      final seeker = sb.asLargeBytes();
      expect(seeker, isNotNull);
    });

    test('asBytes() - converte stream para Uint8List completo', () {
      expect(sb.asBytes(), equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('prototype() - retorna prototipo PrototypeBytes', () {
      expect(sb.prototype(), isA<PrototypeBytes>());
    });
  });

  group('MemoryStore [Atomic Audit]', () {
    late MemoryStore ms;
    setUp(() {
      ms = MemoryStore();
    });

    test('put() - grava bytes sob chave string', () {
      ms.put(null, 'k1', Uint8List.fromList([10]));
      expect(ms.has(null, 'k1'), isTrue);
    });

    test('has() - checa existencia de chave', () {
      expect(ms.has(null, 'unknown'), isFalse);
    });

    test('get() - retorna dados salvos', () {
      ms.put(null, 'k2', Uint8List.fromList([20]));
      expect(ms.get(null, 'k2'), equals(Uint8List.fromList([20])));
    });

    test('getStream() - le dados sob forma de stream iteravel', () {
      ms.put(null, 'k3', Uint8List.fromList([30, 40]));
      expect(ms.getStream(null, 'k3'), equals([30, 40]));
    });

    test('peek() - le conteudo sem alterar posicao', () {
      ms.put(null, 'k4', Uint8List.fromList([50]));
      expect(ms.peek(null, 'k4'), equals(Uint8List.fromList([50])));
    });
  });

  group('Selector [Atomic Audit]', () {
    final sel.Selector s = const sel.Matcher();

    test('interests() - retorna lista de segmentos de interesse ou null', () {
      expect(s.interests(), isEmpty);
    });

    test('explore() - avanca seletor para proximo no filho', () {
      expect(s.explore(const PlainInt(1), const PathSegment.ofInt(0)), isNull);
    });

    test('decide() - determina correspondencia do no', () {
      expect(s.decide(const PlainInt(1)), isTrue);
    });

    test('match() - retorna no correspondente', () {
      final n = const PlainInt(5);
      expect(s.match(n), equals(n));
    });
  });

  group('Link and CidLink [Atomic Audit]', () {
    test('Link.prototype() - expoem prototipo de link', () {
      final Link l = testLink;
      expect(l.prototype(), isA<LinkPrototype>());
    });

    test('Link.toString() - formato string do link', () {
      final Link l = testLink;
      expect(l.toString(), contains('bafybei'));
    });

    test('Link.binary() - serializacao binaria do link', () {
      final Link l = testLink;
      expect(l.binary(), isNotEmpty);
    });

    test('CidLink.prototype() - prototipo de cid link', () {
      expect(testLink.prototype(), isA<CidLinkPrototype>());
    });

    test('CidLink.toString() - representacao em string de CidLink', () {
      expect(testLink.toString(), equals(dummyCid.toString()));
    });

    test('CidLink.binary() - representacao binaria de CidLink', () {
      expect(testLink.binary(), equals(dummyCid.toBytes()));
    });
  });

  group('Kind and KindSet [Atomic Audit]', () {
    test('Kind.link - valida enum kind link', () {
      expect(Kind.link, isNotNull);
    });

    test('Kind.toString() - representacao de kind em texto', () {
      expect(Kind.link.toString(), contains('link'));
    });

    test('KindSet.contains() - checa presenca de kind no conjunto', () {
      final ks = KindSet([Kind.link]);
      expect(ks.contains(Kind.link), isTrue);
      expect(ks.contains(Kind.int_), isFalse);
    });

    test('KindSet.toString() - representacao textual de KindSet', () {
      final ks = KindSet([Kind.link]);
      expect(ks.toString(), contains('link'));
    });
  });

  group('ByteReadSeeker and Memory [Atomic Audit]', () {
    test('ByteReadSeeker.read() - le dados para buffer', () {
      final ByteReadSeeker seeker = _TestByteSeeker(Uint8List.fromList([1, 2, 3]));
      final buf = Uint8List(2);
      final n = seeker.read(buf);
      expect(n, equals(2));
      expect(buf, equals([1, 2]));
    });

    test('ByteReadSeeker.seek() - altera posicao do cursor', () {
      final ByteReadSeeker seeker = _TestByteSeeker(Uint8List.fromList([1, 2, 3]));
      final pos = seeker.seek(1, SeekOrigin.start);
      expect(pos, equals(1));
    });

    test('Memory.openRead() - abre leitura em memoria', () {
      final mem = cid_ls.Memory();
      final (sink, commit) = mem.openWrite(const LinkContext());
      sink.add([1, 2, 3]);
      commit(testLink);
      final data = mem.openRead(const LinkContext(), testLink);
      expect(data, equals([1, 2, 3]));
    });

    test('Memory.openWrite() - abre escrita e comita link em memoria', () {
      final mem = cid_ls.Memory();
      final (sink, commit) = mem.openWrite(const LinkContext());
      expect(sink, isNotNull);
      expect(commit, isNotNull);
    });
  });

  group('Exceptions and Storage Interfaces [Atomic Audit]', () {
    test('PlainBytes.asLargeBytes() - le bytes grandes', () {
      final pb = PlainBytes(Uint8List.fromList([1, 2]));
      expect(pb.asLargeBytes().read(Uint8List(2)), equals(2));
    });

    test('LargeBytesNode.asLargeBytes() - interface LargeBytesNode', () {
      final LargeBytesNode lbn = PlainBytes(Uint8List.fromList([3, 4]));
      expect(lbn.asLargeBytes(), isNotNull);
    });

    test('NodePrototypeSupportingAmend.amendingBuilder() - interface amend', () {
      final NodePrototypeSupportingAmend npsa = _TestAmendPrototype();
      expect(npsa.amendingBuilder(const PlainInt(1)), isNotNull);
    });

    test('BudgetExhaustedException.toString() - representacao em texto', () {
      expect(const BudgetExhaustedException().toString(), contains('exhausted'));
    });

    test('WrongKindException.toString() - representacao em texto', () {
      final ex = const WrongKindException(
        methodName: 'asString',
        appropriateKind: KindSet([Kind.string]),
        actualKind: Kind.int_,
      );
      expect(ex.toString(), contains('asString'));
    });

    test('NotExistsException.toString() - representacao em texto', () {
      expect(const NotExistsException(PathSegment.ofString('not found')).toString(), contains('not found'));
    });

    test('RepeatedMapKeyException.toString() - representacao em texto', () {
      expect(const RepeatedMapKeyException('dup').toString(), contains('dup'));
    });

    test('InvalidSegmentForListException.toString() - representacao em texto', () {
      final ex = const InvalidSegmentForListException(
        troubleSegment: PathSegment.ofString('bad'),
      );
      expect(ex.toString(), contains('bad'));
    });

    test('IteratorOverreadException.toString() - representacao em texto', () {
      expect(const IteratorOverreadException().toString(), contains('iterator overread'));
    });

    test('LinkPrototype.buildLink() - interface LinkPrototype', () {
      final LinkPrototype lp = CidLinkPrototype(makeRawPrefix());
      final l = lp.buildLink(Uint8List.fromList([0x12, 0x20, ...List.filled(32, 1)]));
      expect(l, isA<CidLink>());
    });

    test('CidLinkPrototype.buildLink() - constroi link por bytes', () {
      final clp = CidLinkPrototype(makeRawPrefix());
      final l = clp.buildLink(Uint8List.fromList([0x12, 0x20, ...List.filled(32, 2)]));
      expect(l, isA<CidLink>());
    });

    test('LinkingSetupException.toString() - representacao em texto', () {
      expect(LinkingSetupException('err', StateError('x')).toString(), contains('err'));
    });

    test('HashMismatchException.toString() - representacao em texto', () {
      expect(HashMismatchException(testLink, testLink).toString(), contains('hash mismatch'));
    });

    test('Storage.has() - interface Storage', () {
      final stor.Storage s = MemoryStore();
      expect(s.has(null, 'k'), isFalse);
    });

    test('ReadableStorage.get() - interface ReadableStorage', () {
      final stor.ReadableStorage rs = MemoryStore();
      expect(() => rs.get(null, 'k'), throwsA(isA<StateError>()));
    });

    test('WritableStorage.put() - interface WritableStorage', () {
      final stor.WritableStorage ws = MemoryStore();
      ws.put(null, 'k', Uint8List.fromList([1]));
      expect(ws.has(null, 'k'), isTrue);
    });

    test('StreamingReadableStorage.getStream() - interface StreamingReadableStorage', () {
      final stor.StreamingReadableStorage srs = MemoryStore()..put(null, 'k', Uint8List.fromList([1, 2]));
      expect(srs.getStream(null, 'k'), equals([1, 2]));
    });

    test('StreamingWritableStorage.putStream() - interface StreamingWritableStorage', () {
      final stor.StreamingWritableStorage sws = _TestStreamingWritableStore();
      final (sink, commit) = sws.putStream(null);
      sink.add([1]);
      commit('k');
      expect((sws as stor.Storage).has(null, 'k'), isTrue);
    });

    test('VectorWritableStorage.putVec() - interface VectorWritableStorage', () {
      final stor.VectorWritableStorage vws = _TestVectorWritableStore();
      vws.putVec(null, 'k', [Uint8List.fromList([1])]);
      expect((vws as stor.Storage).has(null, 'k'), isTrue);
    });

    test('PeekableStorage.peek() - interface PeekableStorage', () {
      final stor.PeekableStorage ps = MemoryStore()..put(null, 'k', Uint8List.fromList([9]));
      expect(ps.peek(null, 'k'), equals(Uint8List.fromList([9])));
    });

    test('Budget.clone() - clona orcamento', () {
      final b = trav.Budget(nodeBudget: 10, linkBudget: 5);
      final c = b.clone();
      expect(c.nodeBudget, equals(10));
      expect(c.linkBudget, equals(5));
    });

    test('LastBlock.copy() - copia ultimo bloco', () {
      final lb = trav.LastBlock(path: Path.parse('a/b'), link: testLink);
      final c = lb.copy();
      expect(c.path.toString(), equals('a/b'));
      expect(c.link, equals(testLink));
    });

    test('SkipMeException.toString() - representacao em texto', () {
      expect(const trav.SkipMeException().toString(), equals('skip'));
    });

    test('BudgetExceededException.toString() - representacao em texto', () {
      expect(const trav.BudgetExceededException('node', Path.empty).toString(), contains('budget'));
    });

    test('TraversalException.toString() - representacao em texto', () {
      expect(const trav.TraversalException('msg').toString(), equals('msg'));
    });

    test('Condition.applies() - avalia condicao em no', () {
      final c = sel.Condition.link(PlainLink(testLink));
      expect(c.applies(PlainLink(testLink)), isTrue);
      expect(c.applies(const PlainInt(1)), isFalse);
    });

    test('Reifiable.namedReifier - interface Reifiable', () {
      final sel.Reifiable r = sel.ExploreInterpretAs(
        'custom',
        const sel.Matcher(),
      );
      expect(r.namedReifier, equals('custom'));
    });

    test('JsonCodecException.toString() - representacao em texto', () {
      expect(const json_codec.JsonCodecException('json err').toString(), contains('json err'));
    });
  });
}

class StreamControllerSink implements Sink<List<int>> {
  StreamControllerSink(this._out);
  final List<List<int>> _out;

  @override
  void add(List<int> data) {
    _out.add(data);
  }

  @override
  void close() {}
}
