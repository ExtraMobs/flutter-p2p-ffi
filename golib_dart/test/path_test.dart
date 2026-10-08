// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/path.dart' as path;
import 'package:test/test.dart';

Golang.String _unhex(String h) => Golang.String.fromBytes(
  Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]),
);

String _hex(Golang.String s) =>
    [for (final x in s.toBytes()) x.toRadixString(16).padLeft(2, '0')].join();

String _err(GoError? e) =>
    _hex(e == null ? Golang.String.fromDart('<nil>') : e.error());

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);

void main() {
  test('path igual ao Go (path_test.go, match_test.go)', () async {
    final r = await Process.run('go', [
      'run',
      'test/go_path_vectors.go',
    ], stdoutEncoding: utf8);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final cases = jsonDecode(r.stdout as String) as List;
    expect(cases.length, greaterThan(100));
    for (final c in cases) {
      final f = c[0] as String;
      final a = [for (final h in c[1] as List) _unhex(h as String)];
      final List<Object?> got = switch (f) {
        'Clean' => [_hex(path.clean(a[0]))],
        'Split' => () {
          final (d, b) = path.split(a[0]);
          return [_hex(d), _hex(b)];
        }(),
        'Join' => [_hex(path.join(Slice.of(a, _strElem)))],
        'Ext' => [_hex(path.ext(a[0]))],
        'Base' => [_hex(path.base(a[0]))],
        'Dir' => [_hex(path.dir(a[0]))],
        'IsAbs' => [path.isAbs(a[0])],
        'Match' => () {
          final (ok, err) = path.match(a[0], a[1]);
          return [ok, _err(err)];
        }(),
        _ => throw StateError(f),
      };
      expect(got, c[2], reason: '$f${c[1]}');
    }
  });

  test('ErrBadPattern é o mesmo valor', () {
    final (_, err) = path.match(
      Golang.String.fromDart('['),
      Golang.String.fromDart('a'),
    );
    expect(identical(err, path.errBadPattern), isTrue);
  });
}
