// Os comandos do RPC do kubo pela função 36 (0.14.0): um DTO por retorno,
// Future quando o comando emite um valor, Stream quando emite vários, bytes
// quando emite um io.Reader. Exige `dart run tool/build.dart`.
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/core/coreiface.dart' as coreiface;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/core/commands.dart' as commands;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late core.IpfsNode n;
  late coreiface.CoreApi api;
  final ctx = () => context.background();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_cmds_');
    await P2pService.start();
    loader.PluginLoader('')
      ..initialize()
      ..inject();
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    fsrepo.init('${tmp.path}/repo', cfg);
    n = await core.newNode(
        ctx(), node.BuildCfg(repo: fsrepo.open('${tmp.path}/repo')));
    api = coreapi.newCoreApi(n);
  });

  tearDownAll(() async {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('id e version (Future com DTO)', () async {
    final self = (await api.key().self(ctx())).id!;
    final id = await commands.id(n, ctx(), null).single;
    expect(id.id, self.value);
    expect(id.agentVersion, startsWith('kubo/'));
    final v = await commands.version(n, ctx()).single;
    expect(v.version, startsWith('0.43.'));
  });

  test('files: mkdir, write, stat, ls, read e rm', () async {
    await commands.filesMkdir(n, ctx(), '/c/d', parents: true).drain<void>();
    await commands
        .filesWrite(n, ctx(), '/c/d/a.txt',
            files.newBytesFile(utf8.encode('olá files')),
            create: true)
        .drain<void>();
    final st = await commands.filesStat(n, ctx(), '/c/d/a.txt').single;
    expect(st.type, 'file');
    expect(st.size, utf8.encode('olá files').length);
    final ls = await commands.filesLs(n, ctx(), '/c/d', long: true).single;
    expect([for (final e in ls.entries) e.name], ['a.txt']);
    final read = await commands.filesRead(n, ctx(), '/c/d/a.txt').toList();
    expect(utf8.decode([for (final b in read) ...b]), 'olá files');
    final part =
        await commands.filesRead(n, ctx(), '/c/d/a.txt', offset: 5).toList();
    expect(utf8.decode([for (final b in part) ...b]), 'files');
    await commands.filesRm(n, ctx(), ['/c/d/a.txt']).toList();
    await expectLater(commands.filesStat(n, ctx(), '/c/d/a.txt').single,
        throwsA(isA<GolangException>()));
  });

  test('config: valor de uma chave e show (dinâmico)', () async {
    final f =
        await commands.config(n, ctx(), 'Datastore.StorageMax', null).single;
    expect(f.key, 'Datastore.StorageMax');
    expect(f.value$, isA<String>());
    final show = await commands.configShow(n, ctx()).single;
    expect(show['Identity'], isA<Map<String, Object?>>());
  });

  test('bootstrap: add, list e rm', () async {
    final self = (await api.key().self(ctx())).id!;
    final addr = '/ip4/127.0.0.1/tcp/4001/p2p/${self.value}';
    final added = await commands.bootstrapAdd(n, ctx(), [addr]).single;
    expect(added.peers, [addr]);
    expect(
        (await commands.bootstrapList(n, ctx()).single).peers, contains(addr));
    await commands.bootstrapRm(n, ctx(), [addr]).drain<void>();
    expect((await commands.bootstrapList(n, ctx()).single).peers,
        isNot(contains(addr)));
  });

  test('swarm peering ls: offline, o erro do kubo', () async {
    await expectLater(
        commands.swarmPeeringLs(n, ctx()).single,
        throwsA(isA<GolangException>()
            .having((e) => '$e', 'msg', contains('online mode'))));
  });

  test('key list, pin ls e refs local (Stream)', () async {
    final keys = await commands.keyList(n, ctx()).single;
    expect([for (final k in keys.keys) k.name], contains('self'));
    final p = await api.unixfs().add(
        ctx(),
        files.newBytesFile(utf8.encode('pinado')),
        [options.unixfs.pin(true, '')]);
    final pins = await commands.pinLs(n, ctx(), [], type: 'recursive').toList();
    final cid = p.value.substring('/ipfs/'.length);
    expect(pins.expand((w) => w.keys.keys), contains(cid));
    // o blockstore guarda por multihash: o refs local lista CIDv1 raw
    final refs = await commands.refsLocal(n, ctx()).toList();
    expect(refs, isNotEmpty);
    expect([for (final r in refs) r.err], everyElement(''));
    expect([for (final r in refs) r.ref], everyElement(startsWith('b')));
  });

  test('cid format (Stream), repo stat e cat (bytes)', () async {
    final p = await api
        .unixfs()
        .add(ctx(), files.newBytesFile(utf8.encode('olá cat')));
    final cid = p.value.substring('/ipfs/'.length);
    final f =
        await commands.cidFormat(n, ctx(), [cid], v: '1', b: 'base32').toList();
    expect(f.single.formatted, startsWith('b'));
    final st = await commands.repoStat(n, ctx()).single;
    expect(st.numObjects, greaterThan(0));
    final out = await commands.cat(n, ctx(), [p.value]).toList();
    expect(utf8.decode([for (final b in out) ...b]), 'olá cat');
  });

  test('erro do comando vira GolangException', () async {
    await expectLater(commands.filesStat(n, ctx(), '/nao/existe').single,
        throwsA(isA<GolangException>()));
    await expectLater(commands.cat(n, ctx(), ['/ipfs/nao-e-cid']).toList(),
        throwsA(isA<GolangException>()));
  });
}
