// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('integer to float results match Go bits', () async {
    final go = await Process.run('go', ['run', 'test/go_integer_float.go']);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    String hex(Uint8List b) =>
        b.reversed.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final rows = <List<String>>[];
    for (final text in [
      '0',
      '1',
      '-1',
      '16777217',
      '9007199254740993',
      '4611686293305294849',
      '-4611686293305294849',
      '-9223372036854775808',
      '9223372036854775807',
    ]) {
      final v = Golang.Int64.fromBigInt(BigInt.parse(text));
      rows.add([
        hex(Golang.Float32.fromInt64(v).toLittleEndianBytes()),
        hex(Golang.Float64.fromInt64(v).toLittleEndianBytes()),
      ]);
    }
    final v = Golang.Uint64(-1);
    rows.add([
      hex(Golang.Float32.fromUint64(v).toLittleEndianBytes()),
      hex(Golang.Float64.fromUint64(v).toLittleEndianBytes()),
    ]);
    expect(rows, jsonDecode(go.stdout as String));
  });
}
