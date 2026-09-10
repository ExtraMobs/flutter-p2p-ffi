// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_base58/transpiled_base58.dart';
import 'package:transpiled_boxo/transpiled_boxo.dart';

void main() {
  test('XOR matches boxo vectors', () {
    expect(
      xor(
        Uint8List.fromList([0xff, 0xff, 0xff]),
        Uint8List.fromList([0xff, 0xff, 0xff]),
      ),
      [0, 0, 0],
    );
    expect(
      xor(
        Uint8List.fromList([0, 0xff, 0]),
        Uint8List.fromList([0xff, 0xff, 0xff]),
      ),
      [0xff, 0, 0xff],
    );
  });

  test('partitions use first and last separator', () {
    expect(partition('Ready, steady, go!', ', '), [
      'Ready',
      ', ',
      'steady, go!',
    ]);
    expect(rPartition('Ready, steady, go!', ', '), [
      'Ready, steady',
      ', ',
      'go!',
    ]);
    expect(partition('abc', '/'), ['abc', '', '']);
  });

  test('hash and validity', () {
    final digest = hash(Uint8List.fromList('hello'.codeUnits));
    final encoded = Base58().encode(digest.toBytes());
    expect(isValidHash(encoded), isTrue);
    expect(isValidHash('not a hash'), isFalse);
  });

  test('RFC3339 round trip is UTC', () {
    final parsed = parseRfc3339(formatRfc3339(DateTime.now()));
    expect(parsed.isUtc, isTrue);
  });

  test('FileExists reports missing paths', () {
    expect(
      fileExists('i would be surprised to discover that this file exists'),
      isFalse,
    );
  });
}
