// Mede o custo da ponte em chamadas síncronas (ipfs_ffi/TODO.md):
// `dart run tool/bench.dart`. JSON (IpfsCall) × exports diretos (IpfsD<n>).
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/ipld/merkledag.dart' as merkledag;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/src/runtime.dart' show $bytes, $call, $callSync;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('bench_');
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final cfg = config.initWithIdentity(config.createIdentity([]));
  config.profiles['test']!.transform(cfg);
  final repoPath = '${tmp.path}/r';
  fsrepo.init(repoPath, cfg);
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  final api = coreapi.newCoreApi(n);

  void bench(String what, void Function() f) {
    for (var i = 0; i < 2000; i++) {
      f(); // aquecimento
    }
    const count = 20000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      f();
    }
    print(
        '$what: ${(sw.elapsedMicroseconds / count).toStringAsFixed(1)} µs/chamada');
  }

  bench('api.unixfs() (handle → handle)', () => api.unixfs());
  bench('fsrepo.isInitialized (string → bool)',
      () => fsrepo.isInitialized(repoPath));
  bench('ctx.err() (à mão, direto desde a 0.8.0)', () => ctx.err());
  bench('withTimeout + cancel (à mão, direto)', () {
    final (_, cancel) = context.withTimeout(ctx, const Duration(seconds: 1));
    cancel();
  });

  // bytes e tipos-valor (diretos desde a 0.8.0) × a mesma função pelo JSON
  final kib = Uint8List(1024);
  final raw = merkledag.RawNode(kib);
  const fmt = 'github.com/ipfs/go-ipld-format.Node';
  bench('RawNode(1 KiB) (bytes → handle)', () => merkledag.RawNode(kib));
  bench('  pelo JSON',
      () => $callSync('github.com/ipfs/boxo/ipld/merkledag.NewRawNode', [kib]));
  bench('node.cid() (handle → CID)', () => raw.cid());
  bench('  pelo JSON', () => $callSync('$fmt.Cid', [raw]));
  bench('node.rawData() (handle → 1 KiB)', () => raw.rawData());
  bench('  pelo JSON', () => $bytes($callSync('$fmt.RawData', [raw])));

  // Assíncronas (TODO.md, passo 2): quanto é JSON, quanto é o salto do
  // listener e quanto é o kubo. O IpfsCall síncrono roda a mesma entrada sem
  // goroutine nem listener; o Noop é o piso (JSON mínimo, sem kubo).
  Future<void> benchAsync(String what, Future<Object?> Function() f) async {
    for (var i = 0; i < 500; i++) {
      await f();
    }
    const count = 5000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      await f();
    }
    print(
        '$what: ${(sw.elapsedMicroseconds / count).toStringAsFixed(1)} µs/chamada');
  }

  const noop = 'ipfs_ffi/test.Noop';
  bench(
      'Noop síncrono (IpfsCall, JSON mínimo)', () => $callSync(noop, const []));
  await benchAsync(
      'Noop assíncrono (+ goroutine e listener)', () => $call(noop, const []));
  final p = await api.unixfs().add(ctx, files.newBytesFile(kib));
  const stat = 'github.com/ipfs/kubo/core/coreiface.BlockAPI.Stat';
  final block = api.block();
  await benchAsync(
      'block.stat assíncrono (API gerada)', () => block.stat(ctx, p));
  bench('  mesma entrada síncrona (JSON + kubo)',
      () => $callSync(stat, [block, ctx, p]));
  const resolve = 'github.com/ipfs/kubo/core/coreiface.CoreAPI.ResolvePath';
  await benchAsync(
      'resolvePath assíncrono (API gerada)', () => api.resolvePath(ctx, p));
  bench('  mesma entrada síncrona (JSON + kubo)',
      () => $callSync(resolve, [api, ctx, p]));
  final unixfs = api.unixfs();
  await benchAsync('unixfs.add 1 KiB assíncrono (API gerada)',
      () => unixfs.add(ctx, files.newBytesFile(kib)));

  await n.close();
  tmp.deleteSync(recursive: true);
}
