@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/net/textproto.dart' as textproto;
import 'package:test/test.dart';

Golang.String _s(List l) => Golang.String.fromBytes(
  Uint8List.fromList([for (final b in l) b as int]),
);

void main() {
  test('CanonicalMIMEHeaderKey, TrimString e TrimBytes iguais ao Go', () async {
    final r = await Process.run(
      'go',
      ['run', 'test/go_textproto_vectors.go'],
      environment: {...Platform.environment, 'GOTOOLCHAIN': 'go1.26.5'},
      stdoutEncoding: utf8,
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final ins = go['in'] as List, canon = go['canon'] as List;
    final trim = go['trim'] as List;
    final bad = <String>[];
    for (var i = 0; i < ins.length; i++) {
      final s = _s(ins[i] as List);
      final c = textproto.canonicalMIMEHeaderKey(s);
      if (c != _s(canon[i] as List)) bad.add('canon ${ins[i]}: $c');
      final t = textproto.trimString(s);
      if (t != _s(trim[i] as List)) bad.add('trim ${ins[i]}: $t');
      final b = Slice.of([
        for (final x in s.toBytes()) Golang.Uint8(x),
      ], const Elem<Golang.Uint8>(1, Golang.Uint8.new));
      final tb = textproto.trimBytes(b);
      final tbs = Golang.String.fromBytes(
        Uint8List.fromList([for (final x in tb.items) x.toInt()]),
      );
      if (tbs != t) bad.add('trimBytes ${ins[i]}: $tbs');
    }
    expect(bad, isEmpty);
  });
}
