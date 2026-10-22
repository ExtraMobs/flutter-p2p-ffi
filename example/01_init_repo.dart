// Kubo step 1 (`ipfs init`): plugins, identity, config and the repo on disk.
//
//   dart run example/01_init_repo.dart [repo] [profile...]
//
// Default: ./.ipfs-ffi with the `test` profile (random ports, no
// bootstrap). Kubo profiles: server, lowpower, randomports, flatfs...
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart' show P2pService;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';
  final profiles = args.length > 1 ? args.sublist(1) : ['test'];

  // Kubo runs in the ipfs_host, in another process (dart run tool/build.dart).
  await P2pService.start();
  // Plugins (flatfs/leveldb/pebble datastores...): once per service
  // process, before any repo.
  final plugins = loader.PluginLoader('');
  plugins.initialize();
  plugins.inject();

  if (fsrepo.isInitialized(repoPath)) {
    print('a repo already exists at $repoPath');
    await P2pService.stop();
    return;
  }
  final identity = config.createIdentity(null, [options.key.type('ed25519')]);
  final cfg = config.initWithIdentity(identity);
  for (final p in profiles) {
    config.profiles[p]!.transform(cfg);
  }
  fsrepo.init(repoPath, cfg);
  print('repo created at $repoPath');
  print('peer: ${identity.peerId}');
  print('profiles: ${profiles.join(', ')}');
  await P2pService.stop();
}
