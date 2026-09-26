// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart';
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/strconv.dart' as strconv;
import 'package:test/test.dart';

String _err(GoError? e) => e == null ? '<nil>' : '${e.error()}';

void main() {
  test('strconv (inteiros) igual ao Go: valores e mensagens de erro', () async {
    final r = await Process.run('go', [
      'run',
      'test/go_strconv_vectors.go',
    ], stdoutEncoding: utf8);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final inputs = [
      for (final h in go['in'] as List)
        Golang.String.fromBytes(
          Uint8List.fromList([
            for (var i = 0; i < (h as String).length; i += 2)
              int.parse(h.substring(i, i + 2), radix: 16),
          ]),
        ),
    ];
    final out = <String>[];
    for (final s in inputs) {
      for (final b in [0, 2, 8, 10, 16, 36, 1, 37]) {
        for (final bs in [0, 8, 32, 64, 65, -1]) {
          final (u, ue) = strconv.parseUint(s, Golang.Int(b), Golang.Int(bs));
          final (i, ie) = strconv.parseInt(s, Golang.Int(b), Golang.Int(bs));
          out.add('$u ${_err(ue)}|$i ${_err(ie)}');
        }
      }
      final (a, ae) = strconv.atoi(s);
      out.add('$a ${_err(ae)}');
    }
    final big = BigInt.parse('9223372036854775807');
    for (final v in [
      BigInt.zero,
      BigInt.one,
      -BigInt.one,
      BigInt.from(35),
      BigInt.from(-36),
      BigInt.from(255),
      big,
      -big - BigInt.one,
    ]) {
      final i = Golang.Int64.fromBigInt(v);
      for (final b in [2, 8, 10, 16, 36]) {
        out.add(
          '${strconv.formatInt(i, Golang.Int(b))} '
          '${strconv.formatUint(Golang.Uint64.from(i), Golang.Int(b))}',
        );
      }
      out.add('${strconv.itoa(Golang.Int.from(i))}');
    }
    final want = (go['out'] as List).cast<String>();
    expect(out.length, want.length);
    for (var k = 0; k < out.length; k++) {
      expect(out[k], want[k], reason: 'linha $k');
    }
  });

  test('FormatInt com base inválida entra em pânico como o Go', () {
    expect(
      () => strconv.formatInt(Golang.Int64(1), Golang.Int(1)),
      throwsA(
        predicate(
          (e) => '$e' == 'panic: strconv: illegal AppendInt/FormatInt base',
        ),
      ),
    );
  });
}
