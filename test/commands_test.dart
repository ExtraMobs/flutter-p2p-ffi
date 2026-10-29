// Os comandos do RPC do kubo pela função 36 (0.14.0): um DTO por retorno,
// Future quando o comando emite um valor, Stream quando emite vários, bytes
// quando emite um io.Reader. Exige `dart run tool/build.dart`.
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late KuboCoreIpfsNode n;
  late KuboCoreCoreifaceCoreApi api;
  final ctx = () => go.context.background();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('p2p_ffi_cmds_');
    await P2pService.start();
    KuboPluginLoader('')
      ..initialize()
      ..inject();
    final cfg = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
        .createIdentity(
            null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
    go.ipfs.kubo.config.profiles['test']!.transform(cfg);
    go.ipfs.kubo.repo.fsrepo.init('${tmp.path}/repo', cfg);
    n = await go.ipfs.kubo.core.newNode(
        ctx(),
        KuboCoreNodeBuildCfg(
            repo: go.ipfs.kubo.repo.fsrepo.open('${tmp.path}/repo')));
    api = go.ipfs.kubo.core.coreapi.newCoreApi(n);
  });

  tearDownAll(() async {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('id e version (Future com DTO)', () async {
    final self = (await api.key().self(ctx())).id!;
    final id = await go.ipfs.kubo.core.commands.id(n, ctx(), null).single;
    expect(id.id, self.value);
    expect(id.agentVersion, startsWith('kubo/'));
    final v = await go.ipfs.kubo.core.commands.version(n, ctx()).single;
    expect(v.version, startsWith('0.43.'));
  });

  test('files: mkdir, write, stat, ls, read e rm', () async {
    await go.ipfs.kubo.core.commands
        .filesMkdir(n, ctx(), '/c/d', parents: true)
        .drain<void>();
    await go.ipfs.kubo.core.commands
        .filesWrite(n, ctx(), '/c/d/a.txt',
            go.ipfs.boxo.files.newBytesFile(utf8.encode('olá files')),
            create: true)
        .drain<void>();
    final st = await go.ipfs.kubo.core.commands
        .filesStat(n, ctx(), '/c/d/a.txt')
        .single;
    expect(st.type, 'file');
    expect(st.size, utf8.encode('olá files').length);
    final ls = await go.ipfs.kubo.core.commands
        .filesLs(n, ctx(), '/c/d', long: true)
        .single;
    expect([for (final e in ls.entries) e.name], ['a.txt']);
    final read = await go.ipfs.kubo.core.commands
        .filesRead(n, ctx(), '/c/d/a.txt')
        .toList();
    expect(utf8.decode([for (final b in read) ...b]), 'olá files');
    final part = await go.ipfs.kubo.core.commands
        .filesRead(n, ctx(), '/c/d/a.txt', offset: 5)
        .toList();
    expect(utf8.decode([for (final b in part) ...b]), 'files');
    await go.ipfs.kubo.core.commands.filesRm(n, ctx(), ['/c/d/a.txt']).toList();
    await expectLater(
        go.ipfs.kubo.core.commands.filesStat(n, ctx(), '/c/d/a.txt').single,
        throwsA(isA<GolangException>()));
  });

  test('config: valor de uma chave e show (dinâmico)', () async {
    final f = await go.ipfs.kubo.core.commands
        .config(n, ctx(), 'Datastore.StorageMax', null)
        .single;
    expect(f.key, 'Datastore.StorageMax');
    expect(f.value$, isA<String>());
    final show = await go.ipfs.kubo.core.commands.configShow(n, ctx()).single;
    expect(show['Identity'], isA<Map<String, Object?>>());
  });

  test('bootstrap: add, list e rm', () async {
    final self = (await api.key().self(ctx())).id!;
    final addr = '/ip4/127.0.0.1/tcp/4001/p2p/${self.value}';
    final added =
        await go.ipfs.kubo.core.commands.bootstrapAdd(n, ctx(), [addr]).single;
    expect(added.peers, [addr]);
    expect(
        (await go.ipfs.kubo.core.commands.bootstrapList(n, ctx()).single).peers,
        contains(addr));
    await go.ipfs.kubo.core.commands
        .bootstrapRm(n, ctx(), [addr]).drain<void>();
    expect(
        (await go.ipfs.kubo.core.commands.bootstrapList(n, ctx()).single).peers,
        isNot(contains(addr)));
  });

  test('swarm peering ls: offline, o erro do kubo', () async {
    await expectLater(
        go.ipfs.kubo.core.commands.swarmPeeringLs(n, ctx()).single,
        throwsA(isA<GolangException>()
            .having((e) => '$e', 'msg', contains('online mode'))));
  });

  test('key list, pin ls e refs local (Stream)', () async {
    final keys = await go.ipfs.kubo.core.commands.keyList(n, ctx()).single;
    expect([for (final k in keys.keys) k.name], contains('self'));
    final p = await api.unixfs().add(
        ctx(),
        go.ipfs.boxo.files.newBytesFile(utf8.encode('pinado')),
        [go.ipfs.kubo.core.coreiface.options.unixfs.pin(true, '')]);
    final pins = await go.ipfs.kubo.core.commands
        .pinLs(n, ctx(), [], type: 'recursive')
        .toList();
    final cid = p.value.substring('/ipfs/'.length);
    expect(pins.expand((w) => w.keys.keys), contains(cid));
    // o blockstore guarda por multihash: o refs local lista CIDv1 raw
    final refs = await go.ipfs.kubo.core.commands.refsLocal(n, ctx()).toList();
    expect(refs, isNotEmpty);
    expect([for (final r in refs) r.err], everyElement(''));
    expect([for (final r in refs) r.ref], everyElement(startsWith('b')));
  });

  test('cid format (Stream), repo stat e cat (bytes)', () async {
    final p = await api
        .unixfs()
        .add(ctx(), go.ipfs.boxo.files.newBytesFile(utf8.encode('olá cat')));
    final cid = p.value.substring('/ipfs/'.length);
    final f = await go.ipfs.kubo.core.commands
        .cidFormat(n, ctx(), [cid], v: '1', b: 'base32')
        .toList();
    expect(f.single.formatted, startsWith('b'));
    final st = await go.ipfs.kubo.core.commands.repoStat(n, ctx()).single;
    expect(st.numObjects, greaterThan(0));
    final out =
        await go.ipfs.kubo.core.commands.cat(n, ctx(), [p.value]).toList();
    expect(utf8.decode([for (final b in out) ...b]), 'olá cat');
  });

  test('erro do comando vira GolangException', () async {
    await expectLater(
        go.ipfs.kubo.core.commands.filesStat(n, ctx(), '/nao/existe').single,
        throwsA(isA<GolangException>()));
    await expectLater(
        go.ipfs.kubo.core.commands.cat(n, ctx(), ['/ipfs/nao-e-cid']).toList(),
        throwsA(isA<GolangException>()));
  });
}
