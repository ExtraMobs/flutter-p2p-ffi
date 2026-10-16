// Os comandos do RPC do kubo pela função 36 (0.14.0): um DTO por retorno,
// Future quando o comando emite um valor, Stream quando emite vários, bytes
// quando emite um io.Reader. Exige `dart run tool/build.dart`.
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late kubo.IpfsNode n;
  late kubo.CoreApi api;
  final ctx = () => context.background();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_cmds_');
    await IpfsService.start();
    kubo.PluginLoader('')
      ..initialize()
      ..inject();
    final cfg =
        kubo.initWithIdentity(kubo.createIdentity([kubo.key.type('ed25519')]));
    kubo.profiles['test']!.transform(cfg);
    kubo.init('${tmp.path}/repo', cfg);
    n = await kubo.newNode(
        ctx(), kubo.BuildCfg(repo: kubo.open('${tmp.path}/repo')));
    api = kubo.newCoreApi(n);
  });

  tearDownAll(() async {
    await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('id e version (Future com DTO)', () async {
    final self = (await api.key().self(ctx())).id!;
    final id = await kubo.id(n, ctx(), null).single;
    expect(id.id, self.value);
    expect(id.agentVersion, startsWith('kubo/'));
    final v = await kubo.version(n, ctx()).single;
    expect(v.version, startsWith('0.43.'));
  });

  test('files: mkdir, write, stat, ls, read e rm', () async {
    await kubo.filesMkdir(n, ctx(), '/c/d', parents: true).drain<void>();
    await kubo
        .filesWrite(n, ctx(), '/c/d/a.txt',
            files.newBytesFile(utf8.encode('olá files')),
            create: true)
        .drain<void>();
    final st = await kubo.filesStat(n, ctx(), '/c/d/a.txt').single;
    expect(st.type, 'file');
    expect(st.size, utf8.encode('olá files').length);
    final ls = await kubo.filesLs(n, ctx(), '/c/d', long: true).single;
    expect([for (final e in ls.entries) e.name], ['a.txt']);
    final read = await kubo.filesRead(n, ctx(), '/c/d/a.txt').toList();
    expect(utf8.decode([for (final b in read) ...b]), 'olá files');
    final part =
        await kubo.filesRead(n, ctx(), '/c/d/a.txt', offset: 5).toList();
    expect(utf8.decode([for (final b in part) ...b]), 'files');
    await kubo.filesRm(n, ctx(), ['/c/d/a.txt']).toList();
    await expectLater(kubo.filesStat(n, ctx(), '/c/d/a.txt').single,
        throwsA(isA<IpfsException>()));
  });

  test('config: valor de uma chave e show (dinâmico)', () async {
    final f = await kubo.config(n, ctx(), 'Datastore.StorageMax', null).single;
    expect(f.key, 'Datastore.StorageMax');
    expect(f.value$, isA<String>());
    final show = await kubo.configShow(n, ctx()).single;
    expect(show['Identity'], isA<Map<String, Object?>>());
  });

  test('bootstrap: add, list e rm', () async {
    final self = (await api.key().self(ctx())).id!;
    final addr = '/ip4/127.0.0.1/tcp/4001/p2p/${self.value}';
    final added = await kubo.bootstrapAdd(n, ctx(), [addr]).single;
    expect(added.peers, [addr]);
    expect((await kubo.bootstrapList(n, ctx()).single).peers, contains(addr));
    await kubo.bootstrapRm(n, ctx(), [addr]).drain<void>();
    expect((await kubo.bootstrapList(n, ctx()).single).peers,
        isNot(contains(addr)));
  });

  test('swarm peering ls: offline, o erro do kubo', () async {
    await expectLater(
        kubo.swarmPeeringLs(n, ctx()).single,
        throwsA(isA<IpfsException>()
            .having((e) => '$e', 'msg', contains('online mode'))));
  });

  test('key list, pin ls e refs local (Stream)', () async {
    final keys = await kubo.keyList(n, ctx()).single;
    expect([for (final k in keys.keys) k.name], contains('self'));
    final p = await api.unixfs().add(ctx(),
        files.newBytesFile(utf8.encode('pinado')), [kubo.unixfs.pin(true, '')]);
    final pins = await kubo.pinLs(n, ctx(), [], type: 'recursive').toList();
    final cid = p.value.substring('/ipfs/'.length);
    expect(pins.expand((w) => w.keys.keys), contains(cid));
    // o blockstore guarda por multihash: o refs local lista CIDv1 raw
    final refs = await kubo.refsLocal(n, ctx()).toList();
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
        await kubo.cidFormat(n, ctx(), [cid], v: '1', b: 'base32').toList();
    expect(f.single.formatted, startsWith('b'));
    final st = await kubo.repoStat(n, ctx()).single;
    expect(st.numObjects, greaterThan(0));
    final out = await kubo.cat(n, ctx(), [p.value]).toList();
    expect(utf8.decode([for (final b in out) ...b]), 'olá cat');
  });

  test('erro do comando vira IpfsException', () async {
    await expectLater(kubo.filesStat(n, ctx(), '/nao/existe').single,
        throwsA(isA<IpfsException>()));
    await expectLater(kubo.cat(n, ctx(), ['/ipfs/nao-e-cid']).toList(),
        throwsA(isA<IpfsException>()));
  });
}
