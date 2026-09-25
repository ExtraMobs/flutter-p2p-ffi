import 'dart:convert';
import 'dart:io';

import 'package:golib_dart/builtin.dart';
import 'package:test/test.dart';

void main() {
  test('cap de append segue o growslice do Go', () async {
    final go = await Process.run('go', ['run', 'test/go_slice_growth.go']);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    final types = jsonDecode(go.stdout as String) as Map<String, dynamic>;
    for (final MapEntry(key: name, value: t) in types.entries) {
      final size = t['size'] as int, pointers = t['pointers'] as bool;
      final seq = <int>[];
      var len = 0, cap = 0;
      for (var i = 0; i < 5000; i++) {
        len++;
        if (len > cap) {
          cap = growCap(len, cap, size, pointers);
          seq.add(cap);
        }
      }
      final bulk = <int>[
        for (final start in [0, 1, 5, 17, 300, 1000])
          for (final n in [1, 3, 7, 40, 700])
            start + n > start
                ? growCap(start + n, start, size, pointers)
                : start,
      ];
      expect(seq, t['caps'], reason: '$name: sequência');
      expect(bulk, t['bulk'], reason: '$name: append em bloco');
    }
  });
}
