// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_boxo/transpiled_boxo.dart';

class _FakeDatastore extends MapDatastore {
  Object? hasFailure;
  Object? putFailure;
  Object? batchFailure;
  Object? batchPutFailure;
  Object? batchCommitFailure;
  final hasKeys = <Key>[];
  final putKeys = <Key>[];
  final batchPutKeys = <Key>[];
  int batchCount = 0;
  int commitCount = 0;

  @override
  Future<bool> has(Key key) async {
    hasKeys.add(key);
    if (hasFailure != null) throw hasFailure!;
    return super.has(key);
  }

  @override
  Future<void> put(Key key, List<int> value) async {
    putKeys.add(key);
    if (putFailure != null) throw putFailure!;
    await super.put(key, value);
  }

  @override
  Future<Batch> batch() async {
    batchCount++;
    if (batchFailure != null) throw batchFailure!;
    return _RecordingBatch(
      this,
      putFailure: batchPutFailure,
      commitFailure: batchCommitFailure,
    );
  }
}

class _RecordingBatch implements Batch {
  _RecordingBatch(this._target, {this.putFailure, this.commitFailure});

  final _FakeDatastore _target;
  final Object? putFailure;
  final Object? commitFailure;

  @override
  Future<void> put(Key key, List<int> value) async {
    _target.batchPutKeys.add(key);
    if (putFailure != null) throw putFailure!;
  }

  @override
  Future<void> delete(Key key) async {}

  @override
  Future<void> commit() async {
    _target.commitCount++;
    if (commitFailure != null) throw commitFailure!;
  }
}

BasicBlock _block(String value) =>
    BasicBlock.fromData(Uint8List.fromList(value.codeUnits));

void main() {
  test('put, has, get and getSize use the block datastore key', () async {
    final datastore = _FakeDatastore();
    final blockstore = Blockstore(datastore);
    final block = _block('block');

    await blockstore.put(block);

    expect(await blockstore.has(block.cid()), isTrue);
    expect((await blockstore.get(block.cid())).rawData(), block.rawData());
    expect(await blockstore.getSize(block.cid()), block.rawData().length);
    expect(datastore.putKeys, hasLength(1));
    expect(
      datastore.putKeys.map((key) => key.value),
      equals(['/blocks/CIQES2WKQDSNR4U7XDUM3ALMHL5URU7RAOLQWORO4FQAYCGKM4ZG33Q']),
    );
  });

  test('uses the same key for CIDv0 and CIDv1 with the same multihash', () async {
    final datastore = _FakeDatastore();
    final blockstore = Blockstore(datastore);
    final data = Uint8List.fromList('same-hash'.codeUnits);
    final v0 = BasicBlock.fromData(data).cid();
    final v1 = Cid.v1('raw', v0.multihash);

    await blockstore.put(BasicBlock.withCid(data, v0));

    expect(await blockstore.has(v1), isTrue);
  });

  test('put ignores Has errors and Has still propagates them', () async {
    final error = StateError('has failed');
    final datastore = _FakeDatastore()..hasFailure = error;
    final blockstore = Blockstore(datastore);
    final block = _block('has-error');

    await blockstore.put(block);
    expect(datastore.putKeys, hasLength(1));
    await expectLater(blockstore.has(block.cid()), throwsA(same(error)));
  });

  test('put propagates datastore put errors', () async {
    final error = StateError('put failed');
    final datastore = _FakeDatastore()..putFailure = error;

    await expectLater(
      Blockstore(datastore).put(_block('put-error')),
      throwsA(same(error)),
    );
  });

  test('putMany creates and commits a batch even when it is empty', () async {
    final datastore = _FakeDatastore();
    final blockstore = Blockstore(datastore);

    await blockstore.putMany(const []);

    expect(datastore.batchCount, 1);
    expect(datastore.commitCount, 1);
    expect(datastore.batchPutKeys, isEmpty);
  });

  test('putMany with one block uses the put fast path', () async {
    final datastore = _FakeDatastore();
    final blockstore = Blockstore(datastore);

    await blockstore.putMany([_block('single')]);

    expect(datastore.putKeys, hasLength(1));
    expect(datastore.batchCount, 0);
  });

  test('put skips an existing block unless writeThrough is enabled', () async {
    final block = _block('existing');
    final datastore = _FakeDatastore();
    final blockstore = Blockstore(datastore);
    await blockstore.put(block);
    datastore.putKeys.clear();
    datastore.hasKeys.clear();

    await blockstore.put(block);
    expect(datastore.putKeys, isEmpty);

    final throughDatastore = _FakeDatastore();
    final through = Blockstore(throughDatastore, writeThrough: true);
    await through.put(block);
    throughDatastore.putKeys.clear();
    await through.put(block);
    expect(throughDatastore.putKeys, hasLength(1));
  });

  test(
    'putMany skips existing blocks unless writeThrough is enabled',
    () async {
      final first = _block('first');
      final second = _block('second');
      final datastore = _FakeDatastore();
      final blockstore = Blockstore(datastore);
      await blockstore.put(first);
      datastore.batchPutKeys.clear();
      datastore.commitCount = 0;

      await blockstore.putMany([first, second]);

      expect(datastore.batchPutKeys, hasLength(1));
      expect(datastore.commitCount, 1);

      final throughDatastore = _FakeDatastore();
      await Blockstore(throughDatastore, writeThrough: true)
          .putMany([first, second]);
      expect(throughDatastore.hasKeys, isEmpty);
      expect(throughDatastore.batchPutKeys, hasLength(2));
      expect(throughDatastore.commitCount, 1);
    },
  );

  test(
    'putMany ignores Has errors and preserves the no-prefix option',
    () async {
      final datastore = _FakeDatastore()..hasFailure = StateError('has failed');
      final blockstore = Blockstore(datastore, noPrefix: true);
      final block = _block('no-prefix');

      await blockstore.putMany([block, _block('another')]);

      expect(datastore.batchPutKeys, hasLength(2));
      expect(
        datastore.batchPutKeys.map((key) => key.value),
        equals([
          '/CIQP2HXCYEEU4S6ZNIGUXM6AA4L4I5B7NX2JTEZP6JQQV4YQQ56SUSY',
          '/CIQK4REKZBWE5DSN5RSFOKLQR32BQ45OPHDN76CO75ZTMCMJJB7QRZI',
        ]),
      );
    },
  );

  test('putMany propagates batch creation errors', () async {
    final error = StateError('batch failed');
    final datastore = _FakeDatastore()..batchFailure = error;

    await expectLater(
      Blockstore(datastore).putMany([_block('batch'), _block('second')]),
      throwsA(same(error)),
    );
    expect(datastore.commitCount, 0);
  });

  test('putMany propagates batch put errors without committing', () async {
    final error = StateError('batch put failed');
    final datastore = _FakeDatastore()..batchPutFailure = error;

    await expectLater(
      Blockstore(datastore).putMany([_block('batch-put'), _block('later')]),
      throwsA(same(error)),
    );
    expect(datastore.commitCount, 0);
  });

  test('putMany propagates batch commit errors', () async {
    final error = StateError('commit failed');
    final datastore = _FakeDatastore()..batchCommitFailure = error;

    await expectLater(
      Blockstore(datastore).putMany([_block('commit'), _block('second')]),
      throwsA(same(error)),
    );
    expect(datastore.commitCount, 1);
  });
}
