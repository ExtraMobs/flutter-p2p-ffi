import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart'
    as block_format;
import 'package:transpiled_boxo/transpiled_boxo.dart' as boxo;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart' as multihash;

class _QueryDatastore extends MapDatastore {
  _QueryDatastore(this.rows, {this.creationError});
  final List<QueryResult> rows;
  final Object? creationError;
  bool closed = false;
  Query? received;

  @override
  Future<Results> query(Query query) async {
    received = query;
    if (creationError case final error?) throw error;
    var offset = 0;
    return resultsFromIterator(
      query,
      QueryIterator(
        next: () => offset < rows.length
            ? (rows[offset++], true)
            : (const QueryResult(Entry(key: '')), false),
        close: () => closed = true,
      ),
    );
  }
}

void main() {
  group('dshelp [Atomic Audit]', () {
    final raw = Uint8List.fromList([18, 32, ...List.generate(32, (i) => i)]);
    const encoded = '/CIQAAAICAMCAKBQHBAEQUCYMBUHA6EARCIJRIFIWC4MBSGQ3DQOR4HY';
    test(
      'keyFromBinary() - matches unpadded Base32 without normalizing bytes',
      () {
        expect(boxo.keyFromBinary(raw).value, encoded);
        expect(boxo.keyFromBinary(Uint8List(0)).value, '/');
      },
    );
    test('binaryFromDsKey() - decodes bytes and rejects invalid alphabet', () {
      expect(boxo.binaryFromDsKey(Key.raw(encoded)), raw);
      expect(() => boxo.binaryFromDsKey(Key.raw('/!')), throwsA(anything));
    });
    test('multihashToDsKey() - delegates to binary key encoding', () {
      expect(boxo.multihashToDsKey(raw).value, encoded);
    });
    test('dsKeyToMultihash() - validates the decoded multihash', () {
      expect(boxo.dsKeyToMultihash(Key.raw(encoded)), raw);
      expect(
        () => boxo.dsKeyToMultihash(
          boxo.keyFromBinary(Uint8List.fromList([18, 32, 0])),
        ),
        throwsA(anything),
      );
    });
    test('dsKeyToCidV1() - preserves numeric codec and multihash', () {
      final cid = boxo.dsKeyToCidV1(Key.raw(encoded), Golang.Uint64(0x300001));
      expect(cid.version, 1);
      expect(cid.codecCode, Golang.Uint64(0x300001));
      expect(cid.multihash.toBytes(), raw);
    });
  });
  group('Blockstore [Atomic Audit]', () {
    test(
      'allKeysChanWithErr() - enumerates only blocks as raw CIDv1',
      () async {
        final datastore = MapDatastore();
        final blockstore = boxo.Blockstore(datastore);
        final bytes = Uint8List.fromList([1, 2, 3]);
        final raw = await Cid.fromContent(bytes);
        final dag = Cid.v1('dag-pb', raw.multihash);
        await blockstore.putMany([
          block_format.BasicBlock(bytes, raw),
          block_format.BasicBlock(bytes, dag),
        ]);
        await datastore.put(Key('/provider/reprovide/lastreprovide'), [1]);
        await datastore.put(Key('/blocks-invalid/elsewhere'), [1]);
        await datastore.put(Key('/blocks/!'), [1]);
        final keys = await (await blockstore.allKeysChanWithErr()).toList();
        expect(keys, [raw]);
      },
    );
    test(
      'allKeysChanWithErr() - closes query after subscription cancellation',
      () async {
        final cid = await Cid.fromContent(Uint8List.fromList([4]));
        final row = QueryResult(
          Entry(key: boxo.multihashToDsKey(cid.multihash.toBytes()).value),
        );
        final datastore = _QueryDatastore([row, row]);
        final keys = await (await boxo.Blockstore(
          datastore,
          noPrefix: true,
        ).allKeysChanWithErr()).take(1).toList();
        expect(keys, [cid]);
        expect(datastore.closed, isTrue);
        expect(datastore.received!.keysOnly, isTrue);
        expect(datastore.received!.prefix, '');
      },
    );
    test(
      'allKeysChanWithErr() - reports iteration error and closes query',
      () async {
        final error = StateError('query failed');
        final datastore = _QueryDatastore([QueryResult.error(error)]);
        final stream = await boxo.Blockstore(datastore).allKeysChanWithErr();
        await expectLater(
          stream.toList(),
          throwsA(predicate((e) => e.toString().contains('query failed'))),
        );
        expect(datastore.closed, isTrue);
      },
    );
    test(
      'allKeysChan() - suppresses iteration failure like the Go compatibility API',
      () async {
        final datastore = _QueryDatastore([
          QueryResult.error(StateError('failed')),
        ]);
        expect(
          await (await boxo.Blockstore(datastore).allKeysChan()).toList(),
          isEmpty,
        );
        expect(datastore.closed, isTrue);
      },
    );
    test('allKeysChan() - query creation errors remain observable', () async {
      final error = StateError('cannot query');
      final datastore = _QueryDatastore([], creationError: error);
      await expectLater(
        boxo.Blockstore(datastore).allKeysChan(),
        throwsA(same(error)),
      );
    });
    test(
      'allKeysChanWithErr() - supports asynchronous datastore results',
      () async {
        final cid = Cid.v1(
          'raw',
          multihash.decode(Uint8List.fromList([18, 32, ...List.filled(32, 0)])),
        );
        final datastore = _AsyncDatastore(
          boxo.multihashToDsKey(cid.multihash.toBytes()).value,
        );
        expect(
          await (await boxo.Blockstore(
            datastore,
            noPrefix: true,
          ).allKeysChanWithErr()).toList(),
          [cid],
        );
      },
    );
  });
}

class _AsyncDatastore extends MapDatastore {
  _AsyncDatastore(this.key);
  final String key;
  @override
  Future<Results> query(Query query) async =>
      resultsWithContext(query, (cancelled, sink) async {
        await Future<void>.delayed(Duration.zero);
        sink.add(QueryResult(Entry(key: key)));
      });
}
