import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/unicode.dart' as unicode;
import 'package:test/test.dart';

const _maxRune = 0x10ffff;

/// Saída de `tool/oracle_unicode.go`: faixas fechadas por nome (booleanos) e
/// pares esparsos por nome (conversões, só onde `f(r) != r`).
class _Oracle {
  _Oracle(String text) {
    final lines = const LineSplitter().convert(text);
    var i = 0;
    while (i < lines.length) {
      final head = lines[i].split(' ');
      final kind = head[0], name = head[1];
      i++;
      if (kind == 'RANGES') {
        final mask = Uint8List(_maxRune + 1);
        while (lines[i] != 'END') {
          final parts = lines[i].split(' ');
          final lo = int.parse(parts[0]), hi = int.parse(parts[1]);
          for (var r = lo; r <= hi; r++) {
            mask[r] = 1;
          }
          i++;
        }
        ranges[name] = mask;
      } else {
        final map = <int, int>{};
        while (lines[i] != 'END') {
          final parts = lines[i].split(' ');
          map[int.parse(parts[0])] = int.parse(parts[1]);
          i++;
        }
        pairs[name] = map;
      }
      i++; // 'END'
    }
  }

  final Map<String, Uint8List> ranges = {};
  final Map<String, Map<int, int>> pairs = {};

  bool has(String name, int r) => ranges[name]![r] != 0;
  int map(String name, int r) => pairs[name]![r] ?? r;
}

void main() {
  test('tables.g.dart está em dia com o `unicode` do Go instalado', () async {
    final go = await Process.run('go', [
      'run',
      'tool/gen_unicode.go',
      'tool/gen_unicode_scripts.go',
      'tool/gen_unicode_case.go',
    ], stdoutEncoding: utf8);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    final fmt = await Process.start('dart', ['format'], runInShell: true);
    fmt.stdin.add(utf8.encode(go.stdout as String));
    await fmt.stdin.close();
    final formatted = await fmt.stdout.transform(utf8.decoder).join();
    expect(await fmt.exitCode, 0);
    final file = File(
      'lib/src/unicode/tables.g.dart',
    ).readAsStringSync();
    expect(
      formatted.replaceAll('\r\n', '\n'),
      file.replaceAll('\r\n', '\n'),
    );
  });

  test(
    'predicados e conversões batem com o oráculo Go em 0..0x10FFFF',
    () async {
      final oracleProc = await Process.run('go', [
        'run',
        'tool/oracle_unicode.go',
      ], stdoutEncoding: utf8);
      expect(oracleProc.exitCode, 0, reason: '${oracleProc.stderr}');
      final oracle = _Oracle(oracleProc.stdout as String);

      final boolChecks = <String, bool Function(Golang.Rune)>{
        'IsDigit': unicode.isDigit,
        'IsLetter': unicode.isLetter,
        'IsSpace': unicode.isSpace,
        'IsUpper': unicode.isUpper,
        'IsLower': unicode.isLower,
        'IsTitle': unicode.isTitle,
        'IsControl': unicode.isControl,
        'IsMark': unicode.isMark,
        'IsNumber': unicode.isNumber,
        'IsPunct': unicode.isPunct,
        'IsSymbol': unicode.isSymbol,
        'IsGraphic': unicode.isGraphic,
        'IsPrint': unicode.isPrint,
        'Greek': (r) => unicode.is$(unicode.greek, r),
        'Soft_Dotted': (r) => unicode.is$(unicode.soft_Dotted, r),
      };
      final rangeChecks = <String, Uint8List>{
        for (final name in boolChecks.keys) name: oracle.ranges[name]!,
      };

      final mapChecks = <String, Golang.Rune Function(Golang.Rune)>{
        'ToUpper': unicode.toUpper,
        'ToLower': unicode.toLower,
        'ToTitle': unicode.toTitle,
        'SimpleFold': unicode.simpleFold,
      };

      for (var r = 0; r <= _maxRune; r++) {
        final rune = Golang.Rune(r);
        boolChecks.forEach((name, fn) {
          final want = rangeChecks[name]![r] != 0;
          final got = fn(rune);
          if (got != want) {
            fail('$name(0x${r.toRadixString(16)}): esperado $want, veio $got');
          }
        });
        mapChecks.forEach((name, fn) {
          final want = oracle.map(name, r);
          final got = fn(rune).toInt();
          if (got != want) {
            fail(
              '$name(0x${r.toRadixString(16)}): esperado 0x${want.toRadixString(16)}, '
              'veio 0x${got.toRadixString(16)}',
            );
          }
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('casos conhecidos', () {
    Golang.Rune r(int v) => Golang.Rune(v);

    // ß (U+00DF): maiúscula é SS em texto, mas ToUpper (1:1) não muda.
    expect(unicode.toUpper(r(0xdf)).toInt(), 0xdf);
    expect(unicode.isLower(r(0xdf)), isTrue);

    // İ (U+0130, I maiúsculo com ponto) e o ı sem ponto (U+0131): mapeiam
    // para 'i'/'I' comuns em ToLower/ToUpper (sem a regra especial turca).
    expect(unicode.toLower(r(0x130)).toInt(), 0x69); // İ -> i (mapeamento base)
    expect(unicode.toUpper(r(0x131)).toInt(), 0x49); // ı -> I

    // ſ (long s, U+017F): minúscula "extra" que dobra para 's'/'S'.
    expect(unicode.toUpper(r(0x17f)).toInt(), 0x53);
    expect(unicode.simpleFold(r(0x73)).toInt(), 0x17f); // s -> ſ
    expect(unicode.simpleFold(r(0x17f)).toInt(), 0x53); // ſ -> S
    expect(unicode.simpleFold(r(0x53)).toInt(), 0x73); // S -> s (fecha o ciclo)

    // Kelvin K (U+212A) dobra com 'k'/'K'.
    expect(unicode.simpleFold(r(0x6b)).toInt(), 0x212a); // k -> K(elvin)
    expect(unicode.simpleFold(r(0x212a)).toInt(), 0x4b); // K(elvin) -> K
    expect(unicode.toLower(r(0x212a)).toInt(), 0x6b);

    // Gama grega (U+03B3) está em Greek; 'a' comum não está.
    expect(unicode.is$(unicode.greek, r(0x3b3)), isTrue);
    expect(unicode.is$(unicode.greek, r(0x61)), isFalse);

    // Soft_Dotted: i/j minúsculos têm ponto solto; maiúsculas não.
    expect(unicode.is$(unicode.soft_Dotted, r(0x69)), isTrue); // i
    expect(unicode.is$(unicode.soft_Dotted, r(0x49)), isFalse); // I

    expect(unicode.version, isNotEmpty);
    expect(unicode.maxRune, 0x10ffff);
  });
}
