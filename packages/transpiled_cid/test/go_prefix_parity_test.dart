// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

void main() {
  test('PrefixFromBytes fields and suffix handling match locked Go', () async {
    const inputs = ['01551220', '0155122099', '00701220', '01000000ff'];
    final reference = Directory('../../go-ipfs-reference/go-cid').absolute.path;
    final revision = await Process.run('git', ['rev-parse', 'HEAD'],
        workingDirectory: reference);
    expect(revision.exitCode, 0);
    expect('${revision.stdout}'.trim(), '707ffd0177069183ed529f6799b3c2e1d67372c5');
    final result = await Process.run('go', [
      'run', File('test/go_prefix_vectors.go').absolute.path, ...inputs,
    ], workingDirectory: reference);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final actual = inputs.map((input) {
      final p = Prefix.fromBytes(Uint8List.fromList([
        for (var i = 0; i < input.length; i += 2)
          int.parse(input.substring(i, i + 2), radix: 16),
      ]));
      return ['${p.version}', '${p.codecCode}', '${p.mhTypeCode}', '${p.mhLength}'];
    }).toList();
    expect(actual, jsonDecode('${result.stdout}'));
  });
}
