// Fumaça de todos os comandos do RPC (0.15.0): cada comando gerado
// (test/src/commands_smoke.dart, saída do go/gen) roda num nó offline com
// argumentos plausíveis. Erro do próprio kubo (GolangException: "online mode",
// argumento inválido...) é resposta válida; falha é erro de protocolo: um DTO
// que não decodifica, um item de outro tipo, o host que cai ou um comando que
// não termina nem pelo prazo do ctx. Por fim, os comandos de rede em dois nós
// online. Exige `dart run tool/build.dart`.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

import 'src/commands_smoke.dart';

/// Os que mudam o nó: rodam por último, para não tirar dos outros o CID, a
/// chave e o MFS que eles usam.
const _last = {
  'block rm', 'bootstrap rm', 'bootstrap rm all', 'config profile apply', //
  'config replace', 'files rm', 'key rm', 'key rotate', 'pin rm', 'repo gc',
};

/// Os que, por desenho, só param quando o ctx vence (fluxos contínuos).
const _endless = {'log tail', 'pubsub sub', 'name pubsub subs', 'stats bw'};

final class _Args implements SmokeArgs {
  _Args(this.node, this.ctx, this.cid, this.self);

  @override
  final KuboCoreIpfsNode node;
  @override
  Context ctx;
  final String cid, self;

  @override
  String s(String cmd, String arg) => switch ((cmd, arg)) {
        ('files cp', 'source') => '/ipfs/$cid',
        ('files cp', 'dest') => '/smoke/copy',
        ('files mv', 'source') => '/smoke/copy',
        ('files mv', 'dest') => '/smoke/moved',
        (final c, 'path') when c.startsWith('files') => '/smoke/a.txt',
        (final c, 'key') when c.startsWith('config') => 'Datastore.StorageMax',
        (final c, 'key') when c.startsWith('dht') || c.startsWith('routing') =>
          '/ipns/$self',
        (final c, 'key') when c.startsWith('name') => 'smoke-key',
        (final c, 'name') when c.startsWith('key') => 'smoke-key',
        (_, 'newName') => 'smoke-key2',
        (_, 'cid' || 'ref' || 'root' || 'obj' || 'obj_a' || 'obj_b' || 'key') =>
          cid,
        (_, 'ipfs-path' || 'path' || 'from-path' || 'to-path') => '/ipfs/$cid',
        (_, 'peer' || 'peerID' || 'ID') => self,
        (_, 'address' || 'target-address') => '/ip4/127.0.0.1/tcp/1/p2p/$self',
        (_, 'listen-address') => '/ip4/127.0.0.1/tcp/0',
        (_, 'topic') => 'smoke',
        (_, 'value') => '1',
        (_, 'profile') => 'test',
        (_, 'name') => '/ipns/$self',
        _ => 'x',
      };

  @override
  BoxoFilesNode f(String cmd, String arg) =>
      goBoxo.files.newBytesFile(utf8.encode(switch (arg) {
        'data' when cmd.startsWith('dag') => '{"a": 1}',
        _ => 'smoke $cmd',
      }));
}

