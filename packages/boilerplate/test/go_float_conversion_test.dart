// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('float conversions match Go bit patterns', () async {
    final go = await Process.run('go', ['run', 'test/go_float_conversion.go']);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    String hex(Uint8List b) =>
        b.reversed.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final values = [
      0.0,
      -0.0,
      1 + math.pow(2, -24),
      1 + 3 * math.pow(2, -24),
      math.pow(2, -150),
      3 * math.pow(2, -150),
      1e300,
      0.1,
    ];
    final rows = values.map((x) {
      final narrow = Golang.Float32.fromFloat64(Golang.Float64(x.toDouble()));
      final wide = Golang.Float64.fromFloat32(narrow);
      return [
        hex(narrow.toLittleEndianBytes()),
        hex(wide.toLittleEndianBytes()),
      ];
    }).toList();
    expect(rows, jsonDecode(go.stdout as String));
  });
}
