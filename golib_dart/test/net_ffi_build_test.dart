// Rede FFI (E1) em processo inteiro e por compilador:
//
// - `fixtures/ffi_smoke.dart` (poller, connect/accept, ponte) termina sozinho
//   com o poller vivo, na VM (`dart run`) e compilado AOT
//   (`dart compile exe`), com a mesma saída.
// - F1: `fixtures/ffi_net_entry.dart`, que importa o shim `net` (e o ponto
//   condicional da rede FFI), compila com dart2js e dart2wasm e roda no
//   Node; o controle negativo `fixtures/ffi_direct_entry.dart` (import
//   direto) é recusado pelos dois por causa de `dart:ffi`.
@TestOn('vm && linux')
library;

import 'dart:io';

import 'package:test/test.dart';

const _smokeOut = '''
prazo: i/o timeout
leitura: ping
accept: par 127.0.0.1 porta igual true
ponte: fd do FFI fechado true, remoto 127.0.0.1:true
dart:io → FFI: olá
FFI → dart:io: eco
cancelado: operation was canceled
fim
''';

const _wasmRunner = '''
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const [mjs, wasm] = process.argv.slice(2);
const mod = await import(pathToFileURL(mjs).href);
const app = await mod.compile(await readFile(wasm));
const instance = await app.instantiate({});
instance.invokeMain();
''';

/// Roda e exige saída 0 dentro de [limit] (a VM não pode ficar pendurada
/// no poller).
Future<String> _run(
  String exe,
  List<String> args, {
  Duration limit = const Duration(seconds: 60),
}) async {
  final p = await Process.start(exe, args);
  final out = p.stdout.transform(const SystemEncoding().decoder).join();
  final err = p.stderr.transform(const SystemEncoding().decoder).join();
  final code = await p.exitCode.timeout(
    limit,
    onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return -999;
    },
  );
  if (code != 0) {
    fail('$exe ${args.join(' ')}: saída $code\n${await out}\n${await err}');
  }
  return out;
}

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  late Directory tmp;
  final node = _hasNode();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('net_ffi_build');
    await File('${tmp.path}/run_wasm.mjs').writeAsString(_wasmRunner);
  });
  tearDownAll(() => tmp.delete(recursive: true));

  test('VM: o programa termina sozinho com o poller vivo', () async {
    final sw = Stopwatch()..start();
    final out = await _run(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/ffi_smoke.dart',
    ], limit: const Duration(seconds: 30));
    expect(out, _smokeOut);
    // Encerrar espera no máximo uma fatia de `poll` (250 ms) do auxiliar.
    expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
  });

  test('AOT (dart compile exe): mesma saída, termina sozinho', () async {
    final exe = '${tmp.path}/ffi_smoke';
    await _run(Platform.resolvedExecutable, [
      'compile', 'exe', '-o', exe, 'test/fixtures/ffi_smoke.dart', //
    ], limit: const Duration(minutes: 3));
    final sw = Stopwatch()..start();
    expect(await _run(exe, [], limit: const Duration(seconds: 10)), _smokeOut);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('JS (dart2js): o net compila sem dart:ffi', () async {
    final js = '${tmp.path}/entry.js';
    await _run(Platform.resolvedExecutable, [
      'compile', 'js', '-O1', '-o', js, 'test/fixtures/ffi_net_entry.dart', //
    ], limit: const Duration(minutes: 3));
    expect(await _run('node', [js]), 'ffi false\nip ok\n');
  }, skip: node ? false : 'sem node');

  test('Wasm (dart2wasm): o net compila sem dart:ffi', () async {
    final wasm = '${tmp.path}/entry.wasm';
    await _run(Platform.resolvedExecutable, [
      'compile', 'wasm', '-o', wasm, 'test/fixtures/ffi_net_entry.dart', //
    ], limit: const Duration(minutes: 3));
    expect(
      await _run('node', [
        '${tmp.path}/run_wasm.mjs',
        '${tmp.path}/entry.mjs',
        wasm,
      ]),
      'ffi false\nip ok\n',
    );
  }, skip: node ? false : 'sem node');

  for (final target in ['js', 'wasm']) {
    test('controle: import direto da rede FFI é recusado ($target)', () async {
      final r = await Process.run(Platform.resolvedExecutable, [
        'compile',
        target,
        '-o',
        '${tmp.path}/direct.$target',
        'test/fixtures/ffi_direct_entry.dart',
      ]);
      expect(r.exitCode, isNot(0));
      expect(
        '${r.stdout}${r.stderr}',
        contains("Dart library 'dart:ffi' is not available on this platform"),
      );
    });
  }
}
