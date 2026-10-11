// Mede o custo da ponte em chamadas síncronas (ipfs_ffi/TODO.md):
// `dart run tool/bench.dart`. JSON (IpfsCall) × exports diretos (IpfsD<n>).
import 'dart:io';

import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

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
  bench('ctx.err() (à mão, sempre JSON)', () => ctx.err());

  await n.close();
  tmp.deleteSync(recursive: true);
}
