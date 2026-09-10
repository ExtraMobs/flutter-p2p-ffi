// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

void main() {
  test('new block computes a Cid and exposes block metadata', () {
    final block = BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));
    expect(block.rawData(), orderedEquals([1, 2, 3]));
    expect(block.cid().version, 0);
    expect(block.multihash(), isNotEmpty);
    expect(block.toString(), '[Block ${block.cid()}]');
    expect(block.loggable()['block'], block.cid().toString());
  });

  test('withCid accepts trusted CIDs when debug validation is off', () {
    final cid = Cid.computeForDataSync(Uint8List.fromList([1]), codec: 'raw');
    expect(BasicBlock.withCid(Uint8List.fromList([2]), cid).cid(), cid);
  });
}
