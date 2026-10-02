// Oráculo Go dos timers do `time` e do `context` em programas inteiros
// (goroutines, `runMain`, detector de deadlock): cada `test/fixtures/<caso>.go`
// roda com o `go` do PATH e o `<caso>.dart` correspondente (o que o g2d
// emitiria) roda na VM, no JS (dart2js/Node) e no Wasm (dart2wasm/Node).
// Saída padrão em bytes, código de saída e a 1ª linha do stderr (`fatal
// error: ...`) têm que ser iguais. Só ordem de eventos: as durações são de
// milissegundos e nenhum caso imprime tempo.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

const _cases = ['timers', 'timer_forgotten', 'contexts'];

const _wasmRunner = '''
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const [mjs, wasm] = process.argv.slice(2);
const mod = await import(pathToFileURL(mjs).href);
const app = await mod.compile(await readFile(wasm));
const instance = await app.instantiate({});
instance.invokeMain();
''';

typedef _Run = ({List<int> stdout, int code, String stderr1});

Future<_Run> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args, stdoutEncoding: null);
  final err = (r.stderr as String).split('\n').first;
  return (stdout: r.stdout as List<int>, code: r.exitCode, stderr1: err);
}

Future<void> _must(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    fail('$exe ${args.join(' ')}: ${r.exitCode}\n${r.stdout}\n${r.stderr}');
  }
}

void _same(String what, _Run got, _Run want) {
  expect(
    String.fromCharCodes(got.stdout),
    String.fromCharCodes(want.stdout),
    reason: '$what: stdout',
  );
  expect(got.stdout, want.stdout, reason: '$what: bytes do stdout');
  expect(got.code, want.code, reason: '$what: código de saída');
  expect(got.stderr1, want.stderr1, reason: '$what: 1ª linha do stderr');
}

void main() {
  late Directory tmp;
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('golib_m4c_');
    await File('${tmp.path}/run_wasm.mjs').writeAsString(_wasmRunner);
  });
  tearDownAll(() => tmp.delete(recursive: true));

  for (final name in _cases) {
    group(name, () {
      late _Run want;
      setUpAll(() async {
        final bin = '${tmp.path}/$name.go.bin';
        await _must('go', ['build', '-o', bin, 'test/fixtures/$name.go']);
        want = await _run(bin, []);
      });

      test('VM', () async {
        _same(
          'vm',
          await _run('dart', ['run', 'test/fixtures/$name.dart']),
          want,
        );
      });

      test('JS', () async {
        final js = '${tmp.path}/$name.js';
        await _must('dart', [
          'compile', 'js', '-O1', '-o', js, 'test/fixtures/$name.dart', //
        ]);
        _same('js', await _run('node', [js]), want);
      });

      test('Wasm', () async {
        final wasm = '${tmp.path}/$name.wasm';
        await _must('dart', [
          'compile', 'wasm', '-o', wasm, 'test/fixtures/$name.dart', //
        ]);
        _same(
          'wasm',
          await _run('node', [
            '${tmp.path}/run_wasm.mjs',
            '${tmp.path}/$name.mjs',
            wasm,
          ]),
          want,
        );
      });
    });
  }
}
