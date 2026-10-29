// Mede o custo da ponte com o kubo no p2p_host (TODO.md, 0.9.0):
// `dart run tool/bench.dart` (exige `dart run tool/build.dart`). Chamadas
// síncronas e assíncronas reais da API gerada, com o Noop (função 0) de piso.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:p2p_ffi/src/runtime.dart' show $call, $callSync;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('bench_');
  await P2pService.start();
  KuboPluginLoader('')
    ..initialize()
    ..inject();
  final cfg =
      Go.kubo.config.initWithIdentity(Go.kubo.config.createIdentity(null, []));
  Go.kubo.config.profiles['test']!.transform(cfg);
  final repoPath = '${tmp.path}/r';
  Go.kubo.repo.fsrepo.init(repoPath, cfg);
  final ctx = Go.context.background();
  final n = await Go.kubo.core.newNode(
      ctx, KuboCoreNodeBuildCfg(repo: Go.kubo.repo.fsrepo.open(repoPath)));
  final api = Go.kubo.core.coreapi.newCoreApi(n);

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
      () => Go.kubo.repo.fsrepo.isInitialized(repoPath));
  bench('ctx.err() (à mão)', () => ctx.err());
  bench('withTimeout + cancel (à mão, 2 chamadas)', () {
    final (_, cancel) = Go.context.withTimeout(ctx, const Duration(seconds: 1));
    cancel();
  });

  final kib = Uint8List(1024);
  final raw = BoxoIpldMerkledagRawNode(kib);
  bench('RawNode(1 KiB) (bytes → handle)', () => BoxoIpldMerkledagRawNode(kib));
  bench('node.cid() (handle → CID)', () => raw.cid());
  bench('node.rawData() (handle → 1 KiB)', () => raw.rawData());

  // Assíncronas: o Noop é o piso (canal + Future, sem kubo).
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

  bench('Noop síncrono (função 0, piso do canal)', () => $callSync(0));
  await benchAsync('Noop assíncrono (função 0)', () => $call(0));
  final p = await api.unixfs().add(ctx, Go.boxo.files.newBytesFile(kib));
  final block = api.block();
  await benchAsync('block.stat assíncrono', () => block.stat(ctx, p));
  await benchAsync('resolvePath assíncrono', () => api.resolvePath(ctx, p));
  final unixfs = api.unixfs();
  await benchAsync('unixfs.add 1 KiB assíncrono',
      () => unixfs.add(ctx, Go.boxo.files.newBytesFile(kib)));

  await n.close();
  await P2pService.stop();
  tmp.deleteSync(recursive: true);
}
