// Lição 07 · O que é um repositório, e por que `init`?
//
// Pergunta: as lições 03-06 montaram a pilha à mão, em memória, e a perderam
// no fim. Um nó IPFS guarda os seus blocos, a sua identidade e as suas
// configurações entre execuções. Onde, e o que precisa existir antes de o nó
// poder começar?
//
// Resposta: num repositório, uma pasta em disco criada uma vez pelo `init` (o
// `ipfs init` da linha de comando). Ela guarda:
//   - a identidade: um par de chaves. A chave pública, com hash, é o peer ID:
//     o nome do nó na rede (lição 13). A chave privada assina.
//   - a config: as configurações JSON do kubo (para onde vão os blocos, em
//     quais endereços escutar, de quais peers fazer bootstrap, roteamento...).
//     Perfis são mudanças prontas nela (`test`, `server`, `lowpower`,
//     `randomports`...).
//   - o datastore e o blockstore da lição 03, agora em disco (flatfs para os
//     blocos, leveldb ou pebble para o resto), mais o keystore (as chaves
//     extras da lição 11).
// Os datastores são plugins do kubo: são carregados no serviço uma vez, antes
// de abrir qualquer repositório.
//
// Precisa de: lição 01 (o serviço). Tecnicamente: os plugins (para montar a
// especificação de datastore do repositório), uma identidade (uma chave) e
// uma config feita a partir dela; abrir precisa de uma pasta já inicializada
// e que não esteja em uso por outro processo.
//
//   dart run example/pt_br/07_repo_and_init.dart
//
// Próxima pergunta: "E o que o nó faz com esse repositório?" → lição 08.
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson07_');
  final dir = '${tmp.path}/repo';
  try {
    // 1. Os plugins, uma vez por processo do serviço.
    //    Go:  plugins, _ := loader.NewPluginLoader("")
    //         plugins.Initialize(); plugins.Inject()
    final plugins = KuboPluginLoader('');
    plugins.initialize();
    plugins.inject();
    say('plugins carregados (agora o kubo conhece os datastores)');

    // 2. A identidade: uma chave ed25519 nova; o peer ID vem dela.
    //    Go:  id, _ := config.CreateIdentity(io.Discard, []options.KeyGenerateOption{
    //             options.Key.Type("ed25519")})
    final identity = go.ipfs.kubo.config.createIdentity(
        null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]);
    say('\nidentidade: peer ID ${identity.peerId}');
    say('  (a chave privada fica na config: quem a tem É este peer)');

    // 3. A config a partir da identidade, e um perfil por cima.
    //    Go:  cfg, _ := config.InitWithIdentity(id)
    //         config.Profiles["test"].Transform(cfg)
    final cfg = go.ipfs.kubo.config.initWithIdentity(identity);
    final before = (cfg.json['Addresses'] as Map)['Swarm'];
    go.ipfs.kubo.config.profiles['test']!.transform(cfg);
    final after = (cfg.json['Addresses'] as Map)['Swarm'];
    say('\nconfig: escuta em $before por padrão');
    say('  depois do perfil `test`: $after, peers de bootstrap '
        '${(cfg.json['Bootstrap'] as List).length}');
    say('  perfis que o kubo conhece: ${go.ipfs.kubo.config.profiles.keys.join(', ')}');

    // 4. O init grava a pasta; o open a trava para este processo.
    //    Go:  fsrepo.Init(dir, cfg); r, _ := fsrepo.Open(dir)
    say('\ninicializado antes do init: ${go.ipfs.kubo.repo.fsrepo.isInitialized(dir)}');
    go.ipfs.kubo.repo.fsrepo.init(dir, cfg);
    say('inicializado depois do init: ${go.ipfs.kubo.repo.fsrepo.isInitialized(dir)}');
    void listFolder(String when) {
      final entries = Directory(dir).listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      say('na pasta $when: ${entries.map((e) {
        final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        return e is Directory ? '$name/' : name;
      }).join(', ')}');
    }

    listFolder('depois do init');
    final repo = go.ipfs.kubo.repo.fsrepo.open(dir);
    listFolder('depois do open (os datastores nascem na primeira abertura)');
    final stored = repo.config();
    say('\naberto; a config lida de volta do disco tem o mesmo peer ID: '
        '${(stored.json['Identity'] as Map)['PeerID'] == identity.peerId}');
    final spec = (stored.json['Datastore'] as Map)['Spec'] as Map;
    say('  especificação do datastore: ${spec['type']} com '
        '${(spec['mounts'] as List).map((m) => (m as Map)['mountpoint']).join(', ')}');

    // 5. Uma chave da config pode ser lida e mudada com o repositório aberto.
    //    Go:  r.SetConfigKey("Datastore.StorageMax", "1GB")
    repo.setConfigKey('Datastore.StorageMax', '1GB');
    say('  Datastore.StorageMax agora: '
        '${repo.getConfigKey('Datastore.StorageMax')}');
    repo.close();

    say('\n== Erros comuns\n');
    final other = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
        .createIdentity(
            null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
    await silentlyWrong('init de novo, esperando que a config nova substitua',
        why: 'init numa pasta que já é repositório não faz nada (sem erro): '
            'a identidade de dentro nunca é sobrescrita',
        instead: 'mude um repositório existente com setConfig/setConfigKey '
            '(passo 5); identidade nova pede pasta nova',
        wrong: () {
          go.ipfs.kubo.repo.fsrepo.init(dir, other);
          final r = go.ipfs.kubo.repo.fsrepo.open(dir);
          final id = (r.config().json['Identity'] as Map)['PeerID'];
          r.close();
          return 'peer ID no repositório: $id';
        },
        right: () => 'o peer ID da config nova: '
            '${(other.json['Identity'] as Map)['PeerID']}');
    await mistake('abrir uma pasta que nunca foi inicializada',
        why: 'não há config, nem identidade, nem datastore para abrir',
        instead: 'init uma vez (passos 2-4), open nas outras',
        action: () =>
            go.ipfs.kubo.repo.fsrepo.open('${tmp.path}/nothing-here'));
    await mistake('carregar os plugins duas vezes no mesmo serviço',
        why: 'cada plugin de datastore se registra uma vez só no Go',
        instead: 'carregue-os uma vez por serviço, logo após o '
            'P2pService.start()',
        action: () => KuboPluginLoader('')
          ..initialize()
          ..inject());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
