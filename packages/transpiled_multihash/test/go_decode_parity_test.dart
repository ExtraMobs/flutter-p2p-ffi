// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

void main() {
  test('Decode matches locked Go values and error precedence', () async {
    const inputs = [
      '',
      '00',
      '0000',
      '990101aa',
      '1200',
      '0001',
      '000001',
      '800000',
      '008000',
      '008080808008',
      'ffffffffffffffffff',
      'ffffffffffffffff7f00',
      '8100',
      '8101',
      '0002aabb',
      '81e40200',
      'c0e40200',
      'c1e40200',
      'e0e40200',
    ];
    var reference = Directory('../../go-ipfs-reference/go-multihash').absolute;
    if (!reference.existsSync()) {
      reference = Directory('go-ipfs-reference/go-multihash').absolute;
    }
    var vectorFile = File('test/go_decode_vectors.go').absolute;
    if (!vectorFile.existsSync()) {
      vectorFile = File('packages/transpiled_multihash/test/go_decode_vectors.go').absolute;
    }
    final revision = await Process.run('git', [
      'rev-parse',
      'HEAD',
    ], workingDirectory: reference.path);
    expect(revision.exitCode, 0, reason: '${revision.stderr}');
    expect(
      '${revision.stdout}'.trim(),
      'b29af1cd12049b4d5fa9a81b0cb0b4a04703fa27',
    );
    final result = await Process.run('go', [
      'run',
      vectorFile.path,
      ...inputs,
    ], workingDirectory: reference.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final actual = inputs.map((input) {
      final bytes = Uint8List.fromList([
        for (var i = 0; i < input.length; i += 2)
          int.parse(input.substring(i, i + 2), radix: 16),
      ]);
      try {
        final decoded = MultihashUtils.decode(bytes);
        return [
          'ok',
          '${decoded.code}',
          decoded.name,
          decoded.digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        ];
      } on FormatException catch (error) {
        return ['error', error.message];
      }
    }).toList();
    expect(actual, jsonDecode('${result.stdout}'));
  });
}
