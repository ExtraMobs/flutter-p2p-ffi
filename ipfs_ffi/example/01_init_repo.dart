// Passo 1 do kubo (`ipfs init`): plugins, identidade, config e repo em disco.
//
//   dart run example/01_init_repo.dart [repo] [perfil...]
//
// Padrão: ./.ipfs-ffi com o perfil `test` (portas aleatórias, sem
// bootstrap). Perfis do kubo: server, lowpower, randomports, flatfs...
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';
  final profiles = args.length > 1 ? args.sublist(1) : ['test'];

  // O kubo roda no ipfs_host, noutro processo (dart run tool/build.dart).
  await IpfsService.start();
  // Plugins (datastores flatfs/leveldb/pebble...): uma vez por processo do
  // serviço, antes de qualquer repo.
  final plugins = loader.PluginLoader('');
  plugins.initialize();
  plugins.inject();

  if (fsrepo.isInitialized(repoPath)) {
    print('já existe um repo em $repoPath');
    await IpfsService.stop();
    return;
  }
  final identity = config.createIdentity([options.key.type('ed25519')]);
  final cfg = config.initWithIdentity(identity);
  for (final p in profiles) {
    config.profiles[p]!.transform(cfg);
  }
  fsrepo.init(repoPath, cfg);
  print('repo criado em $repoPath');
  print('peer: ${identity.peerId}');
  print('perfis: ${profiles.join(', ')}');
  await IpfsService.stop();
}
