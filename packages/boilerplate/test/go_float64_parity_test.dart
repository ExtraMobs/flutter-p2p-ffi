// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('float64 arithmetic matches Go binary64 output bits', () async {
    final result = await Process.run('go', [
      'run',
      'test/go_float64_vectors.go',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final values = [
      0.0,
      -0.0,
      1.0,
      -1.0,
      0.1,
      9007199254740992.0,
      math.pow(2, -1074).toDouble(),
      1.7976931348623157e308,
      double.infinity,
    ].map(Golang.Float64.new).toList();
    final rows = <List<String>>[];
    for (final x in values) {
      for (final y in values) {
        rows.add(
          [x + y, x - y, x * y, x / y]
              .map(
                (v) => v.toDouble().isNaN
                    ? 'NaN'
                    : v
                          .toLittleEndianBytes()
                          .reversed
                          .map((b) => b.toRadixString(16).padLeft(2, '0'))
                          .join(),
              )
              .toList(),
        );
      }
    }
    expect(rows, jsonDecode(result.stdout as String));
  });
}
