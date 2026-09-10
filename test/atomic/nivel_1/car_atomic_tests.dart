// test/atomic/nivel_1/car_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo go_car (transpiled_go_car).

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_go_car/transpiled_go_car.dart';

void main() {
  group('CarHeader [Atomic Audit]', () {
    test('matches() - compara cabecalhos por versao e raizes ignorando ordenacao', () {
      final cid1 = Cid.computeForDataSync(Uint8List.fromList([1, 2, 3]), codec: 'raw');
      final cid2 = Cid.computeForDataSync(Uint8List.fromList([4, 5, 6]), codec: 'raw');
      final h1 = CarHeader(roots: [cid1, cid2], version: 1);
      final h2 = CarHeader(roots: [cid2, cid1], version: 1);
      expect(h1.matches(h2), isTrue);
      expect(h2.matches(h1), isTrue);
    });

    test('matches() - retorna false quando versoes ou raizes divergem', () {
      final cid1 = Cid.computeForDataSync(Uint8List.fromList([1, 2, 3]), codec: 'raw');
      final cid2 = Cid.computeForDataSync(Uint8List.fromList([4, 5, 6]), codec: 'raw');
      final cid3 = Cid.computeForDataSync(Uint8List.fromList([7, 8, 9]), codec: 'raw');
      final h1 = CarHeader(roots: [cid1], version: 1);
      final hDifferentVersion = CarHeader(roots: [cid1], version: 2);
      final hDifferentLength = CarHeader(roots: [cid1, cid2], version: 1);
      final hDifferentRoot = CarHeader(roots: [cid3], version: 1);

      expect(h1.matches(hDifferentVersion), isFalse);
      expect(h1.matches(hDifferentLength), isFalse);
      expect(h1.matches(hDifferentRoot), isFalse);
    });
  });

  group('CarBlock [Atomic Audit]', () {
    final sampleData = Uint8List.fromList([10, 20, 30, 40]);
    final sampleCid = Cid.computeForDataSync(sampleData, codec: 'raw');

    test('cid() - retorna identificador de conteudo cid do bloco', () {
      final block = CarBlock(sampleCid, sampleData);
      expect(block.cid(), equals(sampleCid));
    });

    test('rawData() - retorna bytes binarios brutos do payload', () {
      final block = CarBlock(sampleCid, sampleData);
      expect(block.rawData(), equals(sampleData));
      expect(identical(block.rawData(), block.data), isTrue);
    });

    test('toString() - formata bloco em representacao legivel contendo cid', () {
      final block = CarBlock(sampleCid, sampleData);
      expect(block.toString(), equals('[Block ${sampleCid.encode()}]'));
    });

    test('loggable() - produz mapa com informacoes estruturadas de diagnostico', () {
      final block = CarBlock(sampleCid, sampleData);
      final log = block.loggable();
      expect(log, containsPair('cid', sampleCid.encode()));
      expect(log, containsPair('length', sampleData.length));
    });
  });

  group('CarIntegrityException [Atomic Audit]', () {
    test('toString() - formata mensagem de erro indicando cid divergente', () {
      final sampleCid = Cid.computeForDataSync(Uint8List.fromList([1, 2, 3]), codec: 'raw');
      final ex = CarIntegrityException(sampleCid);
      expect(ex.toString(), equals('CAR block does not match Cid: $sampleCid'));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
    final sampleCid = Cid.computeForDataSync(payload, codec: 'raw');
    final header = CarHeader(roots: [sampleCid], version: 1);

    test('writeHeader() - serializa cabecalho car v1 em bytes framed com varint e dag cbor', () {
      final bytes = writeHeader(header);
      expect(bytes.isNotEmpty, isTrue);

      final collected = <List<int>>[];
      final controller = StreamController<List<int>>(sync: true);
      controller.stream.listen(collected.add);
      final bytesWithSink = writeHeader(header, controller.sink);
      controller.close();

      expect(bytesWithSink, equals(bytes));
      expect(collected.first, equals(bytes));
    });

    test('writeHeader() - suporta lista de raizes maior que 23 elementos', () {
      final manyRoots = [
        for (var i = 0; i < 25; i++)
          Cid.computeForDataSync(Uint8List.fromList([i, i + 1]), codec: 'raw'),
      ];
      final largeHeader = CarHeader(roots: manyRoots, version: 1);
      final bytes = writeHeader(largeHeader);
      final decoded = readHeader(bytes);
      expect(decoded.roots.length, equals(25));
    });

    test('readHeader() - decodifica cabecalho a partir de buffer de bytes validando limites', () {
      final bytes = writeHeader(header);
      final decoded = readHeader(bytes);
      expect(decoded.version, equals(1));
      expect(decoded.roots.length, equals(1));
      expect(decoded.roots.first, equals(sampleCid));

      expect(() => readHeader(bytes.sublist(0, 3)), throwsFormatException);
      expect(() => readHeader(bytes, maxSectionSize: 2), throwsFormatException);
    });

    test('readHeaderFromStream() - le e decodifica cabecalho a partir de stream assincrono', () async {
      final bytes = writeHeader(header);
      final stream = Stream.value(bytes);
      final decoded = await readHeaderFromStream(stream);
      expect(decoded.version, equals(1));
      expect(decoded.roots.first, equals(sampleCid));

      final emptyStream = Stream<List<int>>.empty();
      expect(() => readHeaderFromStream(emptyStream), throwsFormatException);
    });

    test('headerSize() - calcula tamanho serializado total do cabecalho com framing', () {
      final calculated = headerSize(header);
      final actual = writeHeader(header).length;
      expect(calculated, equals(actual));
      expect(calculated, greaterThan(0));
    });

    test('validateBlock() - valida integridade dos dados contra multihash do cid', () {
      expect(() => validateBlock(sampleCid, payload), returnsNormally);

      final corruptedPayload = Uint8List.fromList([99, 99, 99]);
      expect(
        () => validateBlock(sampleCid, corruptedPayload),
        throwsA(isA<CarIntegrityException>()),
      );
    });

    test('validateCid() - delega validacao de integridade para validateBlock', () {
      expect(() => validateCid(sampleCid, payload), returnsNormally);

      final corruptedPayload = Uint8List.fromList([99, 99, 99]);
      expect(
        () => validateCid(sampleCid, corruptedPayload),
        throwsA(isA<CarIntegrityException>()),
      );
    });

    test('loadCar() - processa arquivo car e despacha blocos para callback de destino', () async {
      final writer = CarWriter(
        roots: [sampleCid],
        get: (_) => payload,
        links: (_) => const <Cid>[],
      );
      final carBytes = await writer.toBytes();

      final blocks = <CarBlock>[];
      final loadedHeader = await loadCar(carBytes, (CarBlock b) => blocks.add(b));
      expect(loadedHeader.roots, equals([sampleCid]));
      expect(blocks.length, equals(1));
      expect(blocks.first.cid(), equals(sampleCid));
      expect(blocks.first.rawData(), equals(payload));

      final rawPairs = <(Cid, Uint8List)>[];
      await loadCar(carBytes, (Cid c, Uint8List d) => rawPairs.add((c, d)));
      expect(rawPairs.length, equals(1));
      expect(rawPairs.first.$1, equals(sampleCid));
      expect(rawPairs.first.$2, equals(payload));
    });
  });

  group('CarWriter [Atomic Audit]', () {
    final rootData = Uint8List.fromList([1, 2, 3]);
    final childData = Uint8List.fromList([4, 5, 6]);
    final rootCid = Cid.computeForDataSync(rootData, codec: 'raw');
    final childCid = Cid.computeForDataSync(childData, codec: 'raw');

    test('stream() - emite stream de secoes binarias framed com cabecalho e blocos deduplicados', () async {
      final writer = CarWriter(
        roots: [rootCid],
        get: (c) => c == rootCid ? rootData : childData,
        links: (c) => c == rootCid ? [childCid, childCid] : const <Cid>[],
      );

      final sections = await writer.stream().toList();
      expect(sections.length, equals(3));
      final parsedHeader = readHeader(sections[0]);
      expect(parsedHeader.roots, equals([rootCid]));
    });

    test('write() - envia todas as secoes serializadas para um sink de bytes', () async {
      final writer = CarWriter(
        roots: [rootCid],
        get: (_) => rootData,
        links: (_) => const <Cid>[],
      );

      final collected = <List<int>>[];
      final controller = StreamController<List<int>>();
      controller.stream.listen(collected.add);

      await writer.write(controller.sink);
      await controller.close();

      expect(collected.isNotEmpty, isTrue);
      final combined = collected.expand((element) => element).toList();
      final reader = CarReader(combined);
      expect(reader.header!.roots, equals([rootCid]));
      final blk = reader.next();
      expect(blk!.cid(), equals(rootCid));
    });

    test('toBytes() - materializa todo o fluxo car em uint8list contiguo', () async {
      final writer = CarWriter(
        roots: [rootCid],
        get: (_) => rootData,
        links: (_) => const <Cid>[],
      );

      final bytes = await writer.toBytes();
      expect(bytes.isNotEmpty, isTrue);

      final reader = CarReader(bytes);
      expect(reader.header!.roots, equals([rootCid]));
      expect(reader.next()!.cid(), equals(rootCid));
      expect(reader.next(), isNull);
    });
  });

  group('CarReader [Atomic Audit]', () {
    final blockData = Uint8List.fromList([10, 20, 30, 40, 50]);
    final blockCid = Cid.computeForDataSync(blockData, codec: 'raw');

    Future<Uint8List> createCar() async {
      final writer = CarWriter(
        roots: [blockCid],
        get: (_) => blockData,
        links: (_) => const <Cid>[],
      );
      return writer.toBytes();
    }

    test('header() - acessa o cabecalho car decodificado de forma sincrona', () async {
      final bytes = await createCar();
      final reader = CarReader(bytes);
      expect(reader.header, isNotNull);
      expect(reader.header!.version, equals(1));
      expect(reader.header!.roots, equals([blockCid]));
    });

    test('readHeaderAsync() - le e armazena cabecalho assincronamente a partir de stream', () async {
      final bytes = await createCar();
      final stream = Stream.value(bytes);
      final reader = CarReader(stream);

      expect(reader.header, isNull);
      final hdr = await reader.readHeaderAsync();
      expect(hdr.version, equals(1));
      expect(hdr.roots, equals([blockCid]));
      expect(reader.header, equals(hdr));

      final cached = await reader.readHeaderAsync();
      expect(identical(cached, hdr), isTrue);
    });

    test('next() - itera sincronamente sobre as secoes de blocos a partir de bytes', () async {
      final bytes = await createCar();
      final reader = CarReader(bytes);

      final first = reader.next();
      expect(first, isNotNull);
      expect(first!.cid(), equals(blockCid));
      expect(first.rawData(), equals(blockData));

      final second = reader.next();
      expect(second, isNull);

      final streamReader = CarReader(Stream.value(bytes));
      expect(() => streamReader.next(), throwsStateError);
    });

    test('nextAsync() - itera assincronamente sobre as secoes de blocos em stream ou bytes', () async {
      final bytes = await createCar();

      final byteReader = CarReader(bytes);
      final byteBlock = await byteReader.nextAsync();
      expect(byteBlock, isNotNull);
      expect(byteBlock!.cid(), equals(blockCid));
      expect(await byteReader.nextAsync(), isNull);

      final stream = Stream.fromIterable([
        for (var i = 0; i < bytes.length; i++) Uint8List.fromList([bytes[i]]),
      ]);
      final streamReader = CarReader(stream);
      final streamBlock = await streamReader.nextAsync();
      expect(streamBlock, isNotNull);
      expect(streamBlock!.cid(), equals(blockCid));
      expect(await streamReader.nextAsync(), isNull);
    });

    test('blocks() - retorna stream assincrono de todos os blocos decodificados e validados', () async {
      final bytes = await createCar();

      final reader = CarReader(bytes);
      final list = await reader.blocks().toList();
      expect(list.length, equals(1));
      expect(list.first.cid(), equals(blockCid));
      expect(list.first.rawData(), equals(blockData));

      final streamReader = CarReader(Stream.value(bytes));
      final streamList = await streamReader.blocks().toList();
      expect(streamList.length, equals(1));
      expect(streamList.first.cid(), equals(blockCid));
    });
  });
}
