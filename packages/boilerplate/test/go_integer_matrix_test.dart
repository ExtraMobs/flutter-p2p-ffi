// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('signed and unsigned operation matrix matches Go', () async {
    final oracle = await Process.run('go', [
      'run',
      'test/go_integer_matrix.go',
    ]);
    expect(oracle.exitCode, 0, reason: '${oracle.stderr}');
    final expected = jsonDecode(oracle.stdout as String) as List<dynamic>;
    final rows = <List<String>>[];
    void add(List<Object> values) =>
        rows.add(values.map((v) => v.toString()).toList());
    final signed = [
      '-9223372036854775808',
      '-9223372036854775807',
      '-4294967297',
      '-5',
      '-1',
      '0',
      '1',
      '2',
      '4294967297',
      '9223372036854775807',
    ].map((v) => Golang.Int64.fromBigInt(BigInt.parse(v))).toList();
    final unsigned = [
      '0',
      '1',
      '2',
      '4294967297',
      '9223372036854775807',
      '9223372036854775808',
      '18446744073709551615',
    ].map((v) => Golang.Uint64.fromBigInt(BigInt.parse(v))).toList();
    for (final x in signed) {
      for (final y in signed) {
        add([
          x + y,
          x - y,
          x * y,
          x & y,
          x | y,
          x ^ y,
          x.andNot(y),
          x == y,
          x < y,
          x <= y,
          x > y,
          x >= y,
          if (y != Golang.Int64()) ...[x ~/ y, x % y],
        ]);
      }
      for (final shift in [0, 1, 31, 32, 63, 64, 65, 1000000]) {
        add([x << shift, x >> shift]);
      }
    }
    for (final x in unsigned) {
      for (final y in unsigned) {
        add([
          x + y,
          x - y,
          x * y,
          x & y,
          x | y,
          x ^ y,
          x.andNot(y),
          x == y,
          x < y,
          x <= y,
          x > y,
          x >= y,
          if (y != Golang.Uint64()) ...[x ~/ y, x % y],
        ]);
      }
      for (final shift in [0, 1, 31, 32, 63, 64, 65, 1000000]) {
        add([x << shift, x >> shift]);
      }
    }
    expect(rows.length, expected.length);
    for (var i = 0; i < rows.length; i++) {
      expect(rows[i], expected[i], reason: 'Go matrix row $i');
    }
  });
}
