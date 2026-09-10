// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's test/test_util.go: RunBatchTest,
// RunBatchDeleteTest, RunBatchPutAndDeleteTest.
import 'dart:math';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

String _base32(List<int> bytes) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final buffer = StringBuffer();
  var bits = 0;
  var value = 0;
  for (final byte in bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      buffer.write(alphabet[(value >> (bits - 5)) & 0x1F]);
      bits -= 5;
    }
  }
  if (bits > 0) {
    buffer.write(alphabet[(value << (5 - bits)) & 0x1F]);
  }
  return buffer.toString();
}

/// Equivalent to go-datastore's `dstest.RunBatchTest`.
Future<void> runBatchTest(Batching ds) async {
  final batch = await ds.batch();

  final blocks = <List<int>>[];
  final keys = <Key>[];
  final random = Random.secure();
  for (var i = 0; i < 20; i++) {
    final blk = List.generate(256 * 1024, (_) => random.nextInt(256));
    blocks.add(blk);

    final key = Key(_base32(blk.sublist(0, 8)));
    keys.add(key);

    await batch.put(key, blk);
  }

  for (final k in keys) {
    await expectLater(
      () => ds.get(k),
      throwsA(isA<NotFoundException>()),
      reason: 'should not have found this block before committing',
    );
  }

  await batch.commit();

  for (var i = 0; i < keys.length; i++) {
    final blk = await ds.get(keys[i]);
    expect(blk, equals(blocks[i]), reason: 'blocks not correct!');
  }
}

/// Equivalent to go-datastore's `dstest.RunBatchDeleteTest`.
Future<void> runBatchDeleteTest(Batching ds) async {
  final keys = <Key>[];
  final random = Random.secure();
  for (var i = 0; i < 20; i++) {
    final blk = List.generate(16, (_) => random.nextInt(256));
    final key = Key(_base32(blk.sublist(0, 8)));
    keys.add(key);
    await ds.put(key, blk);
  }

  final batch = await ds.batch();
  for (final k in keys) {
    await batch.delete(k);
  }
  await batch.commit();

  for (final k in keys) {
    await expectLater(() => ds.get(k), throwsA(isA<NotFoundException>()));
  }
}

/// Equivalent to go-datastore's `dstest.RunBatchPutAndDeleteTest`.
Future<void> runBatchPutAndDeleteTest(Batching ds) async {
  final batch = await ds.batch();

  final ka = Key('/a');
  final kb = Key('/b');

  await batch.put(ka, [1]);
  await batch.put(kb, [2]);
  await batch.delete(ka);
  await batch.delete(kb);
  await batch.put(kb, [3]);

  await batch.commit();

  await expectLater(() => ds.get(ka), throwsA(isA<NotFoundException>()));

  final v = await ds.get(kb);
  expect(v, equals([3]));
}

/// All batching subtests, in Go's `dstest.BatchSubtests` order.
final List<Future<void> Function(Batching)> batchSubtests = [
  runBatchTest,
  runBatchDeleteTest,
  runBatchPutAndDeleteTest,
];
