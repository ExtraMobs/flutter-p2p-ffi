// Lesson 07 · What is a repo, and why `init`?
//
// Question: lessons 03-06 built the stack by hand, in memory, and lost it at
// the end. An IPFS node keeps its blocks, its identity and its settings
// between runs. Where, and what has to exist before the node can start?
//
// Answer: in a repo, a folder on disk created once by `init` (the
// `ipfs init` of the command line). It holds:
//   - the identity: a key pair. The public key, hashed, is the peer ID: the
//     node's name on the network (lesson 13). The private key signs.
//   - the config: kubo's JSON settings (where the blocks go, which addresses
//     to listen on, which peers to bootstrap from, routing...). Profiles are
//     ready-made changes to it (`test`, `server`, `lowpower`, `randomports`...).
//   - the datastore and the blockstore of lesson 03, now on disk (flatfs
//     for blocks, leveldb or pebble for the rest), plus the keystore (the
//     extra keys of lesson 11).
// The datastores are kubo plugins: they are loaded into the service once,
// before any repo is opened.
//
// Needs: lesson 01 (the service). Technically: the plugins (so the repo's
// datastore spec can be built), an identity (a key) and a config built from
// it; open needs a folder already initialized and not in use by another
// process.
//
//   dart run example/en_us/07_repo_and_init.dart
//
// Next question: "And what does the node do with this repo?" → lesson 08.
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson07_');
  final dir = '${tmp.path}/repo';
  try {
    // 1. The plugins, once per service process.
    //    Go:  plugins, _ := loader.NewPluginLoader("")
    //         plugins.Initialize(); plugins.Inject()
    final plugins = KuboPluginLoader('');
    plugins.initialize();
    plugins.inject();
    say('plugins loaded (the datastores are now known to kubo)');

    // 2. The identity: a new ed25519 key; the peer ID comes from it.
    //    Go:  id, _ := config.CreateIdentity(io.Discard, []options.KeyGenerateOption{
    //             options.Key.Type("ed25519")})
    final identity = goKubo.config.createIdentity(
        null, [goKubo.core.coreiface.options.key.type('ed25519')]);
    say('\nidentity: peer ID ${identity.peerId}');
    say('  (the private key stays in the config: whoever has it IS this peer)');

    // 3. The config from the identity, then a profile on top.
    //    Go:  cfg, _ := config.InitWithIdentity(id)
    //         config.Profiles["test"].Transform(cfg)
    final cfg = goKubo.config.initWithIdentity(identity);
    final before = (cfg.json['Addresses'] as Map)['Swarm'];
    goKubo.config.profiles['test']!.transform(cfg);
    final after = (cfg.json['Addresses'] as Map)['Swarm'];
    say('\nconfig: listening on $before by default');
    say('  after the `test` profile: $after, bootstrap peers '
        '${(cfg.json['Bootstrap'] as List).length}');
    say('  profiles kubo knows: ${goKubo.config.profiles.keys.join(', ')}');

    // 4. init writes the folder; open locks it for this process.
    //    Go:  fsrepo.Init(dir, cfg); r, _ := fsrepo.Open(dir)
    say('\ninitialized before init: ${goKubo.repo.fsrepo.isInitialized(dir)}');
    goKubo.repo.fsrepo.init(dir, cfg);
    say('initialized after init:  ${goKubo.repo.fsrepo.isInitialized(dir)}');
    void listFolder(String when) {
      final entries = Directory(dir).listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      say('in the folder $when: ${entries.map((e) {
        final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        return e is Directory ? '$name/' : name;
      }).join(', ')}');
    }

    listFolder('after init');
    final repo = goKubo.repo.fsrepo.open(dir);
    listFolder('after open (the datastores are created on first open)');
    final stored = repo.config();
    say('\nopened; the config read back from disk has the same peer ID: '
        '${(stored.json['Identity'] as Map)['PeerID'] == identity.peerId}');
    final spec = (stored.json['Datastore'] as Map)['Spec'] as Map;
    say('  datastore spec: ${spec['type']} with '
        '${(spec['mounts'] as List).map((m) => (m as Map)['mountpoint']).join(', ')}');

    // 5. A config key can be read and changed on the open repo.
    //    Go:  r.SetConfigKey("Datastore.StorageMax", "1GB")
    repo.setConfigKey('Datastore.StorageMax', '1GB');
    say('  Datastore.StorageMax now: '
        '${repo.getConfigKey('Datastore.StorageMax')}');
    repo.close();

    say('\n== Common mistakes\n');
    final other = goKubo.config.initWithIdentity(goKubo.config.createIdentity(
        null, [goKubo.core.coreiface.options.key.type('ed25519')]));
    await silentlyWrong('init again, expecting the new config to replace it',
        why: 'init on a folder that already is a repo does nothing (no '
            'error): the identity inside is never overwritten',
        instead: 'change an existing repo with setConfig/setConfigKey (step '
            '5); a new identity means a new folder',
        wrong: () {
          goKubo.repo.fsrepo.init(dir, other);
          final r = goKubo.repo.fsrepo.open(dir);
          final id = (r.config().json['Identity'] as Map)['PeerID'];
          r.close();
          return 'peer ID in the repo: $id';
        },
        right: () => "the new config's peer ID: "
            '${(other.json['Identity'] as Map)['PeerID']}');
    await mistake('open a folder that was never initialized',
        why: 'there is no config, no identity, no datastore to open',
        instead: 'init once (steps 2-4), open every other time',
        action: () => goKubo.repo.fsrepo.open('${tmp.path}/nothing-here'));
    await mistake('loading the plugins twice in the same service',
        why: 'each datastore plugin registers itself once in Go',
        instead: 'load them once per service, right after P2pService.start()',
        action: () => KuboPluginLoader('')
          ..initialize()
          ..inject());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
