// A API gerada (go/gen) na ordem em que o kubo monta um nó: plugins →
// identidade e config → fsrepo.Init/Open → core.NewNode → CoreAPI → Unixfs
// (M1) → pins, blocos e GC (M2).
import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/path.dart' as path;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/corerepo.dart' as corerepo;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/os.dart' as os;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late core.IpfsNode n;
  late iface.CoreApi api;
  final ctx = context.background();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_kubo_');
    final repoPath = '${tmp.path}/repo';

    // Plugins: uma vez por processo (como o setupPlugins do kubo-as-a-library).
    final plugins = loader.PluginLoader('');
    plugins.initialize();
    plugins.inject();

    // ipfs init
    final identity = config.createIdentity([options.key.type('ed25519')]);
    final cfg = config.initWithIdentity(identity);
    config.profiles['test']!.transform(cfg); // portas aleatórias, sem bootstrap
    expect(fsrepo.isInitialized(repoPath), isFalse);
    fsrepo.init(repoPath, cfg);
    expect(fsrepo.isInitialized(repoPath), isTrue);

    // nó offline sobre o repo em disco
    final repo = fsrepo.open(repoPath);
    n = await core.newNode(ctx, node.BuildCfg(repo: repo));
    api = coreapi.newCoreApi(n);
  });

  tearDownAll(() async {
    await n.close();
    tmp.deleteSync(recursive: true);
  });

  test('add e get de bytes', () async {
    final p = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('olá ipfs')));
    expect(p.value, startsWith('/ipfs/Qm')); // padrão do kubo: CIDv0
    final got = await api.unixfs().get(ctx, p);
    expect(utf8.decode(io.readAll(files.toFile(got))), 'olá ipfs');
  });

  test('opções do add (CIDv1, raw leaves)', () async {
    final p = await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('x')),
        [options.unixfs.cidVersion(1), options.unixfs.rawLeaves(true)]);
    expect(p.value, startsWith('/ipfs/bafkrei'));
  });

  test('diretório do disco: add, ls, resolvePath e writeTo', () async {
    final dir = Directory('${tmp.path}/in')..createSync();
    File('${dir.path}/a.txt').writeAsStringSync('A');
    File('${dir.path}/b.txt').writeAsStringSync('BB');

    final root = await api
        .unixfs()
        .add(ctx, files.newSerialFile(dir.path, false, os.stat(dir.path)));
    final entries = await api.unixfs().ls(ctx, root).toList();
    expect([for (final e in entries) e.name], ['a.txt', 'b.txt']);
    expect([for (final e in entries) e.size], [1, 2]);

    final (resolved, rest) =
        await api.resolvePath(ctx, path.Path('${root.value}/b.txt'));
    expect(resolved.value, startsWith('/ipfs/'));
    expect(rest, isEmpty);

    final out = '${tmp.path}/out';
    files.writeTo(await api.unixfs().get(ctx, root), out);
    expect(File('$out/b.txt').readAsStringSync(), 'BB');
  });

  test('context: cancelado e com prazo vencido', () async {
    final (c, cancel) = context.withCancel(context.background());
    expect(c.err(), isNull);
    cancel();
    expect(c.err(), 'context canceled');
    await expectLater(api.unixfs().add(c, files.newBytesFile(utf8.encode('y'))),
        throwsA(isA<IpfsException>()));

    final (t, cancelT) =
        context.withTimeout(context.background(), Duration.zero);
    expect(t.err(), 'context deadline exceeded');
    cancelT();
  });

  test('erros do Go viram IpfsException, inclusive panic', () async {
    await expectLater(api.resolvePath(ctx, path.Path('não é path')),
        throwsA(isA<IpfsException>()));
    // handle inválido: o Go entra em panic e o recover vira exceção
    await expectLater(
        core.IpfsNode.$h(1 << 40).close(),
        throwsA(isA<IpfsException>()
            .having((e) => e.message, 'message', contains('panic'))));
  });

  // M2: pins, blocos e GC
  Future<path.ImmutablePath> addUnpinned(String s) => api.unixfs().add(
      ctx, files.newBytesFile(utf8.encode(s)), [options.unixfs.pin(false, '')]);

  test('pin add, isPinned, ls, update e rm', () async {
    final a = await addUnpinned('pin a');
    final b = await addUnpinned('pin b');
    expect((await api.pin().isPinned(ctx, a)).$2, isFalse);

    await api.pin().add(ctx, a, [options.pin.name('meu-pin')]);
    final (how, pinned) = await api.pin().isPinned(ctx, a);
    expect((how, pinned), ('recursive', true));
    // o filtro por nome só vale com detailed (como `ipfs pin ls --names`)
    final pins = await api.pin().ls(ctx, [
      options.pin.ls.recursive(),
      options.pin.ls.detailed(true),
      options.pin.ls.name('meu-pin'),
    ]).toList();
    expect([for (final p in pins) p.path?.value], [a.value]);
    expect(pins.single.name, 'meu-pin');

    await api.pin().update(ctx, a, b); // move o pin de a para b
    expect((await api.pin().isPinned(ctx, a)).$2, isFalse);
    expect((await api.pin().isPinned(ctx, b)).$2, isTrue);

    await api.pin().rm(ctx, b);
    expect((await api.pin().isPinned(ctx, b)).$2, isFalse);
    expect(await api.pin().verify(ctx).every((s) => s.ok && s.err == null),
        isTrue);
  });

  test('block put, stat, get e rm', () async {
    final data = utf8.encode('bloco cru');
    final st = await api.block().put(ctx, data, [options.block.pin(false)]);
    expect(st.size, data.length);
    expect(st.path!.value, startsWith('/ipfs/bafkrei')); // raw + sha2-256

    expect((await api.block().stat(ctx, st.path!)).size, data.length);
    final r = await api.block().get(ctx, st.path!);
    expect(io.readAll(r), data);

    await api.block().rm(ctx, st.path!);
    await expectLater(
        api.block().stat(ctx, st.path!), throwsA(isA<IpfsException>()));
  });

  test('GC apaga o que não está pinado e mantém o pinado', () async {
    final loose = await addUnpinned('solto ${DateTime.now()}');
    // a CoreAPI não pina por padrão (o `ipfs add` do CLI é que passa pin=true)
    final kept = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('pinado ${DateTime.now()}')),
        [options.unixfs.pin(true, '')]);

    final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
    // O blockstore guarda pelo multihash: o GC informa CIDv1 raw (bafkrei...),
    // não o CIDv0 (Qm...) do add.
    expect(removed, isNotEmpty);
    expect([for (final r in removed) r.error], everyElement(isNull));

    await expectLater(
        api.block().stat(ctx, loose), throwsA(isA<IpfsException>()));
    expect((await api.block().stat(ctx, kept)).size, greaterThan(0));
    await corerepo.garbageCollect(n, ctx); // a versão que só espera
  });
}