void main() {
  late Directory tmp;
  late KuboCoreIpfsNode n;
  late KuboCoreCoreifaceCoreApi api;
  final ctx = () => goContext.background();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('p2p_ffi_smoke_');
    await P2pService.start();
    KuboPluginLoader('')
      ..initialize()
      ..inject();
  });

  tearDownAll(() async {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  });

  Future<(KuboCoreIpfsNode, KuboCoreCoreifaceCoreApi)> newNode(String name,
      {bool online = false}) async {
    final cfg = goKubo.config.initWithIdentity(goKubo.config.createIdentity(
        null, [goKubo.core.coreiface.options.key.type('ed25519')]));
    goKubo.config.profiles['test']!.transform(cfg);
    goKubo.repo.fsrepo.init('${tmp.path}/$name', cfg);
    final n = await goKubo.core.newNode(
        ctx(),
        KuboCoreNodeBuildCfg(
            repo: goKubo.repo.fsrepo.open('${tmp.path}/$name'),
            online: online,
            routing: online ? goKubo.core.node.libp2p.dhtServerOption : null,
            extraOpts: {'pubsub': true}));
    return (n, goKubo.core.coreapi.newCoreApi(n));
  }

  test('todos os comandos num nó offline: nenhum erro de protocolo', () async {
    (n, api) = await newNode('offline');
    final p = await api.unixfs().add(
        ctx(),
        goBoxo.files.newBytesFile(utf8.encode('smoke')),
        [goKubo.core.coreiface.options.unixfs.pin(true, '')]);
    final cid = p.value.substring('/ipfs/'.length);
    final self = (await api.key().self(ctx())).id!.value;
    await goKubo.core.commands.filesMkdir(n, ctx(), '/smoke').drain<void>();
    await goKubo.core.commands
        .filesWrite(n, ctx(), '/smoke/a.txt',
            goBoxo.files.newBytesFile(utf8.encode('olá')),
            create: true)
        .drain<void>();
    await api.key().generate(ctx(), 'smoke-key',
        [goKubo.core.coreiface.options.key.type('ed25519')]);

    final args = _Args(n, ctx(), cid, self);
    final names = smokeCommands.keys.toList()
      ..sort(
          (a, b) => (_last.contains(a) ? 1 : 0) - (_last.contains(b) ? 1 : 0));
    var values = 0;
    final kuboErrors = <String>[], failures = <String>[];
    for (final name in names) {
      final (c, cancel) =
          goContext.withTimeout(ctx(), const Duration(seconds: 10));
      args.ctx = c;
      try {
        final out = await smokeCommands[name]!(args)
            .toList()
            .timeout(const Duration(seconds: 30));
        values += out.length;
      } on P2pServiceException catch (e) {
        failures.add('$name: o host caiu: $e');
        break;
      } on GolangException catch (e) {
        final m = '$e';
        if (m.contains('not its declared type')) {
          failures.add('$name: $m');
        } else if (!_endless.contains(name) || !m.contains('deadline')) {
          kuboErrors.add('$name: ${m.split('\n').first}');
        }
      } on TimeoutException {
        failures.add('$name: não terminou em 30 s (o ctx venceu em 10 s)');
      } catch (e, st) {
        failures.add('$name: ${e.runtimeType}: $e\n$st');
      } finally {
        cancel();
      }
    }
    // ignore: avoid_print
    print('${names.length} comandos; $values valores decodificados; '
        '${kuboErrors.length} erros do kubo:\n  ${kuboErrors.join('\n  ')}');
    expect(failures, isEmpty, reason: failures.join('\n'));
    await n.close();
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('comandos de rede em dois nós online', () {
    late KuboCoreIpfsNode na, nb;
    late KuboCoreCoreifaceCoreApi a;
    late String idA, cid;

    setUpAll(() async {
      (na, a) = await newNode('a', online: true);
      (nb, _) = await newNode('b', online: true);
      idA = (await a.key().self(ctx())).id!.value;
      final addrs = await a.swarm().localAddrs(ctx());
      await goKubo.core.commands.swarmConnect(
          nb, ctx(), ['${addrs.first.value}/p2p/$idA']).drain<void>();
      final p = await a.unixfs().add(ctx(),
          goBoxo.files.newBytesFile(utf8.encode('rede ${DateTime.now()}')));
      cid = p.value.substring('/ipfs/'.length);
    });

    tearDownAll(() async {
      await na.close();
      await nb.close();
    });

    test('swarm peers e ping', () async {
      final peers = await goKubo.core.commands.swarmPeers(nb, ctx()).single;
      expect([for (final p in peers.peers) p.peer], contains(idA));
      final pings =
          await goKubo.core.commands.ping(nb, ctx(), [idA], count: 2).toList();
      expect(pings.where((r) => r.success), isNotEmpty);
    });

    test('routing provide e findprovs', () async {
      await goKubo.core.commands.routingProvide(na, ctx(), [cid]).drain<void>();
      final (c, cancel) =
          goContext.withTimeout(ctx(), const Duration(seconds: 30));
      try {
        final events = await goKubo.core.commands
            .routingFindprovs(nb, c, [cid], numProviders: 1)
            .toList();
        expect([
          for (final e in events)
            for (final r in e.responses) r.id?.value
        ], contains(idA));
      } finally {
        cancel();
      }
    });

    test('pubsub: sub em A, pub em B', () async {
      final got = Completer<String>();
      final sub =
          goKubo.core.commands.pubsubSub(na, ctx(), 'smoke-rede').listen((m) {
        if (!got.isCompleted) got.complete(m.from);
      });
      // a assinatura propaga entre os nós antes da primeira mensagem
      for (var i = 0; i < 20 && !got.isCompleted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await goKubo.core.commands
            .pubsubPub(nb, ctx(), 'smoke-rede',
                goBoxo.files.newBytesFile(Uint8List.fromList([i])))
            .drain<void>();
      }
      expect(await got.future.timeout(const Duration(seconds: 5)), isNotEmpty);
      await sub.cancel();
    });

    test('name publish e resolve', () async {
      final e = await goKubo.core.commands
          .namePublish(na, ctx(), '/ipfs/$cid', allowOffline: true)
          .single;
      final r = await goKubo.core.commands
          .nameResolve(na, ctx(), '/ipns/${e.name}')
          .single;
      expect(r.path, '/ipfs/$cid');
    });
  });
}
